from typing import List, Optional, Literal, Dict, Any
from pydantic import BaseModel, Field

class SourceMetadata(BaseModel):
    type: Literal["text", "url", "image", "document"]
    provided_url: Optional[str] = None
    page_title: Optional[str] = None

class GroundingCitation(BaseModel):
    id: int = 0  # 1-indexed source ID
    title: str = ""
    url: Optional[str] = ""
    snippet: str = ""
    source_file: Optional[str] = None
    status: str = "live"

class ScannedSource(BaseModel):
    id: int # 1-indexed source ID
    title: str
    url: str
    is_cited: bool

class MediaLiteracy(BaseModel):
    logical_fallacies: List[str]
    tone_analysis: str

class Segment(BaseModel):
    startIndex: int
    endIndex: int
    text: str

class GroundingSupport(BaseModel):
    segment: Segment
    groundingChunkIndices: List[int]
    confidenceScores: List[float] = []

class SourceAudit(BaseModel):
    id: int # Keep for backward compatibility or use as generic ID
    source_index: int
    chunk_index: int
    domain: str
    score: float
    quote_text: str
    confidence: Optional[float] = 0.0
    authority: Optional[float] = 0.0
    is_verified: bool = False

class SegmentAudit(BaseModel):
    text: str
    top_source_domain: str
    top_source_score: float  # The Max(Conf * Auth) for this segment
    sources: List[SourceAudit] = []

class ReliabilityMetrics(BaseModel):
    reliability_score: float    # Final clamped (0.0 - 1.0) (Formerly 'score')
    ai_confidence: float        # LLM self-reported confidence
    base_grounding: float       # Global Average of SegmentAudit scores
    consistency_bonus: float    # +0.05 if unique_domains > 1, else 0.0
    multimodal_bonus: float     # +0.05 if file upload matches web, else 0.0
    verdict_label: str          # "High", "Medium-High", "Medium", "Low"
    explanation: str            # Forensic summary
    segments: List[SegmentAudit]
    unused_sources: List[Dict[str, str]] = []

class InputPart(BaseModel):
    type: Literal["text_claim", "image", "document", "url"]
    content: Optional[str] = None  # For text_claim
    mime_type: Optional[str] = None  # For image, document
    data: Optional[str] = None  # Base64 string for image, document
    value: Optional[str] = None  # For url

class AnalysisSettings(BaseModel):
    enable_grounding: bool = True
    forensic_depth: Literal["low", "medium", "high"] = "medium"

class AnalysisRequest(BaseModel):
    request_id: str
    parts: List[InputPart]
    settings: Optional[AnalysisSettings] = Field(default_factory=AnalysisSettings)

class Source(BaseModel):
    id: str
    title: str
    url: str
    cited_segment: str
    source_context: str
    favicon_url: Optional[str] = None

class AnalysisResponse(BaseModel):
    verdict: str = "UNVERIFIABLE"
    confidence_score: float = 0.0
    analysis: str = "**1. The Core Claim(s):**\nThe data could not be parsed.\n\n**2. Evidence Breakdown:**\n* The AI returned malformed data or was blocked by safety filters."
    multimodal_cross_check: Optional[bool] = False
    source_metadata: Optional[Dict[str, Any]] = None
    grounding_citations: List[GroundingCitation] = []
    scanned_sources: List[ScannedSource] = []
    grounding_supports: List[GroundingSupport] = []
    media_literacy: Optional[MediaLiteracy] = None
    reliability_metrics: Optional[ReliabilityMetrics] = None
    sources: List[Source] = []
