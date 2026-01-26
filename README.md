# Fake News Detector

A comprehensive fake news detection application powered by Google's Gemini AI API.

## 🎯 Overview

This application uses advanced AI to analyze news articles and determine their validity. The system is:
- **Strict on facts**: Precisely validates numbers, statistics, names, dates, and locations
- **Lenient on grammar**: Focuses on meaning rather than perfect grammar or spelling
- **Powered by Gemini AI**: Uses Google's latest Gemini 1.5 Pro model with low temperature (0.1) for factual accuracy

## 🏗️ Architecture

### Backend (Python/FastAPI)
- RESTful API built with FastAPI
- Integrates with Google Gemini AI API
- Configured for strict fact-checking with low temperature settings
- CORS-enabled for cross-platform frontend support

### Frontend (Flutter)
- Cross-platform mobile app (iOS, Android, Web)
- Clean Material Design 3 UI
- Real-time news analysis
- Detailed results display with confidence scores

## 🚀 Quick Start

### Prerequisites
- Python 3.8+ (for backend)
- Flutter SDK 3.0+ (for frontend)
- Google Gemini API key ([Get one here](https://makersuite.google.com/app/apikey))

### 1. Setup Backend

```bash
# Navigate to backend directory
cd backend

# Install dependencies
pip install -r requirements.txt

# Configure API key
cp .env.example .env
# Edit .env and add your GEMINI_API_KEY

# Run the server
python main.py
```

The backend will be available at http://localhost:8000

### 2. Setup Frontend

```bash
# Navigate to frontend directory
cd frontend

# Install dependencies
flutter pub get

# Update backend URL in lib/services/api_service.dart if needed

# Run the app
flutter run
```

## 📁 Project Structure

```
Gemini3Pro/
├── backend/              # Python FastAPI backend
│   ├── main.py          # Main API application
│   ├── requirements.txt # Python dependencies
│   ├── .env.example     # Environment variables template
│   └── README.md        # Backend documentation
│
├── frontend/            # Flutter mobile app
│   ├── lib/
│   │   ├── main.dart           # App entry point
│   │   ├── models/             # Data models
│   │   ├── screens/            # UI screens
│   │   └── services/           # API services
│   ├── pubspec.yaml    # Flutter dependencies
│   └── README.md       # Frontend documentation
│
└── README.md           # This file
```

## 🔧 Configuration

### Backend Configuration
The Gemini AI model is configured with:
- **Temperature: 0.1** - Ensures strict, factual responses
- **Model: gemini-1.5-pro** - Latest advanced model
- **Focus**: Factual accuracy over grammar/spelling

### Frontend Configuration
Update the backend URL in `frontend/lib/services/api_service.dart`:
- Android emulator: `http://10.0.2.2:8000`
- iOS simulator: `http://localhost:8000`
- Physical device: `http://YOUR_COMPUTER_IP:8000`

## 📖 Usage

1. Start the backend server
2. Launch the Flutter app
3. Enter a news article in the text field
4. Tap "Analyze" to check the article
5. View results:
   - Verdict (Real/Fake)
   - Confidence score (0-100%)
   - Detailed analysis
   - Key findings

## 🧪 API Endpoints

### `GET /`
Root endpoint with API information

### `GET /health`
Health check and API status

### `POST /analyze`
Analyze news article

**Request:**
```json
{
  "news_text": "Your news article here..."
}
```

**Response:**
```json
{
  "is_valid": true,
  "confidence_score": 85.0,
  "analysis": "Detailed analysis...",
  "key_findings": ["Finding 1", "Finding 2", "..."]
}
```

## 📝 Example

**Input:**
```
Breaking: Scientists discover new planet with 3 moons orbiting Alpha Centauri
```

**Output:**
- Verdict: FAKE
- Confidence: 75%
- Analysis: While Alpha Centauri is a real star system, the specific claim about a new planet with 3 moons requires verification...
- Key Findings:
  - Alpha Centauri is a real star system
  - No recent announcements of new planet discoveries
  - Claim lacks specific source or date

## 🛡️ Features

- ✅ Gemini AI integration for intelligent analysis
- ✅ Strict fact-checking (numbers, names, dates)
- ✅ Grammar-lenient analysis
- ✅ Cross-platform Flutter app
- ✅ RESTful API backend
- ✅ Real-time analysis
- ✅ Confidence scoring
- ✅ Detailed explanations

## 📄 License

This project was created for KitaHack2026.

## 🤝 Contributing

This is a hackathon project. Feel free to fork and improve!

## 📞 Support

For issues or questions:
1. Check the individual README files in backend/ and frontend/
2. Review the API documentation at http://localhost:8000/docs (when running)
3. Check Gemini AI documentation for API-related questions
