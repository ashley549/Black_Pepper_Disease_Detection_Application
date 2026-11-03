import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:pepper_disease_app/features/gemini/gemini_advice_service.dart';

class _MockClient extends Mock implements http.Client {}

void main() {
  late _MockClient client;
  late GeminiAdviceService service;

  const adviceJson = {
    'summary': 'Leaf rot caused by a fungus.',
    'immediateSteps': '- Remove infected leaves\n- Improve drainage',
    'treatment': 'Spray Bordeaux mixture 1%.',
    'prevention': 'Avoid overhead watering.',
  };

  String envelope(String text) => jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': text}
              ]
            }
          }
        ]
      });

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  setUp(() {
    client = _MockClient();
    service = GeminiAdviceService(client: client, apiKey: 'test-key');
    when(() => client.post(any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'))).thenAnswer(
      (_) async => http.Response(envelope(jsonEncode(adviceJson)), 200),
    );
  });

  group('GeminiAdviceService.getAdvice', () {
    test('reports when the API key is not configured', () async {
      final unconfiguredService =
          GeminiAdviceService(client: client, apiKey: '');

      await expectLater(
        unconfiguredService.getAdvice(
          diseaseLabel: 'disease_a',
          diseaseName: 'Rot',
          confidence: 0.9,
        ),
        throwsA(isA<GeminiAdviceException>()),
      );

      verifyNever(() => client.post(any(),
          headers: any(named: 'headers'), body: any(named: 'body')));
    });

    test('parses a successful structured response', () async {
      final advice = await service.getAdvice(
        diseaseLabel: 'disease_a',
        diseaseName: 'Phytophthora Leaf Rot',
        confidence: 0.93,
      );

      expect(advice.summary, adviceJson['summary']);
      expect(advice.immediateSteps, adviceJson['immediateSteps']);
      expect(advice.treatment, adviceJson['treatment']);
      expect(advice.prevention, adviceJson['prevention']);
    });

    test('strips markdown fences around the JSON', () async {
      when(() => client.post(any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'))).thenAnswer(
        (_) async =>
            http.Response(envelope('```json\n${jsonEncode(adviceJson)}\n```'), 200),
      );

      final advice = await service.getAdvice(
        diseaseLabel: 'disease_a',
        diseaseName: 'Phytophthora Leaf Rot',
        confidence: 0.93,
      );

      expect(advice.summary, adviceJson['summary']);
    });

    test('throws a friendly error on rate limiting (429)', () async {
      when(() => client.post(any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'))).thenAnswer(
        (_) async => http.Response('{"error":{}}', 429),
      );

      await expectLater(
        service.getAdvice(
          diseaseLabel: 'disease_a',
          diseaseName: 'Rot',
          confidence: 0.9,
        ),
        throwsA(isA<GeminiAdviceException>()),
      );
    });

    test('throws a friendly error on bad request (400)', () async {
      when(() => client.post(any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'))).thenAnswer(
        (_) async => http.Response('{"error":{}}', 400),
      );

      await expectLater(
        service.getAdvice(
          diseaseLabel: 'disease_a',
          diseaseName: 'Rot',
          confidence: 0.9,
        ),
        throwsA(isA<GeminiAdviceException>()),
      );
    });

    test('throws on empty candidates (blocked prompt)', () async {
      when(() => client.post(any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'))).thenAnswer(
        (_) async => http.Response('{"promptFeedback":{}}', 200),
      );

      await expectLater(
        service.getAdvice(
          diseaseLabel: 'disease_a',
          diseaseName: 'Rot',
          confidence: 0.9,
        ),
        throwsA(isA<GeminiAdviceException>()),
      );
    });
  });
}
