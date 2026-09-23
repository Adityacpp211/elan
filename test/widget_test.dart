import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cardio_aid/main.dart';
import 'package:cardio_aid/screens.dart';

void main() {
  testWidgets('CardioAid splash screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const CardioAidApp());

    // Splash content
    expect(find.text('CardioAid'), findsOneWidget);
    expect(find.text('EMERGENCY CARDIAC CARE'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

    // Let the splash timer finish so the test ends cleanly
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('CardioAid navigates to login after splash', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CardioAidApp());

    // Advance past the splash timer (3s) and route transition
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // Not logged in -> login screen
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}