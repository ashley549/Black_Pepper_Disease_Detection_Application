import 'dart:io';
import 'dart:math';

import '../core/app_config.dart';
import 'disease_classifier.dart';

/// Fake classifier used until the real TFLite model is ready (PRD Phase 2).
/// Returns plausible predictions so the entire app can be built now.
class MockClassifier implements DiseaseClassifier {
  final Random _random = Random();

  @override
  Future<void> load() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<Prediction> classify(File image) async {
    // Simulated inference delay so loading states can be built and tested.
    await Future<void>.delayed(AppConfig.mockInferenceDelay);

    // Occasionally return low confidence to exercise the "not sure" path.
    final lowConfidence = _random.nextDouble() < 0.2;
    final maxConfidence = lowConfidence ? 0.55 : 0.99;

    final top = _random.nextDouble() * (maxConfidence - 0.5) + 0.5;
    final labels = AppConfig.placeholderLabels;

    // Build a probability distribution over the placeholder labels.
    final scores = <String, double>{};
    var remaining = 1.0;
    for (var i = 0; i < labels.length; i++) {
      if (i == labels.length - 1) {
        scores[labels[i]] = remaining;
      } else if (i == 0) {
        final v = top.clamp(0.0, remaining);
        scores[labels[i]] = v;
        remaining -= v;
      } else {
        final v = _random.nextDouble() * remaining;
        scores[labels[i]] = v;
        remaining -= v;
      }
    }

    return Prediction(
      label: labels.first,
      confidence: scores[labels.first]!,
      scores: scores,
    );
  }

  @override
  void dispose() {
    // Nothing to release for the mock.
  }
}
