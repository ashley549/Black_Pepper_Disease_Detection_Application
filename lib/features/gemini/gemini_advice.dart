/// Structured advice returned by Gemini for an identified disease.
class GeminiAdvice {
  final String summary;
  final String immediateSteps;
  final String treatment;
  final String prevention;

  /// Gemini's independent check of the photo itself: false means the image
  /// does not show a pepper leaf (object/screen/scenery), so the on-device
  /// label is probably wrong. Defaults to true when the model omits the key
  /// (older responses, missing field) so advice still renders.
  final bool isLeafPhoto;

  const GeminiAdvice({
    required this.summary,
    required this.immediateSteps,
    required this.treatment,
    required this.prevention,
    this.isLeafPhoto = true,
  });

  factory GeminiAdvice.fromJson(Map<String, dynamic> json) {
    final leaf = json['isLeafPhoto'];
    return GeminiAdvice(
      summary: (json['summary'] as String?) ?? '',
      immediateSteps: (json['immediateSteps'] as String?) ?? '',
      treatment: (json['treatment'] as String?) ?? '',
      prevention: (json['prevention'] as String?) ?? '',
      isLeafPhoto: leaf is bool ? leaf : true,
    );
  }
}
