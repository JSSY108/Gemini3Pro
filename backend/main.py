import os
import re
import json
import logging
import base64
import httpx
from typing import Optional, List, Dict, Any
from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from google import genai
from google.genai import types
from google.oauth2 import service_account
from firebase_functions import https_fn
from firebase_admin import initialize_app
import firebase_admin

# Import models
from models import AnalysisRequest, AnalysisResponse, GroundingCitation, GroundingSupport
# from grounding_service import GroundingService

# --- Initialization ---
load_dotenv()
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

if not firebase_admin._apps:
    initialize_app()

app = FastAPI(title="VeriScan Core Engine")
genai_client = None
_grounding_service = None

def get_grounding_service():
    global _grounding_service
    if _grounding_service is None:
        from grounding_service import GroundingService
        _grounding_service = GroundingService()
    return _grounding_service

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
    global VERTEX_AI_READY, genai_client
    # Robust absolute pathing for production
    base_dir = os.path.dirname(os.path.abspath(__file__))
    CREDENTIALS_PATH = os.path.join(base_dir, "service-account.json")
    
    try:
        # Check for environment variable fallback first
        env_creds = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
        
        if env_creds and os.path.exists(env_creds):
            genai_client = genai.Client(vertexai=True, project=PROJECT_ID, location=LOCATION)
            VERTEX_AI_READY = True
            logger.info("Vertex AI Client (google-genai) initialized via environment variable.")
        elif os.path.exists(CREDENTIALS_PATH):
            # The new SDK can use os.environ to find credentials if we set it temporarily or just use it
            os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = CREDENTIALS_PATH
            genai_client = genai.Client(vertexai=True, project=PROJECT_ID, location=LOCATION)
            VERTEX_AI_READY = True
            logger.info(f"Vertex AI Client (google-genai) initialized with bundled Service Account: {CREDENTIALS_PATH}")
        else:
            # Fallback to default credentials (works on some GCP environments)
            genai_client = genai.Client(vertexai=True, project=PROJECT_ID, location=LOCATION)
            VERTEX_AI_READY = True
            logger.info("Vertex AI Client (google-genai) initialized with Application Default Credentials.")
    except Exception as e:
        logger.error(f"FATAL: Vertex AI (google-genai) Initialization Failed: {e}")
        VERTEX_AI_READY = False
        # We don't raise here to allow the server to start, 
        # but subsequent analysis calls will catch VERTEX_AI_READY=False.

# --- Utilities ---

