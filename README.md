# VeriScan: Antigravity Update 🚀

VeriScan is a multimodal fact-checking dashboard powered by Google's Gemini 2.0 Flash model with Google Search Grounding. It analyzes text, URLs, and images to provide forensic verdicts on potential misinformation.

## Technology Stack

- **AI Engine:** GCP Vertex AI (Gemini 2.0 Flash) for multimodal processing of text, images,pdfs and links.
- **Backend:** Python & FastAPI acting as a high-performance orchestrator for AI inference.
- **Frontend:** Flutter for a consistent, high-performance UI across Web and Mobile deployments.
- **Database & Hosting:** Firebase (Firestore & Hosting) for scalable data storage, and rapid deployment.

## 💡 Innovation & Unique Selling Point (USP)

- **Direct-Share Listener:** VeriScan features a system-level integration allowing users to share media directly from apps like WhatsApp, Instagram, and Facebook via native "Share Sheets".
- **Multimodal Reasoning:** Unlike traditional tools, VeriScan uses Vertex AI to perform cross-modal analysis, checking if an image/pdf's visual context contradicts the claims in the associated text.
- **Human-in-the-Loop:** A unique Community Vote feature allows everyday users to verify AI verdicts, adding cultural nuance and building collective trust.
- **"Try With Demo" Onboarding:** To solve the "cold start" problem, VeriScan features a guided ingestion flow. It loads pre-configured forensic case studies (e.g., medical claims about lemon water) to teach users how to navigate the Explainable AI (XAI) dashboard, audit trails, and tooltips before they analyze their own data.
- **Explainable Grounding:** Every verdict includes a forensic breakdown of logical fallacies and evidence cards linked to real-world sources via Google Search Grounding.

## 🖱️ Interactive UI & Forensic Navigation
VeriScan is designed for radical transparency. We don’t just show results; we show the work behind them through interactive elements:

- **Underlined Claims**: Every verifiable claim in a story is highlighted. Clicking an underline focuses the analysis on that specific "factual atom."
- **Audit Trays (Micro-Audit)**: Triggered by clicking claims, these slide-out panels show the exact high-fidelity text snippets extracted from source documents used for verification.
- **Reliability Rings**: Dynamic circular gauges that visualize the Composite Reliability Metric.
- **Reliability Reveal**: Clicking on the ring reveals the specific mathematical breakdown: confidence score * authority scale

- **Info Icons (XAI Help)**: Found next to every metric (Verdict, AI Certainty, Reliability). These provide instant tooltips explaining the technical definition of the score to improve user media literacy.

## ⚙️ Core Mechanics: Composite Forensic Reliability Engine

