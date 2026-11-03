import 'dart:io';

/// Output of any [DiseaseClassifier] (PRD Section 3.2).
class Prediction {
  final String label; // e.g. "healthy"
  final double confidence; // 0.0 to 1.0
  final Map<String, double> scores; // all classes

  /// Fraction of vegetation-looking pixels (ExG index) in the scanned photo,
  /// or null when the classifier does not measure it (mock). The scan flow
  /// uses it to reject non-leaf photos instead of trusting a forced label.
  final double? leafness;

  const Prediction({
    required this.label,
    required this.confidence,
    required this.scores,
    this.leafness,
  });

  /// Top-N predictions sorted by confidence (FR-12: show top 3).
  List<MapEntry<String, double>> get top3 {
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).toList();
  }
}

/// The ONLY ML boundary the UI is allowed to talk to (PRD rule 1).
abstract class DiseaseClassifier {
  /// Loads the model (no-op for the mock).
  Future<void> load();

  /// Classifies a leaf image and returns a [Prediction].
  Future<Prediction> classify(File image);

  /// Releases model resources.
  void dispose();
}
