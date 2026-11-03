/// Static disease guidance shown on the result screen (PRD Section 8).
class DiseaseInfo {
  final String key; // matches classifier label
  final String displayName;
  final String description;
  final String symptoms;
  final String treatment;
  final String prevention;

  const DiseaseInfo({
    required this.key,
    required this.displayName,
    required this.description,
    required this.symptoms,
    required this.treatment,
    required this.prevention,
  });

  factory DiseaseInfo.fromJson(String key, Map<String, dynamic> json) {
    return DiseaseInfo(
      key: key,
      displayName: (json['displayName'] as String?) ?? key,
      description: (json['description'] as String?) ?? '',
      symptoms: (json['symptoms'] as String?) ?? '',
      treatment: (json['treatment'] as String?) ?? '',
      prevention: (json['prevention'] as String?) ?? '',
    );
  }
}
