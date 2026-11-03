import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pepper_disease_app/features/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Home screen shows photo tips and capture buttons',
      (tester) async {
    // LanguageNotifier reads shared_preferences on startup.
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: HomeScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Take Photo'), findsOneWidget);
    expect(find.text('Choose from Gallery'), findsOneWidget);
    expect(find.text('Photo tips'), findsOneWidget);
    expect(find.text('Photograph a single leaf'), findsOneWidget);
  });
}
