from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import google.generativeai as genai
import os
from typing import Optional

app = FastAPI(title="Fake News Detector API")

# Configure CORS for Flutter frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your Flutter app's origin
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configure Gemini AI
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)


class NewsRequest(BaseModel):
    news_text: str


class NewsResponse(BaseModel):
    is_valid: bool
    confidence_score: float
    analysis: str
    key_findings: list[str]


@app.get("/")
async def root():
    return {
        "message": "Fake News Detector API",
        "status": "running",
        "endpoints": {
            "/analyze": "POST - Analyze news article",
            "/health": "GET - Health check"
        }
    }


@app.get("/health")
async def health_check():
    api_configured = GEMINI_API_KEY is not None
    return {
        "status": "healthy",
        "gemini_api_configured": api_configured
    }


@app.post("/analyze", response_model=NewsResponse)
async def analyze_news(request: NewsRequest):
    """
    Analyze news article for validity using Gemini AI.
    
    The model is configured with low temperature for strict fact-checking
    while being lenient on grammar/spelling issues.
    """
    if not GEMINI_API_KEY:
        raise HTTPException(
            status_code=500,
            detail="GEMINI_API_KEY not configured. Please set the environment variable."
        )
    
    try:
        # Configure model with strict settings for factual accuracy
        # Low temperature (0.1) ensures the model is less creative and more factual
        # This makes it strict about numbers, names, and crucial information
        model = genai.GenerativeModel(
            'gemini-1.5-pro',
            generation_config={
                'temperature': 0.1,  # Low temperature for strict, factual responses
                'top_p': 0.8,
                'top_k': 40,
                'max_output_tokens': 2048,
            }
        )
        
        # Craft a prompt that emphasizes factual accuracy over grammar
        prompt = f"""You are a strict fact-checker analyzing news articles. Your task is to determine if the following news article is likely REAL or FAKE.

ANALYSIS CRITERIA:
1. STRICT on factual accuracy: Check numbers, statistics, names, dates, locations, and verifiable facts
2. LENIENT on grammar/spelling: Minor grammatical errors or typos should NOT affect validity if the meaning is clear
3. Look for logical inconsistencies, impossible claims, or misleading information
4. Consider the credibility of claims made

NEWS ARTICLE TO ANALYZE:
{request.news_text}

Provide your analysis in the following format:
1. VERDICT: [REAL/FAKE/UNCERTAIN]
2. CONFIDENCE: [0-100]%
3. ANALYSIS: [Detailed explanation]
4. KEY FINDINGS: [List 3-5 key observations that support your verdict]

Be thorough but concise."""

        response = model.generate_content(prompt)
        analysis_text = response.text
        
        # Parse the response
        verdict = "UNCERTAIN"
        confidence = 50.0
        key_findings = []
        
        lines = analysis_text.split('\n')
        analysis_section = []
        
        for line in lines:
            line_lower = line.lower().strip()
            
            # Extract verdict
            if 'verdict:' in line_lower:
                if 'real' in line_lower and 'fake' not in line_lower:
                    verdict = "REAL"
                elif 'fake' in line_lower:
                    verdict = "FAKE"
                else:
                    verdict = "UNCERTAIN"
            
            # Extract confidence
            elif 'confidence:' in line_lower:
                # Try to extract percentage
                import re
                match = re.search(r'(\d+(?:\.\d+)?)', line)
                if match:
                    confidence = float(match.group(1))
            
            # Extract key findings
            elif line.strip().startswith(('-', '•', '*')) and len(line.strip()) > 5:
                finding = line.strip().lstrip('-•* ').strip()
                if finding and finding not in key_findings:
                    key_findings.append(finding)
            
            # Collect analysis text
            elif line.strip() and not any(keyword in line_lower for keyword in ['verdict:', 'confidence:', 'key findings:', 'analysis:']):
                if line.strip() and not line.strip().startswith(('1.', '2.', '3.', '4.')):
                    analysis_section.append(line.strip())
        
        # If no key findings were extracted, try to get them from the response
        if not key_findings:
            key_findings = [
                "Analysis completed - see detailed analysis for insights"
            ]
        
        # Limit to top 5 findings
        key_findings = key_findings[:5]
        
        analysis = ' '.join(analysis_section) if analysis_section else analysis_text
        
        is_valid = verdict == "REAL"
        
        return NewsResponse(
            is_valid=is_valid,
            confidence_score=confidence,
            analysis=analysis,
            key_findings=key_findings
        )
    
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error analyzing news: {str(e)}"
        )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
