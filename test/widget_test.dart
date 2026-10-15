import 'package:flutter_test/flutter_test.dart';

import 'package:elan/main.dart';
import 'package:elan/screens.dart';
import 'package:elan/theme.dart';

void main() {
  testWidgets('Élan splash screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ElanApp());

    // Splash content: the logo mark, wordmark and tagline
    expect(find.byType(BrandMark), findsOneWidget);
    expect(find.text('Élan'), findsOneWidget);
    expect(find.text('Emergency cardiac care'), findsOneWidget);

    // On the first frame the mark sits at the screen centre, exactly where
    // the native launch screen draws it, so the hand-off doesn't jump.
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(tester.getCenter(find.byType(BrandMark)),
        Offset(screen.width / 2, screen.height / 2));

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