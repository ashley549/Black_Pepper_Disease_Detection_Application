import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Image preprocessing for the real TFLite model (PRD Phase 9).
///
/// The model's input tensor is [1, 224, 224, 3] float32 (confirmed by
/// inspecting assets/models/mobilenetv1_v2_float32.tflite). Training used
/// `mobilenet.preprocess_input`, i.e. (pixel - 127.5) / 127.5, so pixels are
/// mapped to [-1, 1] here. MUST match training exactly (PRD Phase 9 parity
/// test) — change only together with the training pipeline.
class PreprocessedImage {
  /// Flat RGB buffer: 1 * H * W * 3 floats, row-major, channel-last.
  /// Shaped as [1][H][W][3] nested lists ready for interpreter.run().
  final List<List<List<List<double>>>> tensor;

  /// Fraction (0.0 - 1.0) of pixels that look like vegetation, computed with
  /// the excess-green index ExG = 2G - R - B (Woebbecke et al.). Used by the
  /// scan flow to reject photos of objects/scenery instead of letting the
  /// closed-set classifier force a disease label onto them.
  final double greenFraction;

  const PreprocessedImage(this.tensor, this.greenFraction);
}

/// Decodes [bytes] and produces the normalised input tensor the model
/// expects. Throws [FormatException] for corrupted/unsupported images
/// (the caller maps this to the scan error state).
PreprocessedImage preprocessImage(
  Uint8List bytes, {
  required int inputSize,
  double leafPixelExGThreshold = 40.0,
}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Unsupported or corrupted image data');
  }

  // EXIF orientation is a tag telling how to rotate the raw pixels for
  // display; browsers/phones honour it, raw pixel buffers do not. Training
  // fed the pipeline upright pixels, so bake the rotation in (bakeOrientation
  // is a no-op when the tag is absent).
  final oriented = img.bakeOrientation(decoded);

  final resized = img.copyResize(
    oriented,
    width: inputSize,
    height: inputSize,
    interpolation: img.Interpolation.linear,
  );

  // Build [1][H][W][3] with channels in R, G, B order, normalised to
  // [-1, 1] exactly like tf.keras mobilenet.preprocess_input:
  // (pixel - 127.5) / 127.5.
  // Growable inner lists keep the analyzer happy about the null-filled
  // outer shells.
  final batch = <List<List<List<double>>>>[];
  final height = <List<List<double>>>[];
  var leafishPixels = 0;
  for (var y = 0; y < inputSize; y++) {
    final row = <List<double>>[];
    for (var x = 0; x < inputSize; x++) {
      final pixel = resized.getPixel(x, y);
      // Excess-green vegetation index on the 0-255 pixel: strong for leaves
      // (green or yellowing), ~0 or negative for browns, beiges, whites,
      // i.e. furniture, floors, walls, posters.
      final exg = 2 * pixel.g - pixel.r - pixel.b;
      if (exg > leafPixelExGThreshold) leafishPixels++;
      row.add(<double>[
        (pixel.r - 127.5) / 127.5,
        (pixel.g - 127.5) / 127.5,
        (pixel.b - 127.5) / 127.5,
      ]);
    }
    height.add(row);
  }
  batch.add(height);

  return PreprocessedImage(
    batch,
    leafishPixels / (inputSize * inputSize),
  );
}
