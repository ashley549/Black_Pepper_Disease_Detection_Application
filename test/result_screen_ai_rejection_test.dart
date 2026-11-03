import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pepper_disease_app/features/disease_info/disease_info_model.dart';
import 'package:pepper_disease_app/features/gemini/gemini_advice.dart';
import 'package:pepper_disease_app/features/gemini/gemini_advice_controller.dart';
import 'package:pepper_disease_app/features/gemini/gemini_advice_service.dart';
import 'package:pepper_disease_app/features/result/result_screen.dart';
import 'package:pepper_disease_app/features/scan/scan_controller.dart';
import 'package:pepper_disease_app/ml/disease_classifier.dart';

/// Seeds the scan controller with a fixed state instead of running a scan.
class _FakeScanController extends ScanController {
  _FakeScanController(super.ref, ScanState initial) {
    state = initial;
  }
}

/// Seeds the Gemini advice controller with a fixed response.
class _FakeGeminiController extends GeminiAdviceController {
  _FakeGeminiController(super.service, GeminiAdviceState initial) {
    state = initial;
  }
}

ScanState _successScan(File image) => ScanState(
      status: ScanStatus.success,
      image: image,
      prediction: const Prediction(
        label: 'Slow_decline',
        confidence: 1.0,
        scores: {'Slow_decline': 1.0},
      ),
      diseaseInfo: DiseaseInfo(
        key: 'Slow_decline',
        displayName: 'Slow Decline (Nematode)',
        description: 'd',
        symptoms: 's',
        treatment: 't',
        prevention: 'p',
      ),
    );

void main() {
  // The success view renders Image.file, so give it a real (tiny) PNG.
  late final File leafImage;
  setUpAll(() {
    final png = img.Image(width: 8, height: 8);
    img.fill(png, color: img.ColorRgb8(100, 180, 60));
    leafImage = File(
      '${Directory.systemTemp.path}/result_test_leaf.png',
    ) ..writeAsBytesSync(Uint8List.fromList(img.encodePng(png)));
  });

  testWidgets(
      'Gemini saying the photo is not a leaf hides the disease result entirely',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scanControllerProvider.overrideWith(
            (ref) => _FakeScanController(ref, _successScan(leafImage)),
          ),
          geminiAdviceControllerProvider.overrideWith(
            (ref) => _FakeGeminiController(
              GeminiAdviceService(),
              GeminiAdviceState(
                advice: GeminiAdvice(
                  summary: 'should not show',
                  immediateSteps: '',
                  treatment: '',
                  prevention: '',
                  isLeafPhoto: false,
                ),
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: ResultScreen()),
      ),
    );

    // The rejection view replaces the confident (wrong) disease result.
    expect(find.text("This doesn't look like a pepper leaf"), findsOneWidget);
    expect(find.textContaining('could not find a pepper leaf'),
        findsOneWidget);
    // Disease prediction should NOT show since Gemini rejected it as not a leaf
    expect(find.text('Top predictions'), findsNothing);
    expect(find.text('Slow Decline (Nematode)'), findsNothing);
    expect(find.text('What it is'), findsNothing);
  });

  testWidgets(
      'Gemini agreeing the photo IS a leaf keeps the normal result view',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scanControllerProvider.overrideWith(
            (ref) => _FakeScanController(ref, _successScan(leafImage)),
          ),
          geminiAdviceControllerProvider.overrideWith(
            (ref) => _FakeGeminiController(
              GeminiAdviceService(),
              GeminiAdviceState(
                advice: GeminiAdvice(
                  summary: 'Real advice.',
                  immediateSteps: '',
                  treatment: '',
                  prevention: '',
                  isLeafPhoto: true,
                ),
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: ResultScreen()),
      ),
    );

    // Disease prediction SHOULD show since Gemini said it IS a leaf
    expect(find.text('Slow Decline (Nematode)'), findsOneWidget);
    expect(find.text('Top predictions'), findsOneWidget);
    // Gemini advice card is now hidden - no "What it is", "What to do now", etc.
    expect(find.text('What it is'), findsNothing);
    expect(find.text('What to do now'), findsNothing);
    expect(find.text('Treatment'), findsNothing);
    expect(find.text('Prevention'), findsNothing);
  });
}