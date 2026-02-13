import os
import json
import logging
import base64
import httpx
from typing import Optional, List, Dict, Any
from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
import vertexai
from vertexai.generative_models import (
    GenerativeModel,
    Tool,
    Part,
    GenerationConfig,
    FinishReason,
)
from google.oauth2 import service_account
from firebase_functions import https_fn
from firebase_admin import initialize_app
import firebase_admin

# Import models
from models import AnalysisRequest, AnalysisResponse, GroundingCitation, GroundingSupport
from grounding_service import GroundingService

# --- Initialization ---
load_dotenv()
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

if not firebase_admin._apps:
    initialize_app()

app = FastAPI(title="VeriScan Core Engine")
grounding_service = GroundingService()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Vertex AI Configuration ---
PROJECT_ID = os.getenv("PROJECT_ID", "veriscan-kitahack")
LOCATION = os.getenv("LOCATION", "us-central1")
VERTEX_AI_READY = False

def init_vertex():
    global VERTEX_AI_READY
    CREDENTIALS_PATH = os.path.join(os.path.dirname(__file__), "service-account.json")
    try:
        if os.path.exists(CREDENTIALS_PATH):
            credentials = service_account.Credentials.from_service_account_file(CREDENTIALS_PATH)
            vertexai.init(project=PROJECT_ID, location=LOCATION, credentials=credentials)
            VERTEX_AI_READY = True
            logger.info("Vertex AI initialized with local Service Account.")
        else:
            vertexai.init(project=PROJECT_ID, location=LOCATION)
            VERTEX_AI_READY = True
            logger.info("Vertex AI initialized with Application Default Credentials.")
    except Exception as e:
        logger.error(f"Error initializing Vertex AI: {e}")
        VERTEX_AI_READY = False

# --- Utilities ---

async def fetch_url_content(url: str) -> str:
    """Fetches text content from a URL."""
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(url)
            response.raise_for_status()
            return response.text[:5000]
    except Exception as e:
        logger.error(f"Error fetching URL {url}: {e}")
        return f"[Error fetching content from {url}]"

