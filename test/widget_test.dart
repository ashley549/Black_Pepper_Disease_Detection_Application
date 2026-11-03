import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pepper_disease_app/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App boots to the home screen', (tester) async {
    // Settings/localisation read shared_preferences on startup.
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: PepperApp()));
    await tester.pumpAndSettle();

    expect(find.text('Take Photo'), findsOneWidget);
    expect(find.text('Choose from Gallery'), findsOneWidget);
  });
}
