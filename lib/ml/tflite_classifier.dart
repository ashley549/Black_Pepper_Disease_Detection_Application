import 'dart:io';

import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../core/app_config.dart';
import 'disease_classifier.dart';
import 'preprocessing.dart';

/// Real on-device classifier running the quantised/floating MobileNetV1
/// `.tflite` model (PRD Phase 9). Implements the same [DiseaseClassifier]
/// boundary as [MockClassifier], so swapping it in requires no screen changes.
///
/// Inference runs through an [IsolateInterpreter] so the UI thread never
/// blocks (NFR-2). Only this file may import `tflite_flutter` (PRD rule 2).
class TfliteClassifier implements DiseaseClassifier {
  Interpreter? _interpreter;
  IsolateInterpreter? _isolateInterpreter;

  /// Returns the isolate interpreter, available after [load()] is called.
  /// Returns null if the classifier has not been loaded yet.
  IsolateInterpreter? get isolateInterpreter => _isolateInterpreter;
  List<String> _labels = AppConfig.placeholderLabels;

  @override
  Future<void> load() async {
    if (_isolateInterpreter != null) return; // already loaded

    final interpreter = await Interpreter.fromAsset(
      AppConfig.modelAssetPath,
    );
    _interpreter = interpreter;

    // Run inference on a background isolate (NFR-2: UI never freezes).
    _isolateInterpreter = await IsolateInterpreter.create(
      address: interpreter.address,
    );

    _labels = await _loadLabels();
  }

  Future<List<String>> _loadLabels() async {
    try {
      final raw = await rootBundle.loadString(AppConfig.labelsAssetPath);
      final labels = raw
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (labels.isNotEmpty) return labels;
    } catch (_) {
      // Fall through to placeholder labels below.
    }
    return AppConfig.placeholderLabels;
  }

  @override
  Future<Prediction> classify(File image) async {
    final interpreter = _isolateInterpreter;
    if (interpreter == null) {
      throw StateError('TfliteClassifier.load() must be called before classify()');
    }

    final bytes = await image.readAsBytes();
    final preprocessed = preprocessImage(
      bytes,
      inputSize: AppConfig.inputSize,
    );

    // Input tensor: [1, 224, 224, 3] float32 (normalised to [-1, 1] by
    // preprocessing.dart); output: [1, 4] softmax probabilities.
    final output = List<List<double>>.filled(
      1,
      List<double>.filled(AppConfig.modelOutputClasses, 0),
    );

    await interpreter.run(preprocessed.tensor, output);

    final scores = output[0];
    var bestIndex = 0;
    var bestScore = scores[0];
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > bestScore) {
        bestScore = scores[i];
        bestIndex = i;
      }
    }

    // Guard against labels.txt/class-count drift: fall back to a
    // humanised index label instead of crashing.
    final label = bestIndex < _labels.length
        ? _labels[bestIndex]
        : 'class_$bestIndex';

    final scoreMap = <String, double>{
      for (var i = 0; i < scores.length; i++)
        i < _labels.length ? _labels[i] : 'class_$i': scores[i],
    };

    return Prediction(
      label: label,
      confidence: bestScore,
      scores: scoreMap,
      leafness: preprocessed.greenFraction,
    );
  }

  @override
  void dispose() {
    _isolateInterpreter?.close();
    _isolateInterpreter = null;
    _interpreter?.close();
    _interpreter = null;
  }
}
