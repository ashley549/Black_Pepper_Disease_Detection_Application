import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pepper_disease_app/core/app_config.dart';
import 'package:pepper_disease_app/ml/mock_classifier.dart';

void main() {
  late MockClassifier classifier;

  setUp(() {
    classifier = MockClassifier();
  });

  group('MockClassifier', () {
    test('returns a prediction for a valid label', () async {
      final prediction = await classifier.classify(File('unused.jpg'));

      expect(AppConfig.placeholderLabels, contains(prediction.label));
      expect(prediction.confidence, inInclusiveRange(0.0, 1.0));
    });

    test('returns a full probability distribution', () async {
      final prediction = await classifier.classify(File('unused.jpg'));

      expect(prediction.scores.length, AppConfig.placeholderLabels.length);
      final sum = prediction.scores.values.fold<double>(0, (a, b) => a + b);
      expect(sum, closeTo(1.0, 0.01));
    });

    test('top3 has at most 3 entries sorted by confidence', () async {
      final prediction = await classifier.classify(File('unused.jpg'));

      expect(prediction.top3.length, lessThanOrEqualTo(3));
      final values = prediction.top3.map((e) => e.value).toList();
      expect(values, equals([...values]..sort((a, b) => b.compareTo(a))));
    });

    test('load completes without error and dispose is safe', () async {
      await expectLater(classifier.load(), completes);
      classifier.dispose();
    });
  });
}
