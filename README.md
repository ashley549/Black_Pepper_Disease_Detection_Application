# Pepper Leaf Disease Detection Application

A Flutter app that identifies **black pepper leaf diseases** from a photo (on-device) 
and then fetches an **AI-powered possible solution from Google Gemini** for the identified disease.

Built from `pepper_disease_app_PRD.md` for a college major project.

## ✨ Features

| Requirement | Status |
|---|---|
| FR-1 Capture photo with camera | ✅ |
| FR-2 Pick photo from gallery | ✅ |
| FR-3 Classify via `DiseaseClassifier` + loading state | ✅ |
| FR-4 Display prediction result with confidence | ✅ |
| FR-5 Low confidence handling | ✅ |
| FR-6 Treatment/Prevention/Symptoms info | ✅ |
| FR-12 Top 3 predictions display | ✅ |
| FR-14 Light/dark mode support | ✅ |

## 🤖 Dual-Engine Prediction Architecture

This application features a **dual-engine disease prediction system**:

### Scenario A: Internet Available
- **Gemini AI** performs disease classification from the leaf image
- Uses Google Gemini REST API for analysis
- Returns structured diagnosis from 4 supported classes

### Scenario B: Internet Unavailable  
- **TensorFlow Lite MobileNetV1** performs on-device classification
- No network dependency - works completely offline
- Same user interface regardless of engine

### Scenario C: Internet Available but Gemini Fails
- Silently falls back to TFLite model
- No error messages shown to user
- Seamless experience without interruption

**Key Point:** The user interface is **provider-neutral** - the same result layout 
is shown regardless of which prediction engine (Gemini or MobileNetV1) produced 
the classification. No labels like "Powered by Gemini" or "AI model is processing" 
are displayed.

## 🏗️ Architecture

```
Scan Flow:
1. Image captured/gallery pick → 2. Preprocessing (resize, normalize) → 
3. DiseasePredictionRouter → 4. Gemini OR TFLite → 5. PredictionResult → 
6. Result Screen (consistent UI)

Prediction Engine Routing:
- Internet + Gemini success → Gemini classification
- Internet + Gemini fail → TFLite fallback  
- No internet → TFLite directly
- Any error → TFLite fallback (silent, no UI indication)
```

## 📱 Screens

### Home Screen
- Scan new leaf button
- View scan history
- Settings access

### Scan Screen
- Camera view with scanning animation
- Real-time leafness vegetation gate
- Prediction results overlay

### Result Screen
- Disease name + confidence bar
- Top 3 predictions
- Symptoms, Treatment, Prevention sections
- Disclaimer: "This guidance is indicative only..."
- Scan Another Leaf button
- **No Gemini AI advice visible** (hidden as per requirements)

### Settings Screen
- Language selection (English, Malayalam, Hindi)
- Dark Mode toggle
- App info (Pepper Leaf Doctor, Version 1.0.0)
- Model info (MobileNet quantized, TFLite)
- **AI advice card removed** (per user request)

## 🔧 Technical Details

### Model Information
- **Primary Model**: MobileNetV1 (quantized, TensorFlow Lite)
- **Input**: 224×224 RGB images, normalized to [-1, 1]
- **Classes**: Healthy, Leaf_blight, Slow_decline, Yellow_mottle_virus
- **Preprocessing**: (pixel - 127.5) / 127.5, ExG vegetation index gate

### Gemini Integration
- **API**: Google Generative AI Studio (gemini-3.5-flash-lite)
- **Purpose**: Disease classification + treatment advice
- **Key**: Embedded in `app_config.dart` (per college project requirements)
- **Behavior**: Primary classifier when online, silent fallback on failure

### State Management
- **Riverpod** for all state management
- **GoRouter** for navigation
- **SQLite** for scan history local storage

### Offline-First Design
- All prediction works offline via TFLite
- No network required for basic classification
- Gemini adds AI-powered treatment advice when online
- Complete gracefully when offline or Gemini unavailable

## 🧪 Testing

Test scenarios include:
1. Internet available + Gemini classifies successfully
2. Internet unavailable + MobileNet classifies on-device
3. Internet available + Gemini times out → TFLite fallback
4. Gemini returns malformed JSON → TFLite fallback
5. Gemini returns unsupported label → TFLite fallback
6. Gemini API quota exhausted → TFLite fallback
7. Multiple scans without duplicate requests
8. Occlusion sensitivity works for MobileNet predictions
9. Gemini advice remains functional when online
10. Interface never reveals which engine was used

## 📦 Project Structure

```
lib/
├── core/           - Theme, router, app config
├── features/       - Home, Scan, Result, Settings, History screens
├── ml/             - DiseaseClassifier, TfliteClassifier, 
│                    PredictionRouter, PredictionResult
│                    GeminiDiseasePredictionService
├── gemini/         - GeminiAdviceService, GeminiAdviceController
├── ml/             - preprocessing.dart, disease_classifier.dart
└── core/           - app_config.dart (configs, labels, model paths)
```

## 🚀 Getting Started

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run

# Build APK
flutter build apk --release
```

## 📝 Notes

- Gemini API key is embedded in `lib/core/app_config.dart` (college project)
- Application respects user request to hide AI advice UI
- All prediction works without internet via TFLite model
- No backend server required - fully on-device + optional AI
- Occlusion Sensitivity explanation feature preserved for TFLite predictions