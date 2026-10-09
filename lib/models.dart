// Élan — Models, Services & Utilities

import 'package:flutter/material.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

import 'services/api_service.dart';
import 'services/receiver_service.dart';

// ==================== MODELS ====================

class User {
  final String? id;
  final String name;
  final String email;
  final String password;
  final String phone;
  final String role;
  final String? hospitalId;

  User({
    this.id,
    required this.name,
    required this.email,
    required this.password,
    this.phone = '',
    this.role = 'member',
    this.hospitalId,
  });

  /// Hospital staff sign in to the receiver console instead of the member app.
  bool get isReceiver => role == 'hospital';

  User copyWith(
      {String? name, String? phone, String? role, String? hospitalId}) {
    return User(
      id: id,
      name: name ?? this.name,
      email: email,
      password: password,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      hospitalId: hospitalId ?? this.hospitalId,
    );
  }
}

class PatientRecord {
  final String id;
  final String name;
  final int age;
  final String bloodType;
  final String condition;
  final String admissionDate;
  final String roomNumber;

  PatientRecord({
    required this.id,
    required this.name,
    required this.age,
    required this.bloodType,
    required this.condition,
    required this.admissionDate,
    required this.roomNumber,
  });
}

class VitalSigns {
  final String patientId;
  final String patientName;
  final int heartRate;
  final String bloodPressure;
  final double temperature;
  final int oxygenLevel;
  final String timestamp;

  VitalSigns({
    required this.patientId,
    required this.patientName,
    required this.heartRate,
    required this.bloodPressure,
    required this.temperature,
    required this.oxygenLevel,
    required this.timestamp,
  });

  /// Readings may be entered in °C or °F; no human body is below 50 °F, so
  /// anything under 50 is Celsius.
  bool get isCelsius => temperature < 50;

  /// Temperature normalised to °F for threshold checks.
  double get temperatureF => isCelsius ? temperature * 9 / 5 + 32 : temperature;

  String get temperatureLabel =>
      '${temperature.toStringAsFixed(1)}°${isCelsius ? 'C' : 'F'}';

  /// Fever threshold (37.5 °C / 99.5 °F).
  bool get hasFever => temperatureF > 99.5;
}

class MedicalReport {
  final String id;
  final String patientName;
  final String reportType;
  final String date;
  final String summary;
  final String doctor;

  MedicalReport({
    required this.id,
    required this.patientName,
    required this.reportType,
    required this.date,
    required this.summary,
    required this.doctor,
  });
}

class LocationData {
  final double latitude;
  final double longitude;

  LocationData({
    required this.latitude,
    required this.longitude,
  });
}

/// Outcome of a location lookup: either a real position or a reason the
/// device could not provide one.
class LocationResult {
  final LocationData? location;
  final String? error;

  /// True when the position is the device's last known fix rather than a
  /// fresh reading.
  final bool lastKnown;

  const LocationResult.success(LocationData this.location,
      {this.lastKnown = false})
      : error = null;

  const LocationResult.failure(String this.error)
      : location = null,
        lastKnown = false;
}

class HospitalLocation {
  final String id;
  final String name;
  final String address;
  final String phone;
  final double latitude;
  final double longitude;
  final String emergencyContactEmail;

  HospitalLocation({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.latitude,
    required this.longitude,
    required this.emergencyContactEmail,
  });

  double distanceTo(LocationData userLocation) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(userLocation.latitude - latitude);
    final dLon = _toRadians(userLocation.longitude - longitude);

    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(_toRadians(latitude)) *
            cos(_toRadians(userLocation.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2));

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _toRadians(double degrees) {
    return degrees * pi / 180.0;
  }
}

class HospitalAlert {
  final String id;
  final String hospitalId;
  final String hospitalName;
  final DateTime timestamp;
  final List<String> symptoms;
  final String message;
  final int chargeLevels; // 1, 2, or 3 rupees
  final bool messageDelivered;
  final String userLocation;

  /// The hospital's response, so the sender can see whether help is coming.
  final bool acknowledged;
  final bool declined;
  final int? etaMinutes;

  /// The emergency this dispatch belongs to; one alert fans out to several
  /// hospitals.
  final String alertId;

