import 'dart:math' as math;

import 'package:tflite_flutter/tflite_flutter.dart';

import '../core/app_config.dart';
import 'tflite_classifier.dart';

/// Result of an occlusion sensitivity analysis.
class DiseaseExplanation {
  /// The predicted class label from the original prediction.
  final String predictedLabel;

  /// The predicted class confidence from the original prediction.
  final double predictedConfidence;

  /// Heatmap influence values per grid cell, arranged as a 7x7 grid.
  /// Values are in [0, 1] where 0 = low influence, 1 = high influence.
  final List<List<double>> influenceMap;

  /// Original model output score (before softmax) for the predicted class,
  /// used as the baseline for impact calculation.
  final double originalScore;

  /// Creates a [DiseaseExplanation] with the given properties.
  const DiseaseExplanation({
    required this.predictedLabel,
    required this.predictedConfidence,
    required this.influenceMap,
    required this.originalScore,
  });

  /// Human-readable interpretation of the predicted label.
  String get displayLabel {
    final spaced = predictedLabel.replaceAll('_', ' ').trim();
    if (spaced.isEmpty) return predictedLabel;
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}

/// Configuration for the occlusion grid.
class OcclusionGridConfig {
  /// Number of grid cells per dimension (7x7 = 49 regions by default).
  final int gridSize;

  /// Size of the occlusion window in pixels. Covers ~56x56 pixels per region.
  final int windowSize;

  /// Stride (step) between successive occlusion positions in pixels.
  final int stride;

  /// The masking value in normalized [-1, 1] space.
  /// For MobileNetV1 with (pixel - 127.5) / 127.5 normalization:
  /// - RGB 127.5 → 0.0 normalized
  /// - RGB 0   → -1.0 normalized
  /// - RGB 255 →  1.0 normalized
  /// A neutral mask (background-like) is near 0.0.
  final double maskValue;

  /// Creates a [OcclusionGridConfig] with the given parameters.
  const OcclusionGridConfig({
    this.gridSize = 7,
    this.windowSize = 56,
    this.stride = 28,
    this.maskValue = 0.0,
  });
}

/// Performs occlusion sensitivity analysis on a preprocessed image tensor.
///
/// Runs the complete occlusion inference sequence inside the classifier's
/// existing [IsolateInterpreter] so the Flutter UI thread never blocks (NFR-2).
/// The result is a 7x7 influence map showing which image regions most
/// affected the predicted class score.
///
/// The returned [DiseaseExplanation] is safe to use in the UI thread.
/// The [classifier] must be a loaded [TfliteClassifier] instance.
/// The tensor must be [1][224][224][3] as produced by [preprocessing.preprocessImage].
Future<DiseaseExplanation> computeOcclusionExplanation({
  /// The preprocessed image tensor, shape [1][224][224][3], as produced
  /// by [preprocessing.preprocessImage]. This is the same tensor that would
  /// be passed to [TfliteClassifier.classify].
  required List<List<List<double>>> tensor,

  /// The index of the predicted class from the original classification.
  required int predictedClassIndex,

  /// List of class labels in order matching the model output classes.
  /// e.g. ['Healthy', 'Leaf_blight', 'Slow_decline', 'Yellow_mottle_virus']
  required List<String> classLabels,

  /// The original prediction confidence for the predicted class index.
  /// Passed in from the caller rather than accessed internally, to keep
  /// the explanation service decoupled.
  required double originalConfidence,

  /// Optional configuration controlling the grid size, window, and stride.
  /// Defaults to 7x7 grid with 56px window and 28px stride.
  OcclusionGridConfig? config,

  /// The [TfliteClassifier] instance that provides the isolate interpreter.
  /// The occlusion sequence runs in the same isolate to avoid loading the
  /// model twice and to respect NFR-2 (UI never freezes).
  required TfliteClassifier classifier,
}) async {
  final effectiveConfig = config ?? const OcclusionGridConfig();

  // Run the occlusion sequence in the classifier's existing isolate.
  // This avoids loading the model twice and ensures the UI thread never blocks.
  final result = await _runOcclusionInClassifierIsolate(
    tensor: tensor,
    predictedClassIndex: predictedClassIndex,
    gridSize: effectiveConfig.gridSize,
    windowSize: effectiveConfig.windowSize,
    stride: effectiveConfig.stride,
    maskValue: effectiveConfig.maskValue,
    classifier: classifier,
  );

  // Build the explanation using the provided labels and confidence
  final predictedLabel = classLabels[predictedClassIndex];

  return DiseaseExplanation(
    predictedLabel: predictedLabel,
    predictedConfidence: originalConfidence,
    influenceMap: result.influenceMap,
    originalScore: result.originalScore,
  );
}

/// Internal: runs occlusion inside the classifier's isolate.
Future<_OcclusionResult> _runOcclusionInClassifierIsolate({
  /// The preprocessed tensor [1][224][224][3] as produced by preprocessing.
  required List<List<List<double>>> tensor,
  required int predictedClassIndex,
  required int gridSize,
  required int windowSize,
  required int stride,
  required double maskValue,
  required TfliteClassifier classifier,
}) async {
  // Use the classifier's existing isolate interpreter.
  // NFR-2: UI never freezes - we reuse the background isolate.
  // isolateInterpreter is guaranteed non-null since classifier.load() must be called first.
  final interpreter = classifier.isolateInterpreter;

  // The tensor shape is [1][H][W][3] = [1][224][224][3].
  // Access pattern: tensor[0][y][x][c] where c=0→R, 1→G, 2→B

  // --- Step 1: Run original inference and capture the baseline score ---
  // Prepare output buffer matching the model's 4 output classes
  final List<double> originalOutput = List<double>.filled(AppConfig.modelOutputClasses, 0);
  // The interpreter is guaranteed non-null since classifier.load() must be called first.
  // ignore: avoid_initializing_formals
  if (interpreter == null) {
    throw StateError('Classifier isolate not loaded. Call classifier.load() first.');
  }
  interpreter.run(tensor, originalOutput);

  // After run(), originalOutput contains the 4 class scores.
  // Get the score for the predicted class.
  // Cast to double explicitly
  final double originalScore =
      originalOutput[predictedClassIndex].toDouble();

  // --- Step 2: Grid traversal and occlusion ---
  final height = AppConfig.inputSize; // 224
  final width = AppConfig.inputSize; // 224

  // Influence map indexed by grid position [gy][gx], values will be
  // impact scores later normalized to [0, 1].
  final influenceMap = List.generate(gridSize, (gy) => List.filled(gridSize, 0.0));

  // Calculate positions: with stride S and window W on size 224,
  // positions are at 0, S, 2S, ... while window stays inside.
  // Number of positions: floor((224 - W) / S) + 1
  final numPositionsY = (height - windowSize) ~/ stride + 1;
  final numPositionsX = (width - windowSize) ~/ stride + 1;

  // --- Step 3: For each grid position, occlude and infer ---
  for (var gy = 0; gy < numPositionsY; gy++) {
    for (var gx = 0; gx < numPositionsX; gx++) {
      // Top-left pixel of this occlusion window
      final yStart = gy * stride;
      final xStart = gx * stride;

      // Clamp so window stays inside image bounds
      final yClamped = math.min(yStart, height - windowSize);
      final xClamped = math.min(xStart, width - windowSize);

      // Create a copy of the tensor with the window region masked
      final maskedTensor = _copyTensorWithMask(
        tensor: tensor,
        y: yClamped,
        x: xClamped,
        windowSize: windowSize,
        maskValue: maskValue,
      );

      // Run inference on the masked tensor
      // Prepare output buffer
      final List<double> maskedOutput = List<double>.filled(AppConfig.modelOutputClasses, 0);
      // ignore: non_constant_identifier_patterns
      // The interpreter is non-null per the precondition above.
      interpreter.run(maskedTensor, maskedOutput);

      // Get the score for the original predicted class after masking
      // Cast to double explicitly
      final double occludedScore =
          maskedOutput[predictedClassIndex].toDouble();

      // Calculate positive influence: removing this region reduced the score
      // impact = max(0, originalScore - occludedScore)
      final impact = math.max(0.0, originalScore - occludedScore);

      influenceMap[gy][gx] = impact;
    }
  }

  // --- Step 4: Normalize the influence map to [0, 1] ---
  final normalizedMap = _normalizeInfluenceMap(influenceMap);

  return _OcclusionResult(
    influenceMap: normalizedMap,
    originalScore: originalScore,
  );
}

/// Internal result from the occlusion isolate run.
class _OcclusionResult {
  final List<List<double>> influenceMap;
  final double originalScore;