def sanitize_grounding_text(text: str) -> str:
    """Strips JSON structural fragments from cited segments using aggressive multiline logic."""
    if not text:
        return ""
    
    # 1. Pre-strip code block artifacts
    text = text.replace("```json", "").replace("```", "").strip()
    
    # 2. Line-by-line cleanup for structural leakage
    lines = text.splitlines()
    cleaned_lines = []
    
    # Pattern for JSON keys: "verdict": or \"analysis\": or key_findings: [ 
    # Handles escaped quotes commonly found in leaked segments
    key_pattern = re.compile(r'^\s*(?:\\")?"?([\w_]+)(?:\\")?"?\s*:\s*', re.IGNORECASE)
    # Pattern for solo structural bits or boolean leaks
    structure_pattern = re.compile(r'^\s*[{}[\],"\\]+\s*$|^\s*(?:\\")?"?(?:true|false)(?:\\")?"?\s*,?\s*$', re.IGNORECASE)
    # Keys to skip entirely (structural/forensic metadata)
    metadata_keys = {"verdict", "confidence_score", "multimodal_cross_check", "type", "provided_url", "page_title"}

    for line in lines:
        s_line = line.strip()
        if not s_line:
            continue
            
        # If the line is a key pattern
        match = key_pattern.match(s_line)
        if match:
            key_name = match.group(1).lower()
            # If it's a metadata key, skip the entire line/value
            if key_name in metadata_keys:
                continue
                
            # If it's a content key (like "analysis"), try to take the value
            if ":" in s_line:
                value_part = s_line.split(":", 1)[1].strip().strip('",\\ ')
                if value_part and not structure_pattern.match(value_part):
                    # Value contains actual text, keep only the value!
                    cleaned_lines.append(value_part)
            continue
            
        # If it's just structural junk, skip it entirely
        if structure_pattern.match(s_line):
            continue
            
        # Otherwise, it's likely real content
        cleaned_lines.append(line)

    text = "\n".join(cleaned_lines).strip()
    
    # 3. Final cleanup of leading/trailing structural junk
    text = text.strip('"{},[] \n\r\t')
    # Remove trailing quotes and commas again after stripping
    text = re.sub(r'["\s,\]}\\]*$', '', text)
    
    return text.strip()

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
            raise RuntimeError("Credentials file not found or Vertex AI configuration invalid.")

    logger.info(f"Processing Analysis Request: {request_id}")
    file_names = file_names or []

    try:
        system_instruction = """
You are VeriScan's Forensic Auditor. You will be provided with a claim, and optionally, an uploaded image or PDF.
1. You must use Google Search to verify the claim.
2. If the user provides an uploaded file, you must cross-reference its contents with the web facts. If the file's core claim matches the verified web search results, flag "multimodal_cross_check" as true. Otherwise, false.
You MUST return your final response strictly as a valid JSON object matching this exact structure. 
CRITICAL: Use clear, standard sentence boundaries for the 'analysis' text. Ensure grounding segments remain within claim boundaries and do not include JSON keys or structural quotes in their boundaries.
Do not include markdown code blocks (like ```json).
{
"verdict": "REAL | FAKE | MISLEADING | UNVERIFIED",
"confidence_score": 0.0 to 1.0,
"analysis": "2-3 sentences explaining the reasoning.",
"multimodal_cross_check": true or false,
"key_findings": ["list of strings"],
"source_metadata": { "type": "text" | "url" | "image" | "document", "provided_url": "string or null", "page_title": "string or null" },
"grounding_citations": [{"title": "string", "url": "string", "snippet": "string"}],
"media_literacy": { "logical_fallacies": ["string"], "tone_analysis": "string" }
}
"""
        from models import GroundingCitation, GroundingSupport, AnalysisResponse
        
        # Configure the tool and system instructions using the new SDK syntax
        config = types.GenerateContentConfig(
            system_instruction=system_instruction,
            temperature=0.2,
            tools=[{"google_search": {}}] # Standard format for grounding in the new SDK
        )
        
        # Execute the call using genai_client
        response = genai_client.models.generate_content(
            model="gemini-2.0-flash",
            contents=gemini_parts,
            config=config
        )

        # Forensic Audit: Write the entire grounding metadata object to a file for review
        import os
        base_dir = os.path.dirname(os.path.abspath(__file__))
        dump_path = os.path.join(base_dir, "grounding_metadata_dump.json")
        if response.candidates and response.candidates[0].grounding_metadata:
            # Convert the Pydantic model to a dict, then to a pretty string
            metadata_json = response.candidates[0].grounding_metadata.model_dump_json(indent=2)
            with open(dump_path, "w") as f:
                f.write(metadata_json)
            print(f"\n[FORENSIC] Grounding metadata dumped to {dump_path}\n")
        else:
            with open(dump_path, "w") as f:
                f.write('{"error": "NO GROUNDING METADATA FOUND"}')
            print("NO GROUNDING METADATA FOUND IN RESPONSE")
        
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
        
        if response.candidates and response.candidates[0].finish_reason == types.FinishReason.RECITATION:
             return AnalysisResponse(
                verdict="REAL",
                confidence_score=0.99,
                analysis="The content was found verbatim in authoritative sources.",
                key_findings=["Content matches online sources exactly."],
                grounding_citations=[g.model_dump() for g in grounding_citations]
            )

        response_text = response.text if response.candidates else ""
        print("\n" + "="*50)
        print(f"[DEBUG] Raw Model Text:\n{response_text}")
        print("="*50 + "\n")
        import sys
        sys.stdout.flush()
        
        # Robust parsing using regex to find the first '{' and last '}'
        import re
        json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
        if json_match:
            clean_json = json_match.group(0)
        else:
            clean_json = response_text.strip().removeprefix("```json").removesuffix("```").strip()
            
        logger.info(f"Cleaned JSON: {clean_json}")
        
        try:
            data = json.loads(clean_json)
            is_multimodal_verified = data.get("multimodal_cross_check", False)
        except json.JSONDecodeError:
            logger.error("[SYSTEM ERROR] Model failed to return valid JSON.")
            is_multimodal_verified = False
            # Handle non-JSON response by creating a basic dict with required fields
            data = {
                "analysis": response_text, 
                "verdict": "UNVERIFIED",
                "key_findings": ["Model returned non-JSON response"],
                "confidence_score": 0.0
            }
            
        if not data.get("grounding_citations") and grounding_citations:
             data["grounding_citations"] = [g.model_dump() for g in grounding_citations]
        
        # Sanitization & Filename Mapping & URL Diagnostic
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
                
                # Clean up snippet
                if gc.get("snippet"):
                    gc["snippet"] = sanitize_grounding_text(gc["snippet"])
                
                # URL Diagnostic Logic
                url_str = gc.get("url", "").lower()
                snippet_str = gc.get("snippet", "").lower()
                
                status = "live"
                # Check for Social Media (Restricted)
                social_domains = ["instagram.com", "facebook.com", "twitter.com", "x.com", "tiktok.com", "reddit.com"]
                if any(domain in url_str for domain in social_domains):
                    status = "restricted"
                # Check for Dead Link / Inaccessible
                elif not gc.get("snippet") or "failed to fetch" in snippet_str or "could not be reached" in snippet_str:
                    status = "dead"
                
                gc["status"] = status
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
            
            status_val = gc.get("status", "live") if isinstance(gc, dict) else getattr(gc, "status", "live")
            
            service_sources.append({
                "uri": url_val or "No source link available",
                "title": title_val or "Untitled Source",
                "text": snippet_val or title_val,
                "status": status_val
            })
        
        
        grounding_service = get_grounding_service()
        grounding_result = grounding_service.process(data.get("analysis", ""), service_sources)
        grounding_supports_heuristic = grounding_result.get("groundingSupports", [])
        
        # Phase 2: Math Engine Integration
        try:
            from logic import calculate_reliability
            # Determine grounding sources for math engine. 
            # PRIORITY: If API returned supports directly, use them (they have real confidence scores).
            # FALLBACK: Use heuristic keyword-mapped supports.
            api_supports = []
            if response.candidates and hasattr(response.candidates[0].grounding_metadata, 'grounding_supports'):
                raw_api_supports = response.candidates[0].grounding_metadata.grounding_supports or []
                # Convert Pydantic models to camelCase dicts for AnalysisResponse consistency
                for sup in raw_api_supports:
                    sup_dict = sup.model_dump()
                    standardized = {
                        "segment": {
                            "startIndex": sup_dict["segment"].get("start_index") or 0,
                            "endIndex": sup_dict["segment"].get("end_index") or 0,
                            "text": sanitize_grounding_text(sup_dict["segment"].get("text", ""))
                        },
                        "groundingChunkIndices": sup_dict.get("grounding_chunk_indices") or [],
                        "confidenceScores": sup_dict.get("confidence_scores") or []
                    }
                    api_supports.append(standardized)
            
            final_supports = api_supports if api_supports else grounding_supports_heuristic
            data["grounding_supports"] = final_supports
            
            # Grounding chunks (Sources)
            grounding_chunks = []
            if response.candidates and response.candidates[0].grounding_metadata.grounding_chunks:
                grounding_chunks = response.candidates[0].grounding_metadata.grounding_chunks
            
            import sys
            sys.stdout.flush()
            
            reliability_metrics = calculate_reliability(
                final_supports, 
                grounding_chunks, 
                is_multimodal_verified
            )
            data["reliability_metrics"] = reliability_metrics
            
            # Map VERDICT label back explicitly if not present or for engine-driven overrides if specifically requested
            # However, per user request, we now let the model provide the top-level verdict/score
            # and keep the reliability engine metrics separate.
            if "verdict" not in data or not data["verdict"]:
                score = float(reliability_metrics.get("score", 0.0))
                if score > 0.85:
                    data["verdict"] = "REAL"
                elif score > 0.50:
                    data["verdict"] = "MISLEADING"
                else:
                    data["verdict"] = "FAKE"
                 
        except Exception as e:
            logger.error(f"Error calculating reliability: {e}")
            import traceback
            traceback.print_exc()


        try:
            from models import AnalysisResponse
            # logger.info(f"Final Data Structure: {json.dumps(data, indent=2)}")
            return AnalysisResponse(**data)
        except Exception as e:
            logger.error(f"Pydantic Validation Error: {e}")
            logger.error(f"Data that failed validation: {data}")
            return AnalysisResponse(
                verdict=data.get("verdict", "UNVERIFIED"),
                confidence_score=data.get("confidence_score", 0.0),
                analysis="Analysis completed, but some source data was malformed or missing.",
                key_findings=data.get("key_findings", ["Metadata validation issue"]),
                grounding_citations=data.get("grounding_citations", []),
                grounding_supports=data.get("grounding_supports", []),
                reliability_metrics=data.get("reliability_metrics")
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
                    gemini_parts.append(types.Part.from_bytes(**part_args))
                    prompt_content += f"[Image Attached: {file.filename} ({mime_type})]\n"
                elif mime_type == "application/pdf":
                    gemini_parts.append(types.Part.from_bytes(**part_args))
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
            'Access-Control-Allow-Methods': 'POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        })

    if req.method != 'POST':
        return https_fn.Response("Method Not Allowed. Use POST.", status=405, headers={'Access-Control-Allow-Origin': '*'})

    import asyncio
    import traceback
    
    try:
        # 1. Parse metadata from Form
        metadata_str = req.form.get("metadata")
        if not metadata_str:
             return https_fn.Response(json.dumps({"error": "Missing metadata field"}), status=400, mimetype='application/json')
        
        meta_data = json.loads(metadata_str)
        request_id = meta_data.get("request_id", "prod_req")
        text_claim = meta_data.get("text_claim", "")
        provided_urls = meta_data.get("urls", [])
        
        # 2. Extract files from Request
        gemini_parts = []
        prompt_content = f"Analyze the following parts (Text, Images, Documents, URLs):\n\nTEXT CLAIM: {text_claim}\n"
        
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        async def _run():
            nonlocal prompt_content
            for url in provided_urls:
                content = await fetch_url_content(url)
                prompt_content += f"URL CONTENT (from {url}):\n{content}\n"
            
            file_names = []
            for key in req.files:
                for f in req.files.getlist(key):
                    file_bytes = f.read()
                    if not file_bytes: continue
                    file_names.append(f.filename)
                    mime_type = f.content_type or "application/octet-stream"
                    part_args = {"data": file_bytes, "mime_type": mime_type}
                    if "image" in mime_type:
                        gemini_parts.append(types.Part.from_bytes(**part_args))
                        prompt_content += f"[Image Attached: {f.filename}]\n"
                    elif mime_type == "application/pdf":
                        gemini_parts.append(types.Part.from_bytes(**part_args))
                        prompt_content += f"[PDF Document Attached: {f.filename}]\n"

            gemini_parts.insert(0, prompt_content)
            return await process_multimodal_gemini(gemini_parts, request_id, file_names)

        try:
            result = loop.run_until_complete(_run())
            return https_fn.Response(
                json.dumps(result.model_dump()),
                status=200,
                mimetype='application/json',
                headers={'Access-Control-Allow-Origin': '*'}
            )
        finally:
            loop.close()

    except Exception as e:
        error_msg = f"ERROR: {str(e)}\n{traceback.format_exc()}"
        logger.error(f"Function Execution Error: {error_msg}")
        # Explicit error if credentials are the cause
        if "service-account.json" in str(e) or "Credentials" in str(e):
             return https_fn.Response(json.dumps({
                 "error": "Credentials file not found or invalid on production server.",
                 "debug_trace": error_msg
             }), status=500, mimetype='application/json', headers={'Access-Control-Allow-Origin': '*'})
             
        return https_fn.Response(json.dumps({
            "error": "Internal Server Error during forensic analysis.",
            "debug_trace": error_msg
        }), status=500, mimetype='application/json', headers={'Access-Control-Allow-Origin': '*'})

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8080)
