import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pepper_disease_app/features/gemini/gemini_advice.dart';
import 'package:pepper_disease_app/features/gemini/gemini_advice_controller.dart';
import 'package:pepper_disease_app/features/gemini/gemini_advice_service.dart';
import 'package:pepper_disease_app/features/scan/scan_controller.dart';
import 'package:pepper_disease_app/ml/classifier_provider.dart';
import 'package:pepper_disease_app/ml/disease_classifier.dart';

/// Always returns a high-confidence Leaf_blight for any image.
class _FakeClassifier implements DiseaseClassifier {
  _FakeClassifier(this.leafness);
  final double? leafness;

  @override
  Future<void> load() async {}

  @override
  Future<Prediction> classify(File image) async => Prediction(
        label: 'Leaf_blight',
        confidence: 0.95,
        scores: const {'Leaf_blight': 0.95, 'Healthy': 0.05},
        leafness: leafness,
      );

  @override
  void dispose() {}
}

/// Scripted Gemini controller: returns a fixed verdict instead of network.
class _ScriptedGemini extends GeminiAdviceController {
  _ScriptedGemini._(super.service);

  /// null simulates an offline failure (error state, no advice).
  factory _ScriptedGemini.verdict(bool? isLeafPhoto) {
    final c = _ScriptedGemini._(GeminiAdviceService());
    c._isLeafPhoto = isLeafPhoto;
    return c;
  }

  bool? _isLeafPhoto;

  @override
  Future<void> loadAdvice({
    required String diseaseLabel,
    required String diseaseName,
    required double confidence,
    File? leafImage,
  }) async {
    if (_isLeafPhoto == null) {
      state = const GeminiAdviceState(error: 'offline');
      return;
    }
    state = GeminiAdviceState(
      advice: GeminiAdvice(
        summary: 's',
        immediateSteps: 'i',
        treatment: 't',
        prevention: 'p',
        isLeafPhoto: _isLeafPhoto!,
      ),
    );
  }
}

Future<File> _leafImage() async {
  final png = img.Image(width: 8, height: 8);
  img.fill(png, color: img.ColorRgb8(100, 180, 60));
  return File('${Directory.systemTemp.path}/scan_flow_leaf.png')
    ..writeAsBytesSync(Uint8List.fromList(img.encodePng(png)));
}

ProviderContainer _container({
  required double? leafness,
  required bool? geminiVerdict,
}) {
  return ProviderContainer(
    overrides: [
      classifierProvider.overrideWithValue(_FakeClassifier(leafness)),
      geminiAdviceControllerProvider
          .overrideWith((ref) => _ScriptedGemini.verdict(geminiVerdict)),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Gemini rejecting the photo yields notLeaf without a success state',
      () async {
    final container = _container(leafness: 0.5, geminiVerdict: false);
    addTearDown(container.dispose);

    final controller = container.read(scanControllerProvider.notifier);
    await controller.startScan(await _leafImage());

    final state = container.read(scanControllerProvider);
    expect(state.status, ScanStatus.notLeaf);
    expect(state.diseaseInfo, isNull); // never entered the success state
  });

  test('Gemini agreeing the photo is a leaf shows the normal success result',
      () async {
    final container = _container(leafness: 0.5, geminiVerdict: true);
    addTearDown(container.dispose);

    final controller = container.read(scanControllerProvider.notifier);
    await controller.startScan(await _leafImage());

    expect(container.read(scanControllerProvider).status, ScanStatus.success);
  });

  test('Offline Gemini (error state) degrades gracefully to success',
      () async {
    final container = _container(leafness: 0.5, geminiVerdict: null);
    addTearDown(container.dispose);

    final controller = container.read(scanControllerProvider.notifier);
    await controller.startScan(await _leafImage());

    expect(container.read(scanControllerProvider).status, ScanStatus.success);
  });

  test('Offline pixel gate still rejects scenery before any label', () async {
    final container = _container(leafness: 0.0, geminiVerdict: true);
    addTearDown(container.dispose);

    final controller = container.read(scanControllerProvider.notifier);
    await controller.startScan(await _leafImage());

    expect(container.read(scanControllerProvider).status, ScanStatus.notLeaf);
  });
}
