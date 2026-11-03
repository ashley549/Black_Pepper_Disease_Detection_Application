import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pepper_disease_app/features/disease_info/disease_info_model.dart';

void main() {
  group('DiseaseInfo', () {
    test('fromJson maps all fields and tolerates missing ones', () {
      final info = DiseaseInfo.fromJson('disease_x', {
        'displayName': 'Test Disease',
        'symptoms': 'Spots',
      });

      expect(info.key, 'disease_x');
      expect(info.displayName, 'Test Disease');
      expect(info.description, isEmpty);
      expect(info.symptoms, 'Spots');
      expect(info.treatment, isEmpty);
      expect(info.prevention, isEmpty);
    });

    test('asset JSON is valid and covers all placeholder labels', () {
      final raw =
          File('assets/data/disease_info.json').readAsStringSync();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;

      for (final label in ['Healthy', 'Leaf_blight', 'Slow_decline', 'Yellow_mottle_virus']) {
        expect(decoded.containsKey(label), isTrue,
            reason: 'Missing disease info for "$label"');
        final entry = DiseaseInfo.fromJson(label, decoded[label] as Map<String, dynamic>);
        expect(entry.displayName, isNotEmpty);
        expect(entry.treatment, isNotEmpty);
      }
    });
  });
}
