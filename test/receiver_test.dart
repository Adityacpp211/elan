import 'dart:convert';

import 'package:elan/models.dart';
import 'package:elan/screens.dart';
import 'package:elan/services/receiver_service.dart';
import 'package:elan/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A receiver alert as the receiver API would deliver it (nested `location`).
ReceiverAlert sampleAlert({
  String id = 'A1',
  ReceiverAlertStatus status = ReceiverAlertStatus.pending,
  List<String> symptoms = const ['Chest pain', 'Breathlessness'],
  int? etaMinutes,
  String? declineReason,
  int minutesAgo = 4,
}) {
  return ReceiverAlert.fromJson({
    'id': id,
    'status': status.name,
    'symptoms': symptoms,
    'message': 'Father collapsed at home',
    'tier': 2,
    'patientName': 'Ravi Kumar',
    'patientPhone': '+91-90000-00000',
    'location': {
      'latitude': 12.8585,
      'longitude': 76.488,
      'mapsUrl':
          'https://www.google.com/maps/search/?api=1&query=12.8585,76.488',
    },
    'distanceKm': 0.42,
    'etaMinutes': etaMinutes,
    'declineReason': declineReason,
    'notified': true,
    'createdAt': DateTime.now()
        .subtract(Duration(minutes: minutesAgo))
        .toIso8601String(),
  });
}

/// Put a hospital-staff session plus a cached inbox in place so the console
/// renders real data without reaching the backend.
Future<void> seedReceiverSession(List<ReceiverAlert> alerts) async {
  await ReceiverService().clearCache();
  await AuthService().logout();

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('authToken', 'test-token');
  await prefs.setString('authUserId', 'U-RECEIVER');
  await prefs.setString('lastEmail', 'duty@bahubali-hospital.com');
  await prefs.setString('lastUserName', 'Duty Officer');
  await prefs.setString('lastRole', 'hospital');
  await prefs.setString('lastHospitalId', 'H001');
  await prefs.setString(
    'receiverInboxCache',
    jsonEncode(alerts.map((a) => a.toJson()).toList()),
  );
  await prefs.setString(
    'receiverHospitalCache',
    jsonEncode({
      'id': 'H001',
      'name': 'Bahubali Children Hospital',
      'address': 'Shravanabelagola, Karnataka',
      'phone': '+91-81763-41450',
      'latitude': 12.854,
      'longitude': 76.485,
    }),
  );

  await AuthService().checkAutoLogin();
}

Future<void> pumpConsole(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: const ReceiverConsole(),
    ),
  );
  // The console reads its cache and then attempts a server refresh; give both
  // async hops room to settle inside the test's fake clock.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await ReceiverService().clearCache();
    await AuthService().logout();
  });

  testWidgets('receiver console lists the hospital inbox from cache',
      (WidgetTester tester) async {
    await seedReceiverSession([sampleAlert()]);
    await pumpConsole(tester);

    // Header is the facility, not the member dashboard.
    expect(find.text('Bahubali Children Hospital'), findsOneWidget);
    expect(find.text('RECEIVER CONSOLE'), findsOneWidget);
    expect(find.text('duty@bahubali-hospital.com'), findsOneWidget);

    // The alert card carries the patient, symptoms, and distance.
    expect(find.text('Ravi Kumar'), findsOneWidget);
    expect(find.text('Chest pain'), findsOneWidget);
    expect(find.text('Breathlessness'), findsOneWidget);
    expect(find.text('0.4 km'), findsOneWidget);

    // Counters reflect the cached inbox: one new, nothing accepted or passed.
    expect(find.text('AWAITING'), findsOneWidget);
    expect(find.text('1'), findsWidgets);

    // A new alert is actionable.
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Pass'), findsOneWidget);

    // Server was unreachable, so the offline banner is shown.
    expect(
      find.text('Offline — showing the last alerts this desk received'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('accepted alert shows the ETA and hides the response actions',
      (WidgetTester tester) async {
    await seedReceiverSession([
      sampleAlert(
        status: ReceiverAlertStatus.acknowledged,
        etaMinutes: 8,
      )
    ]);
    await pumpConsole(tester);

    expect(find.text('Team en route · ~8 min'), findsOneWidget);
    expect(find.text('Accept'), findsNothing);
    expect(find.text('Pass'), findsNothing);
    expect(find.text('Accepted'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('passed alert keeps the decline reason on the card',
      (WidgetTester tester) async {
    await seedReceiverSession([
      sampleAlert(
        status: ReceiverAlertStatus.declined,
        declineReason: 'No cath lab available tonight',
      )
    ]);
    await pumpConsole(tester);

    expect(find.text('No cath lab available tonight'), findsOneWidget);
    expect(find.text('Accept'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('filter chips narrow the inbox to one status',
      (WidgetTester tester) async {
    await seedReceiverSession([
      sampleAlert(id: 'A1'),
      sampleAlert(
        id: 'A2',
        status: ReceiverAlertStatus.acknowledged,
        etaMinutes: 4,
        minutesAgo: 9,
      ),
    ]);
    await pumpConsole(tester);

    expect(find.text('Ravi Kumar'), findsNWidgets(2));

    await tester.tap(find.textContaining('New  1'));
    await tester.pump();

    expect(find.text('Ravi Kumar'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('login offers the hospital staff desk',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const LoginScreen(hospitalMode: true),
      ),
    );
    await tester.pump();

    expect(find.text('RECEIVER DESK'), findsOneWidget);
    expect(find.text('Sign in to receive and respond to Élan alerts'),
        findsOneWidget);
    expect(find.text('Hospital staff'), findsOneWidget);
  });
}