  HospitalAlert({
    required this.id,
    String? alertId,
    required this.hospitalId,
    required this.hospitalName,
    required this.timestamp,
    required this.symptoms,
    required this.message,
    required this.chargeLevels,
    required this.messageDelivered,
    required this.userLocation,
    this.acknowledged = false,
    this.declined = false,
    this.etaMinutes,
  }) : alertId = alertId ?? id;
}

// ==================== HOSPITAL RECEIVER MODELS ====================

/// Lifecycle of an alert from the receiving hospital's point of view.
enum ReceiverAlertStatus { pending, acknowledged, declined }

ReceiverAlertStatus _statusFrom(String? raw) => switch (raw) {
      'acknowledged' => ReceiverAlertStatus.acknowledged,
      'declined' => ReceiverAlertStatus.declined,
      _ => ReceiverAlertStatus.pending,
    };

class ReceiverAlert {
  final String id;
  final ReceiverAlertStatus status;
  final List<String> symptoms;
  final String message;
  final int tier;
  final String patientName;
  final String patientPhone;
  final double latitude;
  final double longitude;
  final String mapsUrl;
  final double? distanceKm;
  final int? etaMinutes;
  final String? declineReason;
  final bool notified;
  final DateTime? respondedAt;
  final DateTime createdAt;

  const ReceiverAlert({
    required this.id,
    required this.status,
    required this.symptoms,
    required this.message,
    required this.tier,
    required this.patientName,
    required this.patientPhone,
    required this.latitude,
    required this.longitude,
    required this.mapsUrl,
    required this.createdAt,
    this.distanceKm,
    this.etaMinutes,
    this.declineReason,
    this.notified = false,
    this.respondedAt,
  });

  bool get isPending => status == ReceiverAlertStatus.pending;

