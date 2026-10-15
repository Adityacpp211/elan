import 'package:elan/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpButton(WidgetTester tester, VoidCallback onConfirmed) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: HoldToSendButton(
            label: 'Hold to send alert',
            onConfirmed: onConfirmed,
          ),
        ),
      ),
    ));
  }

  testWidgets('a short press does not send', (tester) async {
    var sent = 0;
    await pumpButton(tester, () => sent++);

    final gesture = await tester
        .startGesture(tester.getCenter(find.byType(HoldToSendButton)));
    // Press registers after the tap timeout; then let the fill animate
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Keep holding…'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(sent, 0);
    expect(find.text('Hold to send alert'), findsOneWidget);
  });

  testWidgets('holding for the full duration sends once', (tester) async {
    var sent = 0;
    await pumpButton(tester, () => sent++);

    final gesture = await tester
        .startGesture(tester.getCenter(find.byType(HoldToSendButton)));
    await tester.pump(const Duration(milliseconds: 150));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(sent, 1);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(sent, 1);
  });
}
