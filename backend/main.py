import os
import json
from typing import Optional, List
from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
import vertexai
from vertexai.generative_models import (
    GenerativeModel,
    Tool,
    Part,
    GenerationConfig,
    HarmCategory,
    HarmBlockThreshold,
    FinishReason,
    grounding
)
from google.oauth2 import service_account
from models import AnalysisResponse, SourceMetadata, GroundingCitation, MediaLiteracy

# Load environment variables
load_dotenv()

app = FastAPI(title="VeriScan Core Engine")

# Configure CORS for Flutter frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Service Account Configuration ---
CREDENTIALS_PATH = os.path.join(os.path.dirname(__file__), "service-account.json")
PROJECT_ID = "veriscan-kitahack"
LOCATION = "us-central1"

VERTEX_AI_READY = False
try:
    if os.path.exists(CREDENTIALS_PATH):
        credentials = service_account.Credentials.from_service_account_file(CREDENTIALS_PATH)
        vertexai.init(project=PROJECT_ID, location=LOCATION, credentials=credentials)
        VERTEX_AI_READY = True
        print(f"Vertex AI initialized from: {CREDENTIALS_PATH}")
    else:
        print(f"CRITICAL: Credentials not found at {CREDENTIALS_PATH}")
except Exception as e:
    print(f"Error initializing Vertex AI: {e}")

@app.get("/")
async def root():
    return {
        "message": "VeriScan Core Engine (Antigravity Update)",
        "status": "running",
        "vertex_ai": VERTEX_AI_READY
    }

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "vertex_ai_configured": VERTEX_AI_READY,
        "model": "gemini-2.5-flash-lite"
    }

