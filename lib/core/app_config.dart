/// Central configuration for the whole app (PRD rule: every configurable
/// value lives here so nothing is scattered through the code).
class AppConfig {
  AppConfig._();

  // ------------------------------------------------------------------
  // ML placeholders (Section 2.1 of the PRD - replace when model is final)
  // ------------------------------------------------------------------
  /// Input size the model expects (224x224 for MobileNet).
  static const int inputSize = 224;

  /// Predictions below this confidence show the "not sure" state.
  static const double confidenceThreshold = 0.60;

  /// Fraction (0-1) of vegetation-looking pixels (excess-green index, see
  /// preprocessing.dart) required for a photo to be treated as a leaf scan.
  /// Below this the scan shows "This doesn't look like a pepper leaf"
  /// instead of a forced disease label — counters objects/scenery being
  /// classified. Measured values: real leaf field photo 0.22+, synthetic
  /// leaf 0.36, brown furniture/room 0.00, dark neon-green poster 0.11.
  /// 0.12 rejects the observed scenery cases with ~2x margin for real
  /// leaves. Note: a mostly-neon image could still pass this cheap offline
  /// gate; the Gemini advice call double-checks leaf-ness online.
  static const double leafGateThreshold = 0.12;

  /// Fallback class labels in exact training index order; the app loads
  /// assets/labels/labels.txt at runtime and only uses this if that file is
  /// missing. Real classes (Phase 9): 0=Healthy, 1=Leaf_blight,
  /// 2=Slow_decline, 3=Yellow_mottle_virus.
  static const List<String> placeholderLabels = [
    'Healthy',
    'Leaf_blight',
    'Slow_decline',
    'Yellow_mottle_virus',
  ];

  /// Asset paths for the real model (v2 retrain, Oct 2026).
  static const String modelAssetPath =
      'assets/models/mobilenetv1_v2_float32.tflite';
  static const String labelsAssetPath = 'assets/labels/labels.txt';
  static const String diseaseInfoAssetPath = 'assets/data/disease_info.json';

  // ------------------------------------------------------------------
  // Real model facts (verified by inspecting mobilenetv1_v2_float32.tflite)
  // ------------------------------------------------------------------
  /// Input tensor: [1, 224, 224, 3] float32, RGB, normalised to [-1, 1]
  /// via (pixel - 127.5) / 127.5 (matches training's mobilenet.preprocess_input).
  /// Output tensor: [1, 4] float32 — softmax probabilities, one per class
  /// in labels.txt order (0=Healthy, 1=Leaf_blight, 2=Slow_decline,
  /// 3=Yellow_mottle_virus). If training changes any of these, update BOTH
  /// this file and lib/ml/preprocessing.dart.
  static const List<int> modelInputShape = [1, 224, 224, 3];
  static const int modelOutputClasses = 4;

  /// Simulated delay for the [MockClassifier] so loading states are testable.
  static const Duration mockInferenceDelay = Duration(milliseconds: 800);

  // ------------------------------------------------------------------
  // Gemini AI (treatment advice for identified diseases)
  // ------------------------------------------------------------------
  /// Inject with --dart-define-from-file=.env.json at build/run time.
  /// Client-side keys can still be extracted from a compiled app.
  static const String geminiApiKey =
      String.fromEnvironment('GEMINI_API_KEY');

  /// Free-tier fast model. Pinned to 3.5-flash-lite (working + generous free
  /// tier). NOTE: Google retired gemini-2.5-flash for new API keys (HTTP 404
  /// "no longer available to new users"), which broke AI advice with
  /// "Gemini error (HTTP 404)". If this 404s again in the future, list the
  /// models available to the key and pick a working flash-lite:
  /// GET `https://generativelanguage.googleapis.com/v1beta/models?key=<KEY>`
  static const String geminiModel = 'gemini-3.5-flash-lite';

  /// REST endpoint for non-streaming text generation.
  static const String geminiApiEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$geminiModel:generateContent';
}
