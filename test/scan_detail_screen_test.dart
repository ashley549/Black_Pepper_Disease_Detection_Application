import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pepper_disease_app/core/router.dart';
import 'package:pepper_disease_app/features/disease_info/disease_info_model.dart';
import 'package:pepper_disease_app/features/disease_info/disease_info_repository.dart';
import 'package:pepper_disease_app/features/history/history_repository.dart';
import 'package:pepper_disease_app/features/history/scan_detail_screen.dart';
import 'package:pepper_disease_app/features/history/scan_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockHistoryRepository extends Mock implements HistoryRepository {}

/// Stub so tests don't depend on the real disease_info.json asset: in a test
/// file that runs several widget tests, rootBundle's cached asset load can
/// leak between tests and leave the detail screen's FutureBuilder pending.
class _StubDiseaseInfoRepository implements DiseaseInfoRepository {
  @override
  Future<DiseaseInfo> getByLabel(String label) async {
    return DiseaseInfo(
      key: label,
      displayName: 'Leaf Blight (Phytophthora)',
      description: 'Test description.',
      symptoms: 'Test symptoms.',
      treatment: 'Test treatment.',
      prevention: 'Test prevention.',
    );
  }
}

void main() {
  final record = ScanRecord(
    id: 1,
    imagePath: '/nonexistent/leaf.jpg',
    label: 'Leaf_blight',
    confidence: 0.87,
    timestamp: DateTime(2026, 10, 1, 9, 5),
  );

  final overrides = <Override>[
    diseaseInfoRepositoryProvider
        .overrideWith((ref) => _StubDiseaseInfoRepository()),
  ];

  testWidgets(
      'Scan detail shows the photo placeholder, saved result and guidance',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(home: ScanDetailScreen(record: record)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scan Detail'), findsOneWidget);
    expect(find.text('Leaf Blight (Phytophthora)'), findsOneWidget);
    expect(find.text('87.0%'), findsOneWidget);
    expect(find.textContaining('Scanned on'), findsOneWidget);
    // imagePath does not exist in the test env -> graceful placeholder.
    expect(find.text('Original photo no longer available'), findsOneWidget);
    expect(find.text('Symptoms'), findsOneWidget);
    expect(find.text('Treatment'), findsOneWidget);
    expect(find.text('Prevention'), findsOneWidget);
  });

  testWidgets('Tapping a history entry opens its detail screen',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    final repo = _MockHistoryRepository();
    when(() => repo.listScans()).thenAnswer((_) async => [record]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          historyRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp.router(routerConfig: appRouter),
      ),
    );
    await tester.pumpAndSettle();

    appRouter.go('/history');
    await tester.pumpAndSettle();

    // The list entry renders with the humanised label. The filter chip row
    // also shows the label, so target the entry card itself (only list
    // entries are Dismissible).
    final cardTitle = find.descendant(
      of: find.byType(Dismissible),
      matching: find.text('Leaf blight'),
    );
    expect(cardTitle, findsOneWidget);

    await tester.tap(cardTitle);
    // Bounded pump loop instead of pumpAndSettle: straggler frames from the
    // page transition + ExpansionTile animations can keep pumpAndSettle
    // busy forever. Pump until the detail content appears.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Leaf Blight (Phytophthora)').evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.text('Scan Detail'), findsOneWidget);
    expect(find.text('Leaf Blight (Phytophthora)'), findsOneWidget);
  });
}
