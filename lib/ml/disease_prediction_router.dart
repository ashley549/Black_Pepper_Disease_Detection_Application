import 'dart:async';

import 'package:tflite_flutter/tflite_flutter.dart';

import '../core/app_config.dart';
import '../ml/tflite_classifier.dart';
import '../features/gemini/gemini_advice.dart';
import '../features/gemini/gemini_advice_service.dart';
import 'disease_classifier.dart';
import 'preprocessing.dart';

/// The source of the disease prediction, used internally but not displayed.
enum PredictionSource { tflite, gemini }

/// Standardized prediction result compatible with both engines.
class PredictionResult {
  /// The diagnosed disease label (e.g. "Healthy", "Leaf_blight")
  final String diseaseLabel;

  /// The class index matching the model's training order
  final int classIndex;

  /// Confidence if meaningfully available, otherwise null
  /// Gemini confidence is qualitative, not calibrated probability
  final double? confidence;

  /// Optional explanation/description from the prediction
  final String? explanation;

  /// Internal metadata about which engine produced this prediction
  final PredictionSource predictionSource;

  /// Creates a [PredictionResult] with the given properties.
  const PredictionResult({
    required this.diseaseLabel,
    required this.classIndex,
    this.confidence,
    this.explanation,
    required this.predictionSource,
  });

  /// Human-readable display label with spaces instead of underscores.
  String get displayLabel {
    final spaced = diseaseLabel.replaceAll('_', ' ').trim();
    if (spaced.isEmpty) return diseaseLabel;
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}

/// Routes disease classification requests to the appropriate prediction engine.
///
/// The router determines whether to use Gemini (when online and available) or
/// TFLite (offline/fallback) and returns a standardized prediction result.
/// The calling UI never needs to know which engine was used.
class _DiseasePredictionRouter {
  _DiseasePredictionRouter({
    required TfliteClassifier tfliteClassifier,
    required GeminiAdviceService geminiService,
  }) : _tfliteClassifier = tfliteClassifier,
       _geminiService = geminiService;

  final TfliteClassifier _tfliteClassifier;
  final GeminiAdviceService _geminiService;

  /// Classifies an image using the appropriate engine.
  /// Tries Gemini first if online, falls back to TFLite otherwise.
  Future<PredictionResult> classifyImage(File image) async {
    // Try Gemini classification
    try {
      final advice = await _geminiService.getAdvice(
        diseaseLabel: '',
        diseaseName: '',
        confidence: 0.0,
        leafImage: image,
      );

      // Validate the Gemini result has a valid disease label
      final validLabels = ['Healthy', 'Leaf_blight', 'Slow_decline', 'Yellow_mottle_virus'];
      final classifiedLabel = _extractLabel(advice, validLabels);

      if (classifiedLabel != null && validLabels.contains(classifiedLabel)) {
        // Attach source metadata for fallback tracking
        return PredictionResult(
          diseaseLabel: classifiedLabel,
          classIndex: _getClassIndex(classifiedLabel),
          confidence: 0.8,
          explanation: advice.immediateSteps,
          predictionSource: PredictionSource.gemini,
        );
      }
      // If Gemini returned an invalid label, fall through to TFLite
    } on GeminiAdviceException {
      // Gemini failed - fall through to TFLite
    } catch (_) {
      // Any error from Gemini - fall through to TFLite
    }

    // Fall back to TFLite classifier
    final tflitePrediction = await _tfliteClassifier.classify(image);
    return PredictionResult(
      diseaseLabel: tflitePrediction.label,
      classIndex: _getClassIndex(tflitePrediction.label),
      confidence: tflitePrediction.confidence,
      explanation: tflitePrediction.label,
      predictionSource: PredictionSource.tflite,
    );
  }

  /// Extracts a disease label from Gemini advice text
  String? _extractLabel(GeminiAdvice advice, List<String> validLabels) {
    final text = '${advice.summary} ${advice.treatment} ${advice.prevention}'.toLowerCase();

    for (final label in validLabels) {
      if (text.contains(label.toLowerCase())) {
        return label;
      }
    }
    return null;
  }

  /// Maps a disease label to its class index (0=Healthy, 1=Leaf_blight, etc.)
  int _getClassIndex(String label) {
    final labels = ['Healthy', 'Leaf_blight', 'Slow_decline', 'Yellow_mottle_virus'];
    return labels.indexOf(label);
  }
}