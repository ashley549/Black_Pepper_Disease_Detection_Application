import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gemini_advice.dart';
import 'gemini_advice_service.dart';

/// Async state for the Gemini advice shown on the result screen.
class GeminiAdviceState {
  final bool loading;
  final GeminiAdvice? advice;
  final String? error;

  const GeminiAdviceState({this.loading = false, this.advice, this.error});

  GeminiAdviceState copyWith({
    bool? loading,
    GeminiAdvice? advice,
    String? error,
  }) {
    return GeminiAdviceState(
      loading: loading ?? false,
      advice: advice ?? this.advice,
      error: error,
    );
  }
}

class GeminiAdviceController extends StateNotifier<GeminiAdviceState> {
  GeminiAdviceController(this._service) : super(const GeminiAdviceState());

  final GeminiAdviceService _service;

  Future<void> loadAdvice({
    required String diseaseLabel,
    required String diseaseName,
    required double confidence,
    File? leafImage,
  }) async {
    state = const GeminiAdviceState(loading: true);
    try {
      final advice = await _service.getAdvice(
        diseaseLabel: diseaseLabel,
        diseaseName: diseaseName,
        confidence: confidence,
        leafImage: leafImage,
      );
      state = GeminiAdviceState(advice: advice);
    } on GeminiAdviceException catch (e) {
      state = GeminiAdviceState(error: e.message);
    } catch (_) {
      state = const GeminiAdviceState(
        error: 'Something went wrong while fetching AI advice.',
      );
    }
  }

  void reset() => state = const GeminiAdviceState();
}

final geminiAdviceControllerProvider =
    StateNotifierProvider<GeminiAdviceController, GeminiAdviceState>((ref) {
  return GeminiAdviceController(ref.watch(geminiAdviceServiceProvider));
});
