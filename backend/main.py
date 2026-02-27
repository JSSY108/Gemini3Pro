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

def normalize_for_search(text: str) -> str:
    """Normalizes text for robust anchor matching (degree symbols, spaces, etc)."""
    if not text:
        return ""
    # Standardize degree symbol: handles standard, escaped, and common corruption variants
    # Note: the empty string in replace('', '°') was likely a placeholder for a specific corruption char
    # We'll use the specific ones mentioned and general cleanup.
    normalized = text.replace('\\u00b0', '°').replace('â°', '°').strip()
    return normalized

def repair_and_parse_json(raw_text: str) -> dict:
    """Aggressively cleans and parses LLM-generated JSON."""
    if not raw_text:
        raise ValueError("Empty response text")

    # Extract just the JSON object (first { to last })
    json_match = re.search(r'\{.*\}', raw_text, re.DOTALL)
    if not json_match:
        raise ValueError("No JSON object found in text")

    cleaned = json_match.group(0)

    # Attempt to fix trailing commas before closing braces/brackets
    cleaned = re.sub(r',\s*([\]}])', r'\1', cleaned)

    # Fallback to targeted regex for escaping double quotes inside the "analysis" text specifically.
    # LLMs frequently hallucinate unescaped double quotes when writing long analysis paragraphs.
    try:
        return json.loads(cleaned, strict=False)
    except json.JSONDecodeError:
        # If the first standard parse fails, let's aggressively escape just the analysis block
        # Match "analysis": " (everything here) " , "multimodal_cross_check"
        match = re.search(r'("analysis"\s*:\s*")(.*?)("\s*,\s*"multimodal_cross_check")', cleaned, re.DOTALL)
        if match:
            analysis_text = match.group(2)
            # Escape inner quotes
            escaped_text = analysis_text.replace('"', '\\"')
            # Reconstruct string
            cleaned = cleaned[:match.start(2)] + escaped_text + cleaned[match.end(2):]
            
        return json.loads(cleaned, strict=False)

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

def normalize_url(url: str) -> str:
    """Normalizes a URL for comparison by removing protocol, www, and trailing slashes."""
    if not url:
        return ""
    # Strip protocol
    url = re.sub(r'^https?://', '', url.lower())
    # Strip www.
    url = re.sub(r'^www\.', '', url)
    # Strip trailing slash
    url = url.rstrip('/')
    # Strip query params/fragments for aggressive matching if needed, 
    # but for now let's keep it simple
    return url

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
You are the VeriScan Lead Forensic Auditor, an expert fact-checking AI designed for the KitaHack 2026 platform. Your job is to analyze claims objectively, rely ONLY on the provided evidence, and output a highly structured factual breakdown.

You will be provided with a user's input and, optionally, a combination of uploaded files (images, PDFs) and external URLs. You also have access to Google Search (Grounding Metadata) to verify the facts.

### STRICT RULES OF ENGAGEMENT:
1. ZERO HALLUCINATION: You must base your analysis entirely on the provided 'Grounding Metadata' (Search Results) and the user's uploaded files/URLs. Do not use outside knowledge.
2. NO ASSUMPTIONS: If the grounding data does not explicitly confirm or deny a claim, you must categorize the verdict as "UNVERIFIABLE".
3. VERDICT HIERARCHY:
    - TRUE: 100% of the claim is factual.
    - MOSTLY_TRUE: The core claim is factual but contains a minor scientific technicality or rounding error.
    - MIXTURE: Use this if the input contains multiple facts where at least one is TRUE and at least one is FALSE. (e.g., "A is true and B is false" = MIXTURE).
    - MISLEADING: The facts are technically true but presented in a way that implies a false conclusion (e.g., correlations presented as causations).
    - MOSTLY_FALSE: The core claim is false but contains a minor element of truth.
    - FALSE: The core claim is entirely false.
    - UNVERIFIABLE: Insufficient grounding data exists.
    - NOT_A_CLAIM: Subjective, opinion, or future prediction.
4. MULTIMODAL CROSS-EXAMINATION: You must cross-reference the contents of all uploaded files, images, and URLs against the Google Search results. If the core claim in ANY of the uploaded files is corroborated by high-authority web search, flag the "multimodal_cross_check" boolean as true. If they contradict the web, or if the user provided no files, flag it as false.
5. LITERAL FACT-CHECKING ONLY: You must evaluate the literal physical reality of the claim. If a user claims an absurd or impossible entity exists (e.g., "There is a teapot in space"), you must fact-check its physical existence. Do NOT output 'TRUE' just because you found an article describing it as a thought experiment, movie plot, or internet meme. If the literal physical claim cannot be proven by evidence, you MUST output "UNVERIFIABLE".
6. IDENTIFYING NON-CLAIMS (SHORT-CIRCUIT): You can only fact-check objective, verifiable statements of past or present fact. If the user's input is a subjective opinion (e.g., "Vanilla is the best flavor"), a prediction of the future, a question, or a poem, you must immediately classify the verdict as "NOT_A_CLAIM".
7. TONE: Maintain an objective, journalistic, and highly analytical tone. Avoid emotional language.