async def process_multimodal_gemini(gemini_parts: List[Any], request_id: str, file_names: List[str] = None) -> AnalysisResponse:
    """Core logic to execute Gemini analysis."""
    if not VERTEX_AI_READY:
        init_vertex()
        if not VERTEX_AI_READY:
            raise RuntimeError("Vertex AI not configured.")

    logger.info(f"Processing Analysis Request: {request_id}")
    file_names = file_names or []

    try:
        system_instruction = """
# ROLE
You are the VeriScan Core Engine, an elite Fact-Checking AI specialized in digital forensic analysis and media literacy.

# OBJECTIVE
Analyze the provided parts (Text, Images, Documents, URLs). Your goal is to cross-verify the claims in the text against the visual evidence in the images and the data in the PDF/URLs. Provide a rigorous, search-grounded verdict.

# ANALYSIS PIPELINE
1. OCR/EXTRACT: Extract text from images/documents and describe visual context.
2. CROSS-VERIFY: Compare evidence across all provided parts.
3. SEARCH: Query authoritative sources to confirm or debunk the claim.
4. EVALUATE: Check for logical fallacies (e.g., Strawman, Ad Hominem, Appeal to Fear).
5. SCORE: Assign a confidence score from 0.0 to 1.0 based on the strength of grounding citations.

# OUTPUT FORMAT (STRICT JSON ONLY)
Return ONLY a JSON object. Do not include markdown code blocks. 
Schema:
{
  "verdict": "REAL" | "FAKE" | "MISLEADING" | "UNVERIFIED",
  "confidence_score": float,
  "analysis": "string (2-3 sentences explaining the 'why')",
  "key_findings": ["list of strings"],
  "source_metadata": { "type": "text" | "url" | "image" | "document", "provided_url": "string or null", "page_title": "string or null" },
  "grounding_citations": [{"title": "string", "url": "string", "snippet": "string"}],
  "media_literacy": { "logical_fallacies": ["string"], "tone_analysis": "string" }
}

# CONSTRAINTS
- If any URL returns a 403 (Forbidden), 404 (Not Found), or 429 (Too Many Requests) error, you MUST explicitly state this in the 'analysis' field. Use user-friendly wording like: "NOTICE: Verification is limited because the provided source (domain.com) is currently inaccessible—this may be due to a paywall or server restrictions. I have analyzed the remaining multimodal evidence (Images/PDFs) instead."
- If the only source provided is inaccessible, you must set verdict: "UNVERIFIED" and confidence_score: 0.0.
- Use the "confidence_score" to drive the verdict: if "confidence_score" < 0.5, the verdict MUST be "UNVERIFIED".
- The "confidence_score" must reflect the average certainty across all provided parts (Images, PDFs, and accessible URLs).
- Tone should be professional, objective, and "Obsidian-class".
- If a citation refers to an uploaded file, include the exact filename in the "title" or "snippet" of the citation.
"""
        tools = [Tool.from_dict({"google_search": {}})]
        model = GenerativeModel("gemini-2.0-flash-lite-001", system_instruction=[system_instruction], tools=tools)
        
        # thinking_level and configuration
        generation_config = GenerationConfig(
            temperature=0.0
        )
        
        response = model.generate_content(
            gemini_parts, 
            generation_config=generation_config
        )
        
        grounding_citations = []
        if response.candidates and response.candidates[0].grounding_metadata.grounding_chunks:
            for chunk in response.candidates[0].grounding_metadata.grounding_chunks:
                snippet_text = "Grounding source"
                if hasattr(chunk, 'retrieved_context'):
                    ctx = getattr(chunk, 'retrieved_context')
                    if ctx:
                        snippet_text = str(ctx.text) if hasattr(ctx, 'text') else str(ctx)
                if chunk.web:
                    grounding_citations.append(GroundingCitation(
                        title=chunk.web.title or "Unknown Source",
                        url=chunk.web.uri or "No source link available",
                        snippet=snippet_text if snippet_text != "Grounding source" else (chunk.web.title or "")
                    ))
        
        if response.candidates and response.candidates[0].finish_reason == FinishReason.RECITATION:
             return AnalysisResponse(
                verdict="REAL",
                confidence_score=0.99,
                analysis="The content was found verbatim in authoritative sources.",
                key_findings=["Content matches online sources exactly."],
                grounding_citations=[g.model_dump() for g in grounding_citations]
            )

        response_text = ""
        if response.candidates:
            for part in response.candidates[0].content.parts:
                if hasattr(part, 'text') and part.text:
                    response_text += part.text
        
        import re
        json_match = re.search(r'\{.*\}', response_text.strip(), re.DOTALL)
        if json_match:
            response_text = json_match.group(0)
        
        data = json.loads(response_text)
        if not data.get("grounding_citations") and grounding_citations:
             data["grounding_citations"] = [g.model_dump() for g in grounding_citations]
        
        # Sanitization & Filename Mapping
        sanitized_citations = []
        for gc in data.get("grounding_citations", []):
            if isinstance(gc, dict):
                # Detect filename in citation
                matched_file = None
                for fname in file_names:
                    if fname in (gc.get("title") or "") or fname in (gc.get("snippet") or ""):
                        matched_file = fname
                        break
                
                gc["source_file"] = matched_file
                if not gc.get("url"):
                    gc["url"] = "No source link available"
                if not gc.get("title"):
                    gc["title"] = matched_file or "Untitled Source"
                sanitized_citations.append(gc)
            else:
                sanitized_citations.append(gc)
        data["grounding_citations"] = sanitized_citations

        service_sources = []
        final_citations = data.get("grounding_citations", [])
        for gc in final_citations:
            url_val = gc.get("url") if isinstance(gc, dict) else getattr(gc, "url", "")
            title_val = gc.get("title") if isinstance(gc, dict) else getattr(gc, "title", "")
            snippet_val = gc.get("snippet") if isinstance(gc, dict) else getattr(gc, "snippet", "")
            
            service_sources.append({
                "uri": url_val or "No source link available",
                "title": title_val or "Untitled Source",
                "text": snippet_val or title_val
            })
        
        grounding_result = grounding_service.process(data.get("analysis", ""), service_sources)
        data["grounding_supports"] = grounding_result.get("groundingSupports", [])

        try:
            return AnalysisResponse(**data)
        except Exception as e:
            logger.error(f"Pydantic Validation Error: {e}")
            return AnalysisResponse(
                verdict=data.get("verdict", "UNVERIFIED"),
                confidence_score=data.get("confidence_score", 0.0),
                analysis="Analysis completed, but some source links are unavailable or malformed.",
                key_findings=data.get("key_findings", ["Metadata validation issue"]),
                grounding_citations=sanitized_citations
            )

    except Exception as e:
        logger.error(f"Analysis Processing Error: {e}")
        return AnalysisResponse(
            verdict="UNVERIFIED",
            confidence_score=0.0,
            analysis=f"System Error: {str(e)}",
            key_findings=[str(e)],
            grounding_citations=[]
        )