  factory ReceiverAlert.fromJson(Map<String, dynamic> json) {
    final location = (json['location'] as Map?)?.cast<String, dynamic>() ?? {};
    return ReceiverAlert(
      id: (json['id'] as String?) ?? '',
      status: _statusFrom(json['status'] as String?),
      symptoms: ((json['symptoms'] as List?) ?? const [])
          .map((s) => s.toString())
          .where((s) => s.isNotEmpty)
          .toList(),
      message: (json['message'] as String?) ?? '',
      tier: (json['tier'] as num?)?.toInt() ?? 1,
      patientName: (json['patientName'] as String?) ?? 'Anonymous',
      patientPhone: (json['patientPhone'] as String?) ?? '',
      latitude: (location['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (location['longitude'] as num?)?.toDouble() ?? 0,
      mapsUrl: (location['mapsUrl'] as String?) ?? '',
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      etaMinutes: (json['etaMinutes'] as num?)?.toInt(),
      declineReason: (json['declineReason'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['declineReason'] as String?)?.trim(),
      notified: json['notified'] == true,
      respondedAt: DateTime.tryParse((json['respondedAt'] as String?) ??
          (json['acknowledgedAt'] as String?) ??
          ''),
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status.name,
        'symptoms': symptoms,
        'message': message,
        'tier': tier,
        'patientName': patientName,
        'patientPhone': patientPhone,
        'location': {
          'latitude': latitude,
          'longitude': longitude,
          'mapsUrl': mapsUrl,
        },
        'distanceKm': distanceKm,
        'etaMinutes': etaMinutes,
        'declineReason': declineReason,
        'notified': notified,
        'respondedAt': respondedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };
}

/// The facility a receiver is signed in to.
class ReceiverHospital {
  final String id;
  final String name;
  final String address;
  final String phone;
  final double latitude;
  final double longitude;

  const ReceiverHospital({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.latitude,
    required this.longitude,
  });

  factory ReceiverHospital.fromJson(Map<String, dynamic> json) {
    return ReceiverHospital(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Hospital',
      address: (json['address'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ReceiverStats {
  final int total;
  final int pending;
  final int acknowledged;
  final int declined;

  const ReceiverStats({
    this.total = 0,
    this.pending = 0,
    this.acknowledged = 0,
    this.declined = 0,
  });

  factory ReceiverStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ReceiverStats();
    return ReceiverStats(
      total: (json['total'] as num?)?.toInt() ?? 0,
      pending: (json['pending'] as num?)?.toInt() ?? 0,
      acknowledged: (json['acknowledged'] as num?)?.toInt() ?? 0,
      declined: (json['declined'] as num?)?.toInt() ?? 0,
    );
  }
}

// ==================== AUTH SERVICE ====================

/// Sessions are always issued by the backend. A session from an earlier
/// online sign-in is restored from its stored token so the app can still open
/// while offline, but new accounts and sign-ins need the server — the app
/// never stores a password or invents a local account.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final ApiService _api = ApiService();
  User? _currentLoggedInUser;
  late SharedPreferences _prefs;

  static const _kToken = 'authToken';
  static const _kUserId = 'authUserId';
  static const _kEmail = 'lastEmail';
  static const _kName = 'lastUserName';
  static const _kRole = 'lastRole';
  static const _kHospitalId = 'lastHospitalId';

  /// Older builds kept the plaintext password here; it is wiped on start-up.
  static const _kLegacyPassword = 'lastPassword';

  static const _offlineMessage =
      'Cannot reach the Élan server. Check your internet connection and try again.';

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Check if user is already logged in
  Future<void> checkAutoLogin() async {
    await _initPrefs();
    await _prefs.remove(_kLegacyPassword);

    final token = _prefs.getString(_kToken);
    final userId = _prefs.getString(_kUserId);
    final email = _prefs.getString(_kEmail);
    final name = _prefs.getString(_kName);
    final role = _prefs.getString(_kRole);
    final hospitalId = _prefs.getString(_kHospitalId);

    // Without a server-issued token there is no session to restore.
    if (token == null || userId == null || email == null || name == null) {
      return;
    }

    // The server re-validates the token on the next request; an expired one
    // triggers ApiService.onUnauthorized and signs the user out.
    _api.setAuthToken(token, userId);
    _currentLoggedInUser = User(
      id: userId,
      name: name,
      email: email,
      password: '',
      role: role ?? 'member',
      hospitalId: hospitalId,
    );
  }

  // Get current logged-in user
  User? get currentLoggedInUser => _currentLoggedInUser;

  /// True when the session belongs to hospital staff, who land in the receiver
  /// console rather than the member dashboard.
  bool get isReceiverSession => _currentLoggedInUser?.isReceiver ?? false;

  // Refresh the current user's profile from the server (best effort).
  // Returns null on success, or an error message if the server is unreachable.
  Future<String?> syncProfileFromServer() async {
    final current = _currentLoggedInUser;
    final userId = current?.id;
    if (current == null || userId == null || userId.isEmpty) {
      return 'Not signed in';
    }

    final response = await _api.getProfile();
    if (!response.success) return response.error;

    final data = response.data is Map ? response.data as Map : const {};
    final serverUser = User(
      id: userId,
      name: (data['name'] as String?) ?? current.name,
      email: (data['email'] as String?) ?? current.email,
      password: '',
      phone: (data['phone'] as String?) ?? '',
      role: (data['role'] as String?) ?? current.role,
      hospitalId: (data['hospitalId'] as String?) ?? current.hospitalId,
    );

    await _initPrefs();
    await _prefs.setString(_kName, serverUser.name);
    if (serverUser.role.isNotEmpty) {
      await _prefs.setString(_kRole, serverUser.role);
    }

    _currentLoggedInUser = serverUser;
    return null;
  }

  // Update the current user's profile (name / phone) on the server.
  Future<String?> updateProfile({required String name, String? phone}) async {
    if (name.trim().isEmpty) return 'Name is required';

    final current = _currentLoggedInUser;
    final userId = current?.id;
    if (current == null || userId == null || userId.isEmpty) {
      return 'Not signed in';
    }

    final response = await _api.updateProfile(name: name.trim(), phone: phone);
    if (!response.success) return response.error;

    final userData = response.data is Map && response.data['user'] is Map
        ? response.data['user'] as Map
        : const {};
    await _initPrefs();
    await _prefs.setString(_kName, name.trim());

    _currentLoggedInUser = User(
      id: userId,
      name: (userData['name'] as String?) ?? name.trim(),
      email: (userData['email'] as String?) ?? current.email,
      password: '',
      phone: (userData['phone'] as String?) ?? phone ?? '',
      role: (userData['role'] as String?) ?? current.role,
      hospitalId: (userData['hospitalId'] as String?) ?? current.hospitalId,
    );
    return null;
  }

  // Sign up a new user
  Future<String?> signUp(
    String name,
    String email,
    String password,
    String confirmPassword, {
    String role = 'member',
    String? hospitalId,
  }) async {
    // Validate inputs
    if (name.trim().isEmpty) {
      return 'Name is required';
    }
    if (!_isValidEmail(email.trim())) {
      return 'Please enter a valid email';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }
    if (password != confirmPassword) {
      return 'Passwords do not match';
    }
    if (role == 'hospital' && (hospitalId == null || hospitalId.isEmpty)) {
      return 'Select the hospital you work for';
    }

    final response = await _api.register(
      name: name.trim(),
      email: email.trim(),
      password: password,
      role: role,
      hospitalId: hospitalId,
    );

    if (response.isNetworkError) return _offlineMessage;
    if (!response.success) return response.error ?? 'Registration failed';

    await _completeLoginFromApi(response.data);
    return null;
  }

  // Login user
  Future<String?> login(String email, String password) async {
    if (email.trim().isEmpty) {
      return 'Email is required';
    }
    if (password.trim().isEmpty) {
      return 'Password is required';
    }

    final response = await _api.login(email: email.trim(), password: password);

    if (response.isNetworkError) return _offlineMessage;
    if (!response.success) return response.error ?? 'Login failed';

    await _completeLoginFromApi(response.data);
    return null;
  }

  Future<void> _completeLoginFromApi(dynamic data) async {
    final userData =
        data is Map && data['user'] is Map ? data['user'] as Map : const {};
    final token = data is Map ? data['token'] as String? : null;

    final user = User(
      id: (userData['id'] as String?) ?? '',
      name: (userData['name'] as String?) ?? 'User',
      email: (userData['email'] as String?) ?? '',
      password: '',
      phone: (userData['phone'] as String?) ?? '',
      role: (userData['role'] as String?) ?? 'member',
      hospitalId: (userData['hospitalId'] as String?) ??
          (userData['hospital_id'] as String?),
    );

    if (token != null) {
      _api.setAuthToken(token, user.id ?? '');
    }

    await _initPrefs();
    if (token != null) {
      await _prefs.setString(_kToken, token);
    }
    if (user.id != null) {
      await _prefs.setString(_kUserId, user.id!);
    }
    await _prefs.setString(_kEmail, user.email);
    await _prefs.setString(_kName, user.name);
    await _prefs.setString(_kRole, user.role);
    if (user.hospitalId != null && user.hospitalId!.isNotEmpty) {
      await _prefs.setString(_kHospitalId, user.hospitalId!);
    } else {
      await _prefs.remove(_kHospitalId);
    }
    await _prefs.remove(_kLegacyPassword);

    _currentLoggedInUser = user;
  }

  // Logout user
  Future<void> logout() async {
    _currentLoggedInUser = null;
    _api.clearAuth();
    await ReceiverService().clearCache();
    await _initPrefs();
    await _prefs.remove(_kToken);
    await _prefs.remove(_kUserId);
    await _prefs.remove(_kEmail);
    await _prefs.remove(_kLegacyPassword);
    await _prefs.remove(_kName);
    await _prefs.remove(_kRole);
    await _prefs.remove(_kHospitalId);
  }

  bool _isValidEmail(String email) {
    // Deliberately permissive (allows + tags and long TLDs); the server is
    // the final judge.
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(email);
  }
}

// ==================== LOCATION SERVICE ====================

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// Get the device's real position. Never invents a location: an emergency
  /// alert sent to the wrong place is worse than no alert, so on failure this
  /// returns an [LocationResult.error] the UI must show to the user.
  Future<LocationResult> getCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult.failure(
            'Location services are turned off. Turn on GPS and try again.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult.failure(
            'Location permission is needed to tell hospitals where you are.');
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult.failure(
            'Location permission is blocked. Enable it for Élan in your phone settings.');
      }

      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
        );
        return LocationResult.success(LocationData(
          latitude: position.latitude,
          longitude: position.longitude,
        ));
      } catch (_) {
        // No fresh fix in time (e.g. indoors) — the device's own last fix is
        // still a real reading, so use it but flag it as possibly stale.
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          return LocationResult.success(
            LocationData(latitude: last.latitude, longitude: last.longitude),
            lastKnown: true,
          );
        }
        rethrow;
      }
    } catch (_) {
      return const LocationResult.failure(
          'Could not get a GPS fix. Move near a window or outdoors and retry.');
    }
  }

