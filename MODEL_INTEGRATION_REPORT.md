# Pepper Leaf Disease Detection App - Model Integration Report

## 1. Model Integration Overview

The application integrates a **TensorFlow Lite (TFLite) image classification model** running entirely on-device for black pepper leaf disease identification, with **Google Gemini** providing AI-powered treatment advice via REST API.

### Core Classification Pipeline:

```
Image Input → TFLite MobileNetV1 Classifier → Prediction → Disease Info Lookup → 
(if confident + not healthy) → Gemini API → AI Advice → Result Screen
```

### Key Integration Points:

| Component | Location | Purpose |
|-----------|----------|---------|
| **TFLite Classifier** | `lib/ml/tflite_classifier.dart` | Runs MobileNetV1 on-device, uses `IsolateInterpreter` for background execution |
| **Classifier Provider** | `lib/ml/classifier_provider.dart` | Riverpod provider - swappable between `TfliteClassifier` and `MockClassifier` |
| **Image Preprocessing** | `lib/ml/preprocessing.dart` | Resizes to 224x224, normalizes to [-1,1], computes ExG vegetation index |
| **Gemini Advice Service** | `lib/features/gemini/gemini_advice_service.dart` | REST call to `generativelanguage.googleapis.com` with photo + disease label |
| **Gemini Controller** | `lib/features/gemini/gemini_advice_controller.dart` | Riverpod state management for async advice loading |

## 2. Model Details

### Technical Specifications:

| Property | Value |
|----------|-------|
| **Model Architecture** | MobileNetV1 (float32, not quantized) |
| **Input Tensor** | `[1, 224, 224, 3]` float32, RGB, normalized to [-1, 1] |
| **Output Tensor** | `[1, 4]` float32 — softmax probabilities |
| **Class Labels** (from `labels.txt`) | 0=Healthy, 1=Leaf_blight, 2=Slow_decline, 3=Yellow_mottle_virus |
| **Model File** | `assets/models/mobilenetv1_v2_float32.tflite` |
| **Labels File** | `assets/labels/labels.txt` |
| **Preprocessing** | `(pixel - 127.5) / 127.5`; matches training `mobilenet.preprocess_input` |
| **Leaf Detection** | Excess-Green index: `2G - R - B`; threshold `0.12` rejects non-leaf photos |

### PRD References:
- **PRD Phase 9**: Real model wired in, `TfliteClassifier` implements `DiseaseClassifier` boundary
- **PRD rule 2**: Only `tflite_classifier.dart` may import `tflite_flutter`
- **PRD Section 3.2**: `DiseaseClassifier` abstract class with `classify(File image) → Prediction`
- **NFR-2**: UI never freezes — inference runs through background isolate

## 3. Performance Impact

### On-Device Classification:
- **No network latency** for the initial diagnosis — runs entirely locally
- **MobileNetV1 on modern phones**: ~10-50ms inference time
- **Background isolate** ensures UI thread never blocks (NFR-2)
- **Green fraction computation** (`ExG` index) adds minimal overhead (~1ms)

### Gemini API Integration:
- **Network-dependent** — requires internet for treatment advice
- **Timeout**: 45-second HTTP timeout, 15-second verification timeout in scan flow
- **Free-tier rate limiting**: 429 response handled gracefully

### Performance Safeguards:
1. **Vegetation gate** (leafness < 0.12) rejects non-leaf photos before Gemini call
2. **Low-confidence guard**: Skip Gemini verification for low-confidence predictions
3. **Healthy skip**: Skip Gemini for "Healthy" predictions (no disease claim to undo)
4. **Timeout fallback**: If Gemini takes >15s, show result anyway; advice card updates later

### Known Performance Considerations:
- **Mock classifier** has 800ms simulated delay (`AppConfig.mockInferenceDelay`) for testability
- **Real model** is lightweight — suitable for mobile devices
- **Memory**: TFLite interpreter + isolate overhead modest on modern devices

## 4. Internet Down Scenario

### What Still Works (No Internet Required):
| Feature | Status |
|---------|--------|
| **On-device classification** | ✅ Works — TFLite runs locally |
| **Disease info from `disease_info.json`** | ✅ Works — asset bundled in APK |
| **Leaf/non-leaf gate** | ✅ Works — ExG index computed locally |
| **History saving** | ✅ Works — local storage (SharedPreferences) |

### What Requires Internet:
| Feature | Failure Mode |
|---------|-------------|
| **Gemini AI advice** | ❌ Fails with user-friendly error message |
| **Alternative disease tips** | ⚠️ Falls back to "Not available. Please consult a local agriculture officer." |

### Graceful Degradation Flow (from `scan_controller.dart`):

1. **Classification succeeds** (on-device, no internet needed)
2. **Vegetation gate check** — if `leafness < 0.12`, shows "This doesn't look like a pepper leaf"
3. **Disease info lookup** — from bundled `disease_info.json`, always available
4. **Gemini verification** — **this is where internet is needed**:
   - If no internet: `SocketException` caught → shows "No internet connection. The AI advice needs to be online."
   - If timeout: Shows result anyway; advice-error card appears
   - If HTTP error: Shows result with error state
5. **Result screen** — displays:
   - Classification prediction + confidence
   - Disease description, symptoms, treatment, prevention (from JSON)
   - Gemini advice card (with error state if no internet)
   - History entry saved (best effort, never blocks result)

### User Experience When Internet Is Down:
- User takes photo → classification works immediately
- Diagnosis shown (e.g., "Leaf blight 92% confidence")
- Disease details from `disease_info.json` displayed (treatment, prevention from bundled data)
- Gemini advice card shows error: "No internet connection. The AI advice needs to be online."
- User can still view the on-device diagnosis and basic disease info
- Once internet is restored, re-running the scan fetches fresh Gemini advice

## 5. Summary

The app implements a **hybrid architecture**:

- **Core diagnosis**: On-device TFLite MobileNetV1 — works entirely offline, no performance dependency on network
- **Advanced advice**: Google Gemini REST API — requires internet, with graceful fallback when unavailable
- **Safety layer**: ExG vegetation gate prevents misclassification of non-leaf photos
- **Riverpod state management**: Clean separation of classification, disease info, and AI advice states

The integration was designed per the PRD's NFR-2 requirement (UI never freezes) by using `IsolateInterpreter` for TFLite inference, and the Gemini failure paths are fully handled with user-friendly messages rather than crashes. The on-device model ensures the app remains functional even without internet, though the AI-powered treatment recommendations will be unavailable in that scenario.

---

*Report generated on November 2, 2026*