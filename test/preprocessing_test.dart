import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pepper_disease_app/ml/preprocessing.dart';

/// Builds a PNG in memory: solid colour [a], or left half [a] / right half [b].
Uint8List _png({required List<int> a, List<int>? b}) {
  final image = img.Image(width: 320, height: 320);
  if (b == null) {
    img.fill(image, color: img.ColorRgb8(a[0], a[1], a[2]));
  } else {
    img.fillRect(image,
        x1: 0, y1: 0, x2: 159, y2: 319, color: img.ColorRgb8(a[0], a[1], a[2]));
    img.fillRect(image,
        x1: 160, y1: 0, x2: 319, y2: 319,
        color: img.ColorRgb8(b[0], b[1], b[2]));
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('vegetation gate (greenFraction)', () {
    test('a healthy green leaf-like image counts as fully leaf', () {
      // ExG = 2*180 - 100 - 60 = 200 > 40 -> every pixel is vegetation.
      final p = preprocessImage(_png(a: [100, 180, 60]), inputSize: 224);
      expect(p.greenFraction, greaterThan(0.95));
    });

    test('a yellowing/diseased leaf still counts as leaf', () {
      // Yellow: ExG = 2*190 - 200 - 90 = 90 > 40. Important: yellow mottle
      // symptoms must NOT be rejected by the gate.
      final p = preprocessImage(_png(a: [200, 190, 90]), inputSize: 224);
      expect(p.greenFraction, greaterThan(0.95));
    });

    test('brown furniture-like colours are not vegetation', () {
      // Brown: ExG = 2*110 - 150 - 80 = -10.
      final p = preprocessImage(_png(a: [150, 110, 80]), inputSize: 224);
      expect(p.greenFraction, lessThan(0.05));
    });

    test('beige floor / white wall colours are not vegetation', () {
      final beige = preprocessImage(_png(a: [210, 200, 180]), inputSize: 224);
      final white = preprocessImage(_png(a: [235, 235, 230]), inputSize: 224);
      expect(beige.greenFraction, lessThan(0.05));
      expect(white.greenFraction, lessThan(0.05));
    });

    test('a half-leaf half-scenery frame lands near the middle', () {
      final p = preprocessImage(
        _png(a: [100, 180, 60], b: [150, 110, 80]),
        inputSize: 224,
      );
      expect(p.greenFraction, inInclusiveRange(0.40, 0.60));
    });

    test('tensor shape is still [1][224][224][3] with the gate added', () {
      final p = preprocessImage(_png(a: [100, 180, 60]), inputSize: 224);
      expect(p.tensor.length, 1);
      expect(p.tensor[0].length, 224);
      expect(p.tensor[0][0].length, 224);
      expect(p.tensor[0][0][0].length, 3);
    });
  });
}
