import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/app_config.dart';
import 'gemini_advice.dart';

/// Exception thrown when Gemini advice cannot be fetched.
class GeminiAdviceException implements Exception {
  final String message;
  GeminiAdviceException(this.message);

  @override
  String toString() => message;
}

/// Calls the Gemini REST API (generativelanguage.googleapis.com) with the
/// identified disease and the leaf photo, and returns structured treatment
/// advice. Uses plain HTTP because the google_generative_ai Dart SDK is
/// deprecated; the REST surface is the most stable integration.
class GeminiAdviceService {
  GeminiAdviceService({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _apiKey = apiKey ?? AppConfig.geminiApiKey;

  final http.Client _client;
  final String _apiKey;

  /// Prompt sent to Gemini. Asks for strict JSON so parsing is reliable.
  /// Also acts as layer-2 defence against non-leaf photos: the on-device
  /// classifier is a closed 4-class model and labels ANY image, so Gemini
  /// independently checks the photo actually shows a pepper leaf.
  static const String _systemInstruction =
      'You are an agricultural extension expert for black pepper (Piper '
      'nigrum) farmers. Answer in simple, jargon-free language a farmer can '
      'act on. Prefer locally available, low-cost remedies. First inspect '
      'the attached photo: if it does not actually show a plant leaf '
      '(for example an object, furniture, room, poster, screen or other '
      'scenery), set isLeafPhoto to false and leave the other values as '
      'empty strings. Always answer with ONLY a JSON object, no markdown '
      'fences, with keys: isLeafPhoto (boolean), summary, immediateSteps, '
      'treatment, prevention. Each text value must be a short plain-text '
      'paragraph; use "- " bullets inside a value.';

  /// [diseaseLabel] is the raw classifier label (e.g. "disease_a"),
  /// [diseaseName] the human-readable name shown to the user.
  Future<GeminiAdvice> getAdvice({
    required String diseaseLabel,
    required String diseaseName,
    required double confidence,
    File? leafImage,
  }) async {
    if (_apiKey.isEmpty) {
      throw GeminiAdviceException(
        'Gemini API key is not configured. '
        'Run with --dart-define-from-file=.env.json to enable AI advice.',
      );
    }

    final prompt = '''
The on-device model classified a black pepper leaf image.
Disease label: "$diseaseLabel"
Disease name: "$diseaseName"
Model confidence: ${(confidence * 100).toStringAsFixed(1)}%
${leafImage != null ? 'The leaf photo is attached for context.' : ''}

Provide the possible solution for this disease for a smallholder farmer.
Respond ONLY with the JSON object described.''';

    final body = <String, dynamic>{
      'systemInstruction': {
        'parts': [
          {'text': _systemInstruction}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
            if (leafImage != null)
              {
                'inline_data': {
                  // image_picker files are jpg on Android/iOS by default.
                  'mime_type': 'image/jpeg',
                  'data': base64Encode(await leafImage.readAsBytes()),
                },
              },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.4,
        'maxOutputTokens': 1024,
        'responseMimeType': 'application/json',
      },
    };

    final uri = Uri.parse('${AppConfig.geminiApiEndpoint}?key=$_apiKey');
    final response = await _postJson(uri, jsonEncode(body));

    if (response.statusCode == 404) {
      // Typically means the pinned model name was retired for new keys.
      throw GeminiAdviceException(
          'The AI model is no longer available (HTTP 404). '
          'Update geminiModel in AppConfig to a current model name.');
    }
    if (response.statusCode == 400 || response.statusCode == 403) {
      throw GeminiAdviceException(
          'Gemini rejected the request (HTTP ${response.statusCode}). '
          'Check the GEMINI_API_KEY configuration.');
    }
    if (response.statusCode == 429) {
      throw GeminiAdviceException(
          'Gemini free-tier limit reached. Please try again in a minute.');
    }
    if (response.statusCode != 200) {
      throw GeminiAdviceException(
          'Gemini error (HTTP ${response.statusCode}).');
    }

    return _parseResponse(response.body);
  }

  /// POST with network errors mapped to farmer-friendly messages.
  Future<http.Response> _postJson(Uri uri, String body) async {
    try {
      return await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 45));
    } on SocketException {
      throw GeminiAdviceException(
          'No internet connection. The AI advice needs to be online.');
    } on TimeoutException {
      throw GeminiAdviceException(
          'The AI advice took too long to respond. Please retry.');
    } on HttpException {
      throw GeminiAdviceException('Could not reach the AI advice service.');
    } on Exception {
      throw GeminiAdviceException('AI advice request failed. Please retry.');
    }
  }

  /// Parses the generateContent envelope and then the model's JSON payload.
  GeminiAdvice _parseResponse(String responseBody) {
    try {
      final outer = jsonDecode(responseBody) as Map<String, dynamic>;
      final candidates = outer['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        // Request may have been blocked by safety filters.
        if (outer.containsKey('promptFeedback')) {
          throw GeminiAdviceException(
              'The AI could not answer this request. Try another photo.');
        }
        throw GeminiAdviceException('The AI returned an empty response.');
      }

      final content = (candidates.first as Map<String, dynamic>)['content']
          as Map<String, dynamic>;
      final parts = content['parts'] as List<dynamic>;
      final text = parts
          .map((p) => ((p as Map<String, dynamic>)['text'] ?? '') as String)
          .join();

      // Strip accidental markdown fences.
      var payload = text.trim();
      if (payload.startsWith('```')) {
        payload = payload
            .replaceFirst(RegExp(r'^```(json)?'), '')
            .replaceFirst(RegExp(r'```$'), '')
            .trim();
      }

      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      return GeminiAdvice.fromJson(decoded);
    } on GeminiAdviceException {
      rethrow;
    } catch (_) {
      throw GeminiAdviceException(
          'Could not understand the AI response. Please retry.');
    }
  }

  void dispose() => _client.close();
}

final geminiAdviceServiceProvider =
    Provider<GeminiAdviceService>((ref) => GeminiAdviceService());