@app.post("/analyze", response_model=AnalysisResponse)
async def analyze_multimodal(
    text: Optional[str] = Form(None),
    url: Optional[str] = Form(None),
    image: Optional[UploadFile] = File(None)
):
    if not VERTEX_AI_READY:
        raise HTTPException(status_code=500, detail="Vertex AI not configured.")

    if not text and not url and not image:
        raise HTTPException(status_code=400, detail="At least one input is required.")

    try:
        parts = []
        
        # --- 1. SYSTEM INSTRUCTION (Opinion-Proof Version) ---
        system_instruction = """
        Role: VeriScan Core Engine.
        
        CRITICAL ANALYSIS PROTOCOL (FOLLOW IN ORDER):
        
        PHASE 1: CLASSIFICATION (The Gatekeeper)
        - Analyze the input for Subjectivity, Opinions, Insults, or Satire.
        - EXAMPLES:
          * "Politician X is corrupt" -> Fact Check required (Check court cases).
          * "Politician X is stupid/ugly/pointless" -> OPINION (Subjective).
        - IF OPINION/INSULT: STOP immediately. Proceed to generate JSON with the below rules. 
          * VERDICT MUST BE: "UNVERIFIED".
          * VERDICT CANNOT BE: "FAKE" or "FALSE".
          * Analysis: "This statement is a subjective opinion or insult. Opinions cannot be proven true or false."
        
        PHASE 2: TYPO CORRECTION
        - If Input is factual (e.g. "Malausia"), correct typos (to "Malaysia") before searching.
        - DO NOT correct numbers/dates.
        
        PHASE 3: FACT CHECKING (Only for Factual Claims)
        - Perform a Google Search.
        - If the claim contradicts established facts, Verdict is "FAKE".
        - If the claim is supported by facts, Verdict is "REAL".
        - If the claim is partially true/missing context, Verdict is "MISLEADING".
        
        Task: 
        1. Classify (Opinion vs Fact).
        2. Search (If Fact).
        3. Output JSON.
        
        Output: STRICT JSON only. No Markdown.
        Format:
        {
          "verdict": "REAL" | "FAKE" | "MISLEADING" | "UNVERIFIED",
          "confidence_score": 0.0 to 1.0,
          "analysis": "string (2-3 sentences)",
          "key_findings": ["string"],
          "media_literacy": { "logical_fallacies": ["string"], "tone_analysis": "string" }
        }
        
        IMPORTANT: Do NOT include a 'grounding_citations' list in your JSON. The system will add them automatically.
        """
        
        prompt_content = "Analyze:\n"
        if text: prompt_content += f"Text: {text}\n"
        if url: prompt_content += f"URL: {url}\n"
        parts.append(prompt_content)

        if image:
            image_bytes = await image.read()
            parts.append(Part.from_data(data=image_bytes, mime_type=image.content_type))

        tools = [Tool.from_dict({"google_search": {}})]
        model = GenerativeModel("gemini-2.5-flash-lite", system_instruction=[system_instruction], tools=tools)
        
        # --- 2. SAFETY SETTINGS ---
        # Keep BLOCK_ONLY_HIGH (or BLOCK_NONE if you want to be extra sure)
        safety_settings = {
            HarmCategory.HARM_CATEGORY_HATE_SPEECH: HarmBlockThreshold.BLOCK_ONLY_HIGH,
            HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT: HarmBlockThreshold.BLOCK_ONLY_HIGH,
            HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT: HarmBlockThreshold.BLOCK_ONLY_HIGH,
            HarmCategory.HARM_CATEGORY_HARASSMENT: HarmBlockThreshold.BLOCK_ONLY_HIGH,
        }

        # --- 3. GENERATE ---
        response = model.generate_content(
            parts,
            generation_config=GenerationConfig(temperature=0.0),
            safety_settings=safety_settings
        )

        # Safety Catch
        if response.candidates and response.candidates[0].finish_reason != FinishReason.STOP:
             if response.candidates[0].finish_reason != FinishReason.RECITATION:
                print(f"⚠️ Blocked by AI. Reason: {response.candidates[0].finish_reason}")
                return AnalysisResponse(
                    verdict="UNVERIFIED",
                    confidence_score=0.0,
                    analysis="The AI flagged this content as unsafe or invalid.",
                    key_findings=["Safety Filter Triggered"],
                    grounding_citations=[]
                )

        # --- 4. EXTRACTION (Tool > AI) ---
        
        # A. Tool Citations
        tool_citations = []
        try:
            candidate = response.candidates[0]
            if candidate.grounding_metadata.grounding_chunks:
                for chunk in candidate.grounding_metadata.grounding_chunks:
                    if chunk.web:
                        tool_citations.append(GroundingCitation(title=chunk.web.title or "Source", url=chunk.web.uri, snippet="Verified via Google Search"))
            if candidate.finish_reason == FinishReason.RECITATION:
                if hasattr(candidate, 'citation_metadata') and candidate.citation_metadata:
                    for citation in candidate.citation_metadata.citations:
                        tool_citations.append(GroundingCitation(title="Direct Source Match", url=citation.uri, snippet="Exact match"))
        except Exception:
            pass

        # B. Extract JSON Text
        response_text = ""
        try:
            if response.candidates:
                for part in response.candidates[0].content.parts:
                    if part.text: response_text += part.text
        except:
            response_text = response.text

        response_text = response_text.replace("```json", "").replace("```", "").strip()

        # C. Parse JSON
        import re
        try:
            match = re.search(r'\{[\s\S]*\}', response_text)
            if match: response_text = match.group(0)
            
            data = json.loads(response_text)
            
        except json.JSONDecodeError:
            print(f"❌ JSON Parse Failed. Raw Text: {response_text}")
            data = {
                "verdict": "UNVERIFIED",
                "confidence_score": 0.0,
                "analysis": "The AI response format was invalid.",
                "key_findings": ["Formatting Error"]
            }

        # --- 5. MERGE ---
        data["grounding_citations"] = [c.model_dump() for c in tool_citations]
        
        if "grounding_citations" not in data:
            data["grounding_citations"] = []

        if "source_metadata" not in data: data["source_metadata"] = None
        if "media_literacy" not in data: data["media_literacy"] = None

        print(f"✅ Verdict: {data.get('verdict')} | Citations: {len(data['grounding_citations'])}")
        return AnalysisResponse(**data)

    except Exception as e:
        print(f"🔥 Critical Server Error: {e}")
        return AnalysisResponse(verdict="UNVERIFIED", confidence_score=0.0, analysis=f"System Error: {str(e)}", key_findings=["Server Crash"], grounding_citations=[])