VeriScan has moved beyond simple "AI confidence" metrics. We now use a **Composite Reliability Metric** that provides objective trust scores visualized through interactive Reliability Rings. Our systems are built upon the [Vertex AI Grounding Metadata](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/reference/rest/v1beta1/GroundingMetadata?hl=en#GroundingSupport) framework to ensure high-fidelity evidence mapping.

### Mathematical Foundations

#### 1. Contextual Reliability (Local Claim Score)
Calculated per factual segment to determine the specific trust level of an individual claim.
$$Score_{seg} = \max(Conf_i \times Auth_j)$$

#### 2. Base Grounding (Global Score)
Represents the core factual density across the entire analysis.
$$BaseScore = \frac{1}{n} \sum_{i=1}^{n} \max(Conf_i \times Auth_j)$$

**Variables:**
- $Conf_i$: Grounding confidence returned by the Gemini API.
- $Auth_j$: Domain Authority Weight.

### Forensic Source Logic & Authority Heuristics
The $Auth_j$ variable is determined by a strict hierarchical fallback system:
- **1.00:** Verified Fact-Checkers (IFCN/INSIGHT) & Official Institutional (.gov, .edu)
- **0.90:** Established Global News
- **0.80:** Crowd-Sourced Knowledge (Wikipedia)
- **0.70:** Standard Reputable Domains
- **0.40:** User-Generated Content (Reddit, social media)

### Verification Bonuses
The final reliability score is calibrated with two mathematical boosts:
- **Consistency Bonus (+0.05):** Applied when a factual segment is supported by at least three distinct domains to mitigate single-source bias.
- **Multimodal Bonus (+0.05):** Applied if a textual claim is cross-referenced and confirmed by Gemini vision models analyzing user-uploaded images or documents.

## Features
- **8-Tier Verdict System**: To handle the nuances of modern misinformation, VeriScan employs a precision lexicon:
    - `TRUE`: The claim is 100% factual based on external evidence.
    - `MOSTLY_TRUE`: The core claim is factual but contains minor technicalities or rounding errors.
    - `MIXTURE`: The input contains multiple facts where some are true and others are false.
    - `MISLEADING`: The facts are technically true but presented to imply a false conclusion.
    - `MOSTLY_FALSE`: The core claim is false but contains a minor element of truth.
    - `FALSE`: The core claim is refuted by external search results.
    - `UNVERIFIABLE`: Insufficient independent grounding data exists to reach a conclusion.
    - `NOT_A_CLAIM`: Subjective opinions, predictions, or non-factual statements.
- **Source Categorization**: VeriScan distinguishes between tiers of evidence:
    1.  **Scanned Sources**: The complete list of documents, URLs, and images analyzed by the forensic engine.
    2.  **Cited Sources**: Specific documents used to verify or refute a claim.
    3.  **Verified Sources**: Trusted authorities (e.g., IFCN signatories) and established databases like [factcheckinsights.org](https://factcheckinsights.org).
- **Multimodal Input**: Text, URL,PDF and Image analysis.
- **Google Search Grounding**: Evidence cards linked to real-world sources.
- **Bento Grid Dashboard**: A "Obsidian & Gilded" themed high-performance UI.

## Challenges Faced
- **Multi-Platform Integration**: We encountered significant "Java version" configurations and library compatibility issues where certain Dart packages worked on Web but failed on Mobile. We resolved this by auditing our dependencies and switching to strictly cross-platform compatible libraries.
- **CORS & API Connectivity**: During the implementation of the Community Vote feature, we faced `ClientException: Failed to fetch` errors due to Cross-Origin Resource Sharing (CORS) restrictions. We implemented custom CORS middleware in FastAPI and refactored the frontend to dynamically generate backend URLs based on the environment.

## ⚖️ Technical Trade-offs & Architecture Decisions

### 1. Model Selection: Metadata vs. Versioning
During development, we faced a critical choice between using the latest experimental versions of Gemini or the stable **Gemini 2.0 Flash** release.

* **The Conflict:** Newer experimental iterations (e.g., certain 2.1 previews) are optimized for conversational fluency and creative reasoning. However, these versions lacked the granular **Grounding Metadata** required for our forensic engine. Specifically, the `confidence_scores` array—which maps the AI's mathematical certainty to specific source chunks—was unavailable or inconsistent in newer versions.
* **The Trade-off:** We chose **Gemini 2.0 Flash** as our core engine, prioritizing data depth over model recency.
* **The Rationale:** Our project’s unique value proposition is the **Source Reliability Metric**:
    $$Score_{context} = Confidence_{segment} \times Authority_{source}$$
    Without the raw confidence metadata provided by the 2.0 Flash API, we could not calculate our **Radial Reliability Rings** or provide the "Factual Breakdown" tooltips. We prioritized **Verification Accuracy** over **Generative Novelty**.

- **Accuracy vs. Latency Trade-off**: Balancing the deep-search capabilities of Google Search Grounding with user expectations for speed was a hurdle. We prioritized accuracy, deciding that a slightly longer wait for a verified, evidence-backed verdict was more valuable than a near-instant but ungrounded response.


---

## 🛠️ Setup Instructions

### Prerequisites
- **Python 3.10+**
- **Flutter SDK** (Latest Stable)
- **Google Cloud Service Account** (`service-account.json`) with Vertex AI permissions.

### 1. Backend Setup
Navigate to the `backend` directory:
```bash
cd backend
```

Install dependencies:
```bash
pip install -r requirements.txt
```

**Important**: Ensure your `service-account.json` key is placed in the `backend/` directory.

Run the server:
```bash
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
*The API will be available at `http://localhost:8000`.*

### 2. Frontend Setup
Navigate to the `frontend` directory:
```bash
cd frontend
```

Get dependencies:
```bash
flutter pub get
```

Run the app (Chrome recommended for dev):
```bash
flutter run -d chrome
```

---

## ⚠️ Troubleshooting
- **Backend 400 Errors**: Ensure you have valid credentials in `service-account.json`.
- **Image Upload Failures**: The app supports `.jpg`, `.jpeg`, and `.png`.

---

**Built with 🖤 by the VeriScan Team**
