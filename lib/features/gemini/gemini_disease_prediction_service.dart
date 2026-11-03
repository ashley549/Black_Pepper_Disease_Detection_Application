import 'dart:async';
import 'dart:io';

import 'package:pepper_disease_app/features/gemini/gemini_advice_service.dart';
import 'package:pepper_disease_app/features/gemini/gemini_advice.dart';
import 'package:pepper_disease_app/ml/disease_prediction_router.dart';

/// Service that uses Gemini REST API for disease classification.
///
/// Wraps the existing [GeminiAdviceService] to perform disease classification
/// from leaf images. Returns structured prediction results or indicates
/// that classification is not possible.
class GeminiDiseasePredictionService {
  GeminiDiseasePredictionService({
    GeminiAdviceService? service,
  }) : _service = service ?? GeminiAdviceService();

  final GeminiAdviceService _service;

  /// Attempts to classify a leaf image using Gemini AI.
  ///
  /// Returns a [PredictionResult] if Gemini successfully classifies the disease,
  /// or throws a [GeminiClassificationException] if classification fails for
  /// any reason (network, API error, invalid response, unsupported label).
  ///
  /// The result is normalized to the app's 4-class system. Gemini confidence
  /// values are qualitative and not presented as calibrated probabilities.
  Future<PredictionResult> classifyImage(File image) async {
    try {
      final advice = await _service.getAdvice(
        diseaseLabel: '',
        diseaseName: '',
        confidence: 0.0,
        leafImage: image,
      );

      // Validate and extract the disease label
      final classifiedLabel = _extractAndValidateLabel(advice);

      // If no valid label, throw exception (will fall back to TFLite)
      if (classifiedLabel == null) {
        throw GeminiClassificationException(
          'Gemini did not return a recognized disease label.',
        );
      }

      // Map to class index
      final classIndex = _getClassIndex(classifiedLabel);

      // Gemini provides qualitative confidence; we use a reasonable default
      // but do NOT present it as a calibrated probability
      final confidence = _deriveConfidenceFromAdvice(advice);

      return PredictionResult(
        diseaseLabel: classifiedLabel,
        classIndex: classIndex,
        confidence: confidence,
        explanation: advice.immediateSteps.isNotEmpty
            ? advice.immediateSteps
            : advice.summary.isNotEmpty
                ? advice.summary
                : null,
        predictionSource: PredictionSource.gemini,
      );
    } on GeminiAdviceException catch (e) {
      rethrowGeminiException(e);
    } catch (_) {
      rethrowGenericException();
    }
  }

  /// Extracts and validates the disease label from Gemini advice.
  /// Returns the label if it matches one of the 4 supported classes, or null.
  String? _extractAndValidateLabel(GeminiAdvice advice) {
    final validLabels = ['Healthy', 'Leaf_blight', 'Slow_decline', 'Yellow_mottle_virus'];
    final text = '${advice.summary} ${advice.treatment} ${advice.prevention}'.toLowerCase();

    // Check each valid label appears in the Gemini response text
    for (final label in validLabels) {
      final formattedLabel = label.toLowerCase();
      if (text.contains(formattedLabel)) {
        return label;
      }
    }

    // Also check the full advice text for any label match
    for (final label in validLabels) {
      if (text.contains(label.toLowerCase())) {
        return label;
      }
    }

    return null;
  }

  /// Derives a qualitative confidence score from Gemini advice.
  /// This is NOT a calibrated probability - it's just a heuristic indicator.
  double _deriveConfidenceFromAdvice(GeminiAdvice advice) {
    // Base confidence if Gemini provided a clear classification
    if (advice.summary.isNotEmpty && advice.treatment.isNotEmpty) {
      return 0.80; // High confidence in the classification
    }

    // Moderate confidence if we have some information
    if (advice.summary.isNotEmpty || advice.treatment.isNotEmpty ||
        advice.prevention.isNotEmpty) {
      return 0.60;
    }

    // Low confidence if we only have basic info
    return 0.40;
  }

  /// Maps a disease label to its class index (0=Healthy, 1=Leaf_blight, etc.)
  int _getClassIndex(String label) {
    final labels = ['Healthy', 'Leaf_blight', 'Slow_decline', 'Yellow_mottle_virus'];
    return labels.indexOf(label);
  }

  /// Converts a [GeminiAdviceException] to a [GeminiClassificationException].
  void rethrowGeminiException(GeminiAdviceException e) {
    if (e.message.contains('no internet')) {
      throw GeminiClassificationException(
        'No internet connection. Switching to local model.',
      );
    }
    if (e.message.contains('429') || e.message.contains('limit')) {
      throw GeminiClassificationException(
        'Gemini API quota exhausted. Using local model.',
      );
    }
    if (e.message.contains('404') || e.message.contains('no longer available')) {
      throw GeminiClassificationException(
        'Gemini model is no longer available. Using local model.',
      );
    }
    if (e.message.contains('403') || e.message.contains('API key')) {
      throw GeminiClassificationException(
        'Gemini API configuration error. Using local model.',
      );
    }
    // Generic Gemini error - fall back to local model
    throw GeminiClassificationException(
      'Gemini classification failed. Using local model.',
    );
  }

  /// Converts unexpected errors to [GeminiClassificationException].
  void rethrowGenericException() {
    throw GeminiClassificationException(
      'Gemini classification error. Using local model.',
    );
  }
}

/// Exception thrown when Gemini classification fails.
class GeminiClassificationException implements Exception {
  final String message;
  GeminiClassificationException(this.message);

  @override
  String toString() => message;
}