  // Calculate distance between two points
  static double calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2));

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _toRadians(double degrees) {
    return degrees * pi / 180.0;
  }
}

// ==================== HOSPITAL DIRECTORY ====================

/// Bundled copy of the seeded hospital list. Used only for display when the
/// backend is unreachable (the staff-signup picker and the nearby-hospital
/// preview); alerts are always routed by the server.
///
/// Patient records, vitals, reports and alert history come exclusively from
/// the backend — there is no sample data mixed into a user's real records.
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  List<HospitalLocation> get hospitals => List.unmodifiable(_hospitals);

  // Get nearby hospitals
  List<HospitalLocation> getNearbyHospitals(LocationData userLocation,
      {double radiusKm = 10}) {
    return _hospitals
        .where((hospital) => hospital.distanceTo(userLocation) <= radiusKm)
        .toList()
      ..sort((a, b) =>
          a.distanceTo(userLocation).compareTo(b.distanceTo(userLocation)));
  }

  static final List<HospitalLocation> _hospitals = [
    HospitalLocation(
      id: 'H001',
      name: 'Bahubali Children Hospital',
      address:
          'Shri Dhavala Teertham, Chalya Post, Shravanabelagola (Hirisave Road), SH-8, Karnataka',
      phone: '+91-81763-41450',
      latitude: 12.8540,
      longitude: 76.4850,
      emergencyContactEmail: 'contact@bahubali-hospital.com',
    ),
    HospitalLocation(
      id: 'H002',
      name: 'Shravanabelagola Government Hospital',
      address:
          'Shravanabelagola Main Road, Shravanabelagola, Karnataka 573135',
      phone: '+91-81726-00000',
      latitude: 12.8585,
      longitude: 76.4880,
      emergencyContactEmail: 'govt-hospital@shravanabelagola.gov.in',
    ),
    HospitalLocation(
      id: 'H003',
      name: 'Swayam Sevak Nagara Hospital',
      address: 'Shravanabelagola area, Karnataka',
      phone: '+91-81726-00001',
      latitude: 12.8560,
      longitude: 76.4900,
      emergencyContactEmail: 'swayamsevak@hospital.com',
    ),
    HospitalLocation(
      id: 'H004',
      name: 'Primary Health Centre (PHC) - Chalya',
      address: 'Chalya / Nirisare Road, Shravanabelagola, Karnataka',
      phone: '+91-81726-00002',
      latitude: 12.8450,
      longitude: 76.4750,
      emergencyContactEmail: 'phc-chalya@karnataka.gov.in',
    ),
];
}

