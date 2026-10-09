import 'package:elan/models.dart';
import 'package:elan/screens.dart';
import 'package:elan/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService().logout();
  });

  test('a password left by older builds is wiped on start-up', () async {
    SharedPreferences.setMockInitialValues({
      'authToken': 'server-token',
      'authUserId': 'U1',
      'lastEmail': 'asha@example.com',
      'lastUserName': 'Asha',
      'lastPassword': 'hunter22',
    });

    await AuthService().checkAutoLogin();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('lastPassword'), isNull);
    expect(AuthService().currentLoggedInUser?.email, 'asha@example.com');
    expect(ApiService().authToken, 'server-token');
  });

  test('no session is restored without a server-issued token', () async {
    // What the old offline sign-up left behind: a name and email, no token.
    SharedPreferences.setMockInitialValues({
      'lastEmail': 'offline@example.com',
      'lastUserName': 'Offline User',
      'lastRole': 'hospital',
    });

    await AuthService().checkAutoLogin();

    expect(AuthService().currentLoggedInUser, isNull);
    expect(AuthService().isReceiverSession, isFalse);
  });

  test('sign-up validation accepts modern email addresses', () async {
    // Validation runs before any network call; a password mismatch proves
    // the email itself passed.
    final error = await AuthService().signUp(
      'Asha',
      'asha+alerts@clinic.health',
      'secret123',
      'different',
    );
    expect(error, 'Passwords do not match');
  });

  group('formatVitalTimestamp', () {
    test('formats ISO timestamps as local day/month and time', () {
      final local = DateTime(2026, 3, 7, 9, 5);
      expect(
        formatVitalTimestamp(local.toUtc().toIso8601String()),
        '07/03 09:05',
      );
    });

    test('passes legacy time-only values through unchanged', () {
      expect(formatVitalTimestamp('10:15 AM'), '10:15 AM');
    });
  });

  test('distances under 1 km read in metres', () {
    expect(formatDistance(0), '0 m');
    expect(formatDistance(0.42), '420 m');
    expect(formatDistance(2.14), '2.1 km');
  });

  group('VitalSigns temperature', () {
    VitalSigns reading(double temperature) => VitalSigns(
          patientId: 'P1',
          patientName: 'Asha',
          heartRate: 72,
          bloodPressure: '120/80',
          temperature: temperature,
          oxygenLevel: 98,
          timestamp: '',
        );

    test('Celsius readings are labelled and flagged in Celsius', () {
      expect(reading(37.9).temperatureLabel, '37.9°C');
      expect(reading(37.9).hasFever, isTrue);
      expect(reading(36.8).hasFever, isFalse);
    });

    test('Fahrenheit readings keep their unit', () {
      expect(reading(98.6).temperatureLabel, '98.6°F');
      expect(reading(98.6).hasFever, isFalse);
      expect(reading(100.4).hasFever, isTrue);
    });
  });
}