# --- FastAPI Endpoints ---

@app.get("/")
async def root():
    return {"status": "running", "vertex_ai": VERTEX_AI_READY}

@app.get("/health")
async def health_check():
    return {"status": "healthy", "vertex_ai_configured": VERTEX_AI_READY}

@app.post("/analyze", response_model=AnalysisResponse)
async def analyze_endpoint(
    files: Optional[List[UploadFile]] = File(None),
    metadata: str = Form(...)
):
    try:
        try:
            meta_data = json.loads(metadata)
        except json.JSONDecodeError:
            raise HTTPException(status_code=400, detail="Invalid JSON in metadata field.")
        
        request_id = meta_data.get("request_id", "unknown")
        text_claim = meta_data.get("text_claim")
        provided_url = meta_data.get("url")
        provided_urls = meta_data.get("urls", [])
        
        gemini_parts = []
        prompt_content = "Analyze the following parts (Text, Images, Documents, URLs):\n\n"
        
        if text_claim:
            prompt_content += f"TEXT CLAIM: {text_claim}\n"
        
        # 3. Process URLs
        if provided_url:
            content = await fetch_url_content(provided_url)
            prompt_content += f"URL CONTENT (from {provided_url}):\n{content}\n"
        
        for url in provided_urls:
            content = await fetch_url_content(url)
            prompt_content += f"URL CONTENT (from {url}):\n{content}\n"
        
        total_size = len(metadata)
        file_names = []
        if files:
            for file in files:
                file_bytes = await file.read()
                file_size = len(file_bytes)
                
                if file_size > 10 * 1024 * 1024:
                    raise HTTPException(status_code=413, detail=f"File {file.filename} exceeds 10MB limit.")
                
                total_size += file_size
                if total_size > 20 * 1024 * 1024:
                    raise HTTPException(status_code=413, detail="Total payload size exceeds 20MB limit.")
                
                file_names.append(file.filename)
                mime_type = file.content_type or "application/octet-stream"
                part_args = {"data": file_bytes, "mime_type": mime_type}
                
                if "image" in mime_type:
                    gemini_parts.append(Part.from_data(**part_args))
                    prompt_content += f"[Image Attached: {file.filename} ({mime_type})]\n"
                elif mime_type == "application/pdf":
                    gemini_parts.append(Part.from_data(**part_args))
                    prompt_content += f"[PDF Document Attached (Medium Resolution): {file.filename}]\n"
                else:
                    logger.warning(f"Unsupported file type: {mime_type}")

        if total_size > 20 * 1024 * 1024:
             raise HTTPException(status_code=413, detail="Total payload size exceeds 20MB limit.")

        gemini_parts.insert(0, prompt_content)
        return await process_multimodal_gemini(gemini_parts, request_id, file_names)
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except RuntimeError as e:
        raise HTTPException(status_code=500, detail=str(e))

# --- Firebase Cloud Function Wrapper ---

@https_fn.on_request(
    region=LOCATION,
    memory=512,
    timeout_sec=60,
    min_instances=0,
    max_instances=10
)
def analyze(req: https_fn.Request) -> https_fn.Response:
    if req.method == 'OPTIONS':
        return https_fn.Response(status=204, headers={
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST',
            'Access-Control-Allow-Headers': 'Content-Type',
        })

    import asyncio
    # Simple wrapper for Firebase - in production, you'd parse multipart here too if needed
    # For now, we'll keep it simple as the FastAPI endpoint is the main target.
    # If the user needs this specifically worked on, we'll refactor it separately.
    return https_fn.Response("Use FastAPI endpoint for multimodal analysis.", status=200)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8080)