  _OcclusionResult({
    required this.influenceMap,
    required this.originalScore,
  });
}

/// Creates a copy of the image tensor with a rectangular region masked.
/// The mask replaces pixels in the window region with [maskValue] (in normalized space).
/// The tensor format is [1][H][W][3] as produced by preprocessing.
/// Access pattern: tensor[0][y][x][c] where c=0→R, 1→G, 2→B
List<List<List<double>>> _copyTensorWithMask({
  required List<List<List<double>>> tensor,
  required int y,
  required int x,
  required int windowSize,
  required double maskValue,
}) {
  // Deep copy the tensor [1][H][W][3]
  // tensor structure: batch[0][y][x][c] where c=0→R, 1→G, 2→B
  // tensor is [1][H][W][3], so tensor[0] removes batch dimension → [H][W][3]
  final batch = tensor[0];

  final height = batch.length; // 224
  final width = batch[0].length; // 224
  final channels = 3; // RGB channels, known from model architecture

  // Create new tensor structure with copied inner lists
  // Result will be [1][H][W][3] format
  final resultList = List.generate(1, (i) => List.generate(height, (row) => List.filled(width, 0.0)));

  // Apply the mask - replace a window region with maskValue
  final endY = math.min(y + windowSize, height);
  final endX = math.min(x + windowSize, width);

  for (int iy = y; iy < endY; iy++) {
    for (int ix = x; ix < endX; ix++) {
      for (int c = 0; c < channels; c++) {
        resultList[0][iy][ix] = maskValue;
      }
    }
  }

  return resultList;
}

/// Normalizes a grid-based influence map to the [0, 1] range.
/// Values below the min are clamped to 0, values above the max are clamped to 1.
List<List<double>> _normalizeInfluenceMap(List<List<double>> map) {
  // Find min and max across the entire grid
  double minVal = double.infinity;
  double maxVal = double.negativeInfinity;

  for (final row in map) {
    for (final val in row) {
      if (val < minVal) minVal = val;
      if (val > maxVal) maxVal = val;
    }
  }

  // Avoid division by zero - if all values are the same, return zeros
  final range = maxVal - minVal;
  if (range == 0) {
    return List.generate(map.length, (_) => List.filled(map[0].length, 0.0));
  }

  // Normalize each cell to [0, 1]
  final normalized = List.generate(map.length, (rowIdx) => List.filled(map[rowIdx].length, 0.0));
  for (int i = 0; i < map.length; i++) {
    for (int j = 0; j < map[i].length; j++) {
      normalized[i][j] = (map[i][j] - minVal) / range;
    }
  }
  return normalized;
}