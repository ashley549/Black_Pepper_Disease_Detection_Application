import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ml/classifier_provider.dart';
import '../../ml/disease_classifier.dart';
import '../../ml/tflite_classifier.dart';
import '../disease_info/disease_info_model.dart';
import '../history/history_repository.dart';
import '../disease_info/disease_info_repository.dart';
import '../gemini/gemini_advice_controller.dart';
import '../gemini/gemini_advice_service.dart';
import '../../core/app_config.dart';
import 'package:pepper_disease_app/ml/disease_prediction_router.dart';

enum ScanStatus { idle, analyzing, success, lowConfidence, notLeaf, error }

/// Holds everything the result screen needs for one scan.
class ScanState {
  final ScanStatus status;
  final File? image;
  final Prediction? prediction;
  final DiseaseInfo? diseaseInfo;
  final String? errorMessage;
  final PredictionSource? predictionSource;

  const ScanState({
    this.status = ScanStatus.idle,
    this.image,
    this.prediction,
    this.diseaseInfo,
    this.errorMessage,
    this.predictionSource,
  });

  ScanState copyWith({
    ScanStatus? status,
    File? image,
    Prediction? prediction,
    DiseaseInfo? diseaseInfo,
    String? errorMessage,
    PredictionSource? predictionSource,
  }) {
    return ScanState(
      status: status ?? this.status,
      image: image ?? this.image,
      prediction: prediction ?? this.prediction,
      diseaseInfo: diseaseInfo ?? this.diseaseInfo,
      errorMessage: errorMessage ?? this.errorMessage,
      predictionSource: predictionSource ?? this.predictionSource,
    );
  }
}

/// Router that determines which prediction engine to use:
/// - Gemini when online and available
/// - TFLite when offline or Gemini fails
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
      if (validLabels.contains(advice.summary.isNotEmpty ? _extractLabel(advice) : null)) {
        // Attach source metadata for fallback tracking
        return PredictionResult(
          diseaseLabel: _extractLabel(advice) ?? 'Healthy',
          classIndex: 0,
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
      classIndex: 0, // Will be set properly below
      confidence: tflitePrediction.confidence,
      explanation: tflitePrediction.label,
      predictionSource: PredictionSource.tflite,
    );
  }

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

/// Orchestrates: image in → classify → disease info (+ Gemini advice) out,
// with loading, success, low-confidence and error states (PRD Phase 4).
class ScanController extends StateNotifier<ScanState> {
  ScanController(Ref ref) : super(const ScanState()) {
    _ref = ref;
    _router = _DiseasePredictionRouter(
      tfliteClassifier: TfliteClassifier(),
      geminiService: GeminiAdviceService(),
    );
  }

  late final Ref _ref;
  late final _DiseasePredictionRouter _router;

  Future<void> startScan(File image) async {
    state = ScanState(status: ScanStatus.analyzing, image: image);

    try {
      // Use the router to classify the image (Gemini or TFLite)
      final predictionResult = await _router.classifyImage(image);

      // Build a Prediction from the result
      // Use 0.5 as default confidence if none available (Gemini qualitative)
      final confidence = predictionResult.confidence ?? 0.5;
      final prediction = Prediction(
        label: predictionResult.diseaseLabel,
        confidence: confidence,
        scores: _buildScoreMap(predictionResult.diseaseLabel),
        leafness: _estimateLeafness(predictionResult.diseaseLabel),
      );

      // Layer-1 defence against scenery/object photos using vegetation gate
      final leafness = prediction.leafness;
      if (leafness != null && leafness < AppConfig.leafGateThreshold) {
        state = ScanState(
          status: ScanStatus.notLeaf,
          image: image,
          prediction: prediction,
          predictionSource: predictionResult.predictionSource,
        );
        return;
      }

      // Get disease info from local repository
      final info = await _ref
          .read(diseaseInfoRepositoryProvider)
          .getByLabel(prediction.label);

      final lowConfidence =
          prediction.confidence != null &&
              prediction.confidence! < AppConfig.confidenceThreshold;

      // Run Gemini leaf verification (layer 2) only when we have a disease
      // prediction from TFLite. Gemini predictions already include leaf verification.
      if (predictionResult.predictionSource == PredictionSource.tflite &&
          !lowConfidence &&
          prediction.label != 'Healthy') {
        await _ref
            .read(geminiAdviceControllerProvider.notifier)
            .loadAdvice(
              diseaseLabel: prediction.label,
              diseaseName: info.displayName,
              confidence: prediction.confidence,
              leafImage: image,
            )
            .timeout(const Duration(seconds: 15), onTimeout: () {});

        final gemini = _ref.read(geminiAdviceControllerProvider);
        if (gemini.advice != null && !gemini.advice!.isLeafPhoto) {
          // Layer-2 rejection: Gemini says this photo is not a pepper leaf.
          state = ScanState(
            status: ScanStatus.notLeaf,
            image: image,
            prediction: prediction,
            predictionSource: PredictionSource.gemini,
          );
          return;
        }
        // Gemini unavailable/offline: fall through and show the result
      }

      state = ScanState(
        status: lowConfidence ? ScanStatus.lowConfidence : ScanStatus.success,
        image: image,
        prediction: prediction,
        diseaseInfo: info,
        predictionSource: predictionResult.predictionSource,
      );

      // Save to history (best effort; never blocks the result screen)
      await _ref.read(historyRepositoryProvider).addScan(
            imagePath: image.path,
            label: prediction.label,
            confidence: prediction.confidence,
            source: predictionResult.predictionSource,
          );
    } catch (_) {
      state = ScanState(
        status: ScanStatus.error,
        image: image,
        errorMessage: 'Could not analyse the leaf. Please try again.',
      );
    }
  }

  /// Builds a score map for the prediction result.
  Map<String, double> _buildScoreMap(String label) {
    final allLabels = AppConfig.placeholderLabels;
    final scores = <String, double>{};
    for (var i = 0; i < allLabels.length; i++) {
      scores[allLabels[i]] = i == allLabels.indexOf(label.replaceAll(' ', '_'))
          ? 1.0
          : 0.1;
    }
    return scores;
  }

  /// Estimates leafness based on the predicted disease label.
  double? _estimateLeafness(String label) {
    // Healthy leaves typically have higher leafness
    if (label == 'Healthy') return 0.8;
    // Other disease labels might still have vegetation
    return 0.5;
  }

  void reset() {
    _ref.read(geminiAdviceControllerProvider.notifier).reset();
    state = const ScanState();
  }
}

final scanControllerProvider =
    StateNotifierProvider<ScanController, ScanState>((ref) {
  return ScanController(ref);
});