### REQUIRED OUTPUT FORMAT:
You MUST return your final response strictly as a valid JSON object matching the exact structure below. Do NOT wrap the JSON in markdown code blocks (like ```json). Ensure all internal double quotes are escaped (e.g., \") as per standard JSON rules.

{
  "verdict": "TRUE | MOSTLY_TRUE | MIXTURE | MISLEADING | MOSTLY_FALSE | FALSE | UNVERIFIABLE | NOT_A_CLAIM",
  "confidence_score": [float between 0.0 and 1.0 representing internal reasoning confidence],
  "analysis": "[A highly detailed markdown-formatted string following the exact structure outlined below]",
  "multimodal_cross_check": [boolean: true if uploaded files match verified web facts, false otherwise],
  "source_metadata": { 
    "types_analyzed": ["array of strings: e.g., 'text', 'image', 'pdf', 'url' based on what was provided"] 
  },
  "grounding_citations": [
    {"title": "string", "url": "string", "snippet": "string"}
  ],
  "media_literacy": { 
    "logical_fallacies": ["array of strings: any logical fallacies detected"], 
    "tone_analysis": "string" 
  }
}

### THE "ANALYSIS" FORMAT:
The "analysis" string MUST be formatted in Markdown and strictly use these four headings. 

**EXCEPTION FOR 'NOT_A_CLAIM':** If the verdict is "NOT_A_CLAIM", ignore the 4 headings below. Instead, provide a single, brief paragraph explaining why the input is subjective, a future prediction, or otherwise impossible to fact-check objectively.

**1. The Core Claim(s):**
[Provide a single, precise sentence PARAPHRASING what is being fact-checked. You MUST paraphrase in your own words. DO NOT quote the user's input verbatim under any circumstances to avoid triggering recitation filters.]

**2. Evidence Breakdown:**
[Use bullet points. State the raw facts found in the retrieved Google Search sources and uploaded files. Extract specific 'factual anchors'—such as numbers, dates, locations, or direct quotes—ONLY IF they are relevant to the claim. Do not force specific details if they do not apply. If the verdict is 'MIXTURE', you MUST explicitly list which specific parts of the input are true and which are false.]

**3. Context & Nuance:**
[Explain the background. Why might this claim be misleading? Is it a real photo taken out of context? Explain the "how" and "why" behind the verdict.]

**4. Red Flags & Discrepancies:**
[Use this section ONLY if there is conflicting information (e.g., an uploaded PDF contradicts the web, or two different news sites report different things). If there are no conflicts, write: "No major discrepancies found in the verified sources."]
"""
        from models import GroundingCitation, GroundingSupport, AnalysisResponse, ScannedSource
        
        # Configure the tool and system instructions using the new SDK syntax
        config = types.GenerateContentConfig(
            system_instruction=system_instruction,
            temperature=0.0,
            max_output_tokens=8192,
            tools=[{"google_search": {}}]
        )
        
        # Execute the call using genai_client
        response = genai_client.models.generate_content(
            model="gemini-2.0-flash",
            contents=gemini_parts,
            config=config
        )

        # DEBUG: Print raw response to console for deep inspection
        print("\n[DEBUG] RAW RESPONSE METADATA:")
        if response.candidates:
            if response.candidates[0].grounding_metadata:
                print(f"Grounding Metadata Attributes: {dir(response.candidates[0].grounding_metadata)}")
                print(f"Grounding Metadata Dump: {response.candidates[0].grounding_metadata.model_dump_json(indent=2)}")
        
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
        
        grounding_citations_fallback = []
        if response.candidates and response.candidates[0].grounding_metadata:
            chunks = getattr(response.candidates[0].grounding_metadata, 'grounding_chunks', [])
            if chunks:
                for i, chunk_obj in enumerate(chunks):
                    web_node = getattr(chunk_obj, 'web', None)
                    if web_node:
                        title = getattr(web_node, 'title', getattr(web_node, 'domain', "Unknown Source"))
                        uri = getattr(web_node, 'uri', "No source link available")
                        grounding_citations_fallback.append(GroundingCitation(
                            id=i + 1,
                            title=title,
                            url=uri,
                            snippet=title # Fallback snippet if LLM fails
                        ))
        
        try:
            raw_text = response.text
            logging.info(f"[RAW LLM DUMP] Raw text from Gemini before parsing:\n{raw_text}")
        except Exception as e:
            logging.error(f"[RAW LLM DUMP] Failed to extract text from response. Reason: {e}")
            logging.error(f"[RAW LLM DUMP] Response object: {response}")
            
        try:
            response_text = response.text or ""
        except Exception:
            response_text = ""
            
        finish_reason = response.candidates[0].finish_reason if response.candidates else "UNKNOWN"
        print(f"[DEBUG] Finish Reason: {finish_reason}")
        print("\n" + "="*50)
        print(f"[DEBUG] Raw Model Text:\n{response_text}")
        print("="*50 + "\n")
        try:
            # Use our aggressive cleaner
            data = repair_and_parse_json(response_text)
            
            # Debug Dump: Model Output JSON
            output_dump_path = os.path.join(base_dir, "model_output_dump.json")
            with open(output_dump_path, "w") as f:
                json.dump(data, f, indent=2)
            print(f"[FORENSIC] Model output dumped to {output_dump_path}")

            is_multimodal_verified = data.get("multimodal_cross_check", False)
            
        except Exception as e:
            logger.error(f"[JSON PARSE ERROR] {e}")
            
            # FORENSIC DUMP: Save the exact string that broke the parser
            dump_path = os.path.join(base_dir, "failed_json_dump.txt")
            with open(dump_path, "w", encoding="utf-8") as f:
                f.write(f"ERROR: {str(e)}\n")
                f.write("="*50 + "\n")
                f.write(response_text or "NONE")
            print(f"[FORENSIC] Broken JSON dumped to {dump_path}")
            
            is_multimodal_verified = False
            # FALLBACK: If the LLM crashed, returned text, or got blocked by safety filters
            data = {
                "verdict": "UNVERIFIABLE",
                "confidence_score": 0.0,
                "analysis": "**1. The Core Claim(s):**\nThe provided text could not be independently verified.\n\n**2. Evidence Breakdown:**\n* The AI safety or recitation filters prevented a deep analysis of this specific phrasing.\n* No verifiable search data could be extracted.\n\n**3. Context & Nuance:**\nPlease try rewording your claim or providing more specific factual context.\n\n**4. Red Flags & Discrepancies:**\nNo major discrepancies found in the verified sources.",
                "multimodal_cross_check": False,
                "source_metadata": {"types_analyzed": ["text"]},
                "grounding_citations": [],
                "media_literacy": {"logical_fallacies": [], "tone_analysis": "Neutral"},
            }
            
        if not data.get("grounding_citations") and grounding_citations_fallback:
             data["grounding_citations"] = [g.model_dump() for g in grounding_citations_fallback]
        
        # Prepare a URI to ID map from grounding chips
        uri_to_id = {}
        if response.candidates and response.candidates[0].grounding_metadata:
            chunks = getattr(response.candidates[0].grounding_metadata, 'grounding_chunks', [])
            for i, chunk_obj in enumerate(chunks):
                web_node = getattr(chunk_obj, 'web', None)
                if web_node:
                    uri = getattr(web_node, 'uri', "")
                    if uri:
                        uri_to_id[normalize_url(uri)] = i + 1

        # Final Sanitization: Attach correct IDs to citations
        sanitized_citations = []
        for gc in data.get("grounding_citations", []):
            if isinstance(gc, dict):
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
                
                # Assign ID based on URL match with master chunks
                norm_url = normalize_url(gc.get("url", ""))
                gc["id"] = uri_to_id.get(norm_url, 0) # 0 if not found in master chunks
                
                if gc.get("snippet"):
                    gc["snippet"] = sanitize_grounding_text(gc["snippet"])
                
                url_str = gc.get("url", "").lower()
                snippet_str = gc.get("snippet", "").lower()
                status = "live"
                social_domains = ["instagram.com", "facebook.com", "twitter.com", "x.com", "tiktok.com", "reddit.com"]
                if any(domain in url_str for domain in social_domains):
                    status = "restricted"
                elif not gc.get("snippet") or "failed to fetch" in snippet_str or "could not be reached" in snippet_str:
                    status = "dead"
                
                gc["status"] = status
                sanitized_citations.append(gc)
            else:
                sanitized_citations.append(gc)
        data["grounding_citations"] = sanitized_citations

        # --- Populate Scanned Sources ---
        scanned_sources = []
        if response.candidates and response.candidates[0].grounding_metadata:
            chunks = getattr(response.candidates[0].grounding_metadata, 'grounding_chunks', [])
            cited_urls = {normalize_url(gc.get("url")) for gc in sanitized_citations if gc.get("url")}
            
            seen_urls = set()
            for i, chunk_obj in enumerate(chunks):
                web_node = getattr(chunk_obj, 'web', None)
                if web_node:
                    title = getattr(web_node, 'title', "Untitled Source")
                    uri = getattr(web_node, 'uri', "")
                    norm_uri = normalize_url(uri)
                    if not uri or norm_uri in seen_urls:
                        continue
                    
                    seen_urls.add(norm_uri)
                    scanned_sources.append(ScannedSource(
                        id=i + 1, # Unified Rule: ID = chunk_index + 1
                        title=title,
                        url=uri,
                        is_cited=norm_uri in cited_urls
                    ).model_dump())
        
        data["scanned_sources"] = scanned_sources

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
                    segment_obj = sup_dict.get("segment") or {}
                    raw_seg_text = segment_obj.get("text", "")
                    
                    # 1. Robust Unescaping
                    try:
                        # Ensures \\n becomes \n and other escaped chars are handled
                        unescaped_text = raw_seg_text.encode('utf-8').decode('unicode_escape')
                    except Exception:
                        unescaped_text = raw_seg_text.replace('\\n', '\n').replace('\\"', '"')

                    # 2. Segment Trimming (Markdown Headers & Bullet Points)
                    # Regex to find leading **Section Header:** or * Bullet points
                    # and capture the remaining text.
                    trim_match = re.match(r'^(\s*(?:\*\*[^*]+\*\*:\s*|\*+\s*))(.*)', unescaped_text, re.DOTALL)
                    
                    final_seg_text = unescaped_text
                    start_offset = 0
                    
                    if trim_match:
                        prefix = trim_match.group(1)
                        final_seg_text = trim_match.group(2)
                        start_offset = len(prefix)
                    
                    standardized = {
                        "segment": {
                            "startIndex": (segment_obj.get("start_index") or 0) + start_offset,
                            "endIndex": segment_obj.get("end_index") or 0,
                            "text": final_seg_text
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
                data.get("grounding_citations", []),
                is_multimodal_verified,
                ai_confidence=float(data.get("confidence_score", 0.0))
            )
            data["reliability_metrics"] = reliability_metrics
            
            # Map VERDICT label back explicitly if not present or for engine-driven overrides if specifically requested
            # However, per user request, we now let the model provide the top-level verdict/score
            # and keep the reliability engine metrics separate.
            if "verdict" not in data or not data["verdict"]:
                score = float(reliability_metrics.get("score", 0.0))
                if score > 0.85:
                    data["verdict"] = "TRUE"
                elif score > 0.50:
                    data["verdict"] = "MISLEADING"
                else:
                    data["verdict"] = "FALSE"
                 
        except Exception as e:
            logger.error(f"Error calculating reliability: {e}")
            import traceback
            traceback.print_exc()

        raw_analysis = data.get("analysis", "") or "**1. The Core Claim(s):**\nThe data could not be parsed.\n\n**2. Evidence Breakdown:**\n* The AI returned malformed data or was blocked by safety filters."
        
        # The model sometimes returns literal '\n' and '\"' strings instead of actual characters
        # due to its internal interpretation of JSON safety. We unescape them here.
        if isinstance(raw_analysis, str):
            sanitized_analysis = raw_analysis.replace('\\n', '\n').replace('\\"', '"')
        else:
            sanitized_analysis = str(raw_analysis)

        # Phase 3: Fuzzy Anchor Re-indexing
        # After citation brackets are injected (in standardize_analysis or similar),
        # we must find the strings again to ensure UI highlights are accurate.
        clean_analysis = normalize_for_search(sanitized_analysis)
        for support in data.get("grounding_supports", []):
            segment = support.get("segment", {})
            anchor_text = segment.get("text", "")
            if not anchor_text:
                continue
            
            clean_anchor = normalize_for_search(anchor_text)
            
            # 1. Try Exact Match in normalized text
            new_start = clean_analysis.find(clean_anchor)
            
            # 2. Try Partial Match (Fingerprint) if exact fails
            if new_start == -1:
                # Use first 20 chars as unique fingerprint to avoid bracket collisions
                fingerprint = clean_anchor[:min(len(clean_anchor), 20)]
                if len(fingerprint) >= 5: # Ensure fingerprint is meaningful
                    new_start = clean_analysis.find(fingerprint)
            
            if new_start != -1:
                segment["startIndex"] = new_start
                segment["endIndex"] = new_start + len(anchor_text) # Use original length for indexing

        return AnalysisResponse(
            verdict=data.get("verdict", "UNVERIFIABLE"),
            confidence_score=data.get("confidence_score", 0.0),
            analysis=sanitized_analysis,
            multimodal_cross_check=data.get("multimodal_cross_check", False),
            reliability_metrics=data.get("reliability_metrics"),
            grounding_citations=data.get("grounding_citations", []),
            scanned_sources=data.get("scanned_sources", []),
            grounding_supports=data.get("grounding_supports", [])
        )

    except Exception as e:
        logger.error(f"Analysis Processing Error: {e}")
        return AnalysisResponse(
            verdict="UNVERIFIABLE",
            confidence_score=0.0,
            analysis=f"System Error: {str(e)}",
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