// ==================== RESPONSIVE UTILITIES ====================

class ResponsiveHelper {
  // Breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;

  // Screen type detection
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  // Responsive padding
  static double getPadding(BuildContext context) {
    if (isMobile(context)) return 16.0;
    if (isTablet(context)) return 24.0;
    return 32.0;
  }

  static double getCardPadding(BuildContext context) {
    if (isMobile(context)) return 20.0;
    if (isTablet(context)) return 28.0;
    return 32.0;
  }

  // Responsive font sizes
  static double getHeadlineSize(BuildContext context) {
    if (isMobile(context)) return 28.0;
    if (isTablet(context)) return 30.0;
    return 32.0;
  }

  static double getTitleSize(BuildContext context) {
    if (isMobile(context)) return 20.0;
    if (isTablet(context)) return 22.0;
    return 24.0;
  }

  static double getBodySize(BuildContext context) {
    if (isMobile(context)) return 14.0;
    if (isTablet(context)) return 15.0;
    return 16.0;
  }

  static double getCaptionSize(BuildContext context) {
    if (isMobile(context)) return 12.0;
    return 14.0;
  }

  // Responsive icon sizes
  static double getIconSize(BuildContext context, double baseSize) {
    if (isMobile(context)) return baseSize * 0.85;
    return baseSize;
  }

  // Card max width
  static double getCardMaxWidth(BuildContext context) {
    if (isMobile(context)) return double.infinity;
    if (isTablet(context)) return 500;
    return 450;
  }

  // Grid columns for dashboard
  static int getDashboardColumns(BuildContext context) {
    if (isMobile(context)) return 1;
    return 2;
  }

  // Responsive spacing
  static double getSpacing(BuildContext context) {
    if (isMobile(context)) return 12.0;
    return 16.0;
  }
}
