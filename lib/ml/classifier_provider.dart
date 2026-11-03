import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'disease_classifier.dart';
import 'mock_classifier.dart';
import 'tflite_classifier.dart';

/// The one dependency swap point for Phase 9: change this line from
/// [MockClassifier] to [TfliteClassifier] and no screen code changes
/// (PRD Section 2).
///
/// Phase 9 status: the real model is wired in. To fall back to the mock
/// (e.g. for emulator screenshots or tests), swap the returned class here.
final classifierProvider = Provider<DiseaseClassifier>((ref) {
  return TfliteClassifier();
});
