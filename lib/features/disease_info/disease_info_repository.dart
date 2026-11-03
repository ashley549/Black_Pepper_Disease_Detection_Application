import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_config.dart';
import 'disease_info_model.dart';

/// Reads assets/data/disease_info.json and serves entries by label
/// (PRD Phase 5). Unknown labels get a safe fallback instead of a crash.
class DiseaseInfoRepository {
  Map<String, DiseaseInfo>? _cache;

  Future<Map<String, DiseaseInfo>> _load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString(AppConfig.diseaseInfoAssetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    _cache = decoded.map(
      (key, value) => MapEntry(key, DiseaseInfo.fromJson(key, value as Map<String, dynamic>)),
    );
    return _cache!;
  }

  /// Returns the entry for [label], or a graceful fallback (FR: unknown label
  /// must not crash).
  Future<DiseaseInfo> getByLabel(String label) async {
    final all = await _load();
    return all[label] ??
        DiseaseInfo(
          key: label,
          displayName: _humanize(label),
          description: 'Detailed information for this condition is not '
              'available yet. Please consult a local agriculture officer.',
          symptoms: 'Not available.',
          treatment: 'Not available.',
          prevention: 'Not available.',
        );
  }

  /// "disease_a" -> "Disease A"; "healthy" -> "Healthy".
  static String _humanize(String label) {
    if (label.isEmpty) return label;
    final spaced = label.replaceAll('_', ' ').trim();
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}

final diseaseInfoRepositoryProvider =
    Provider<DiseaseInfoRepository>((ref) => DiseaseInfoRepository());
