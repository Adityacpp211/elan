import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elan/main.dart';
import 'package:elan/screens.dart';

void main() {
  testWidgets('Élan splash screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ElanApp());

    // Splash content
    expect(find.text('Élan'), findsOneWidget);
    expect(find.text('EMERGENCY CARDIAC CARE'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

    // Let the splash timer finish so the test ends cleanly
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('Élan navigates to login after splash', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ElanApp());

    // Advance past the splash timer (3s) and route transition
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // Not logged in -> login screen
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}