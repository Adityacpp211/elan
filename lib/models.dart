// CardioAid — Models, Services & Utilities

import 'package:flutter/material.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

import 'services/api_service.dart';

// ==================== MODELS ====================

class User {
  final String? id;
  final String name;
  final String email;
  final String password;

  User({
    this.id,
    required this.name,
    required this.email,
    required this.password,
  });
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
}

class EmergencyRecord {
  final String id;
  final String timestamp;
  final bool responsiveness;
  final bool breathing;
  final bool pulse;
  final bool heartRhythm;
  final String status; // Critical, Stable, Resolved

  EmergencyRecord({
    required this.id,
    required this.timestamp,
    required this.responsiveness,
    required this.breathing,
    required this.pulse,
    required this.heartRhythm,
    required this.status,
  });
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

class UserProfile {
  final String name;
  final String email;
  final String role;
  final String employeeId;
  final String department;
  final String phone;
  final String profileImage;

  UserProfile({
    required this.name,
    required this.email,
    required this.role,
    required this.employeeId,
    required this.department,
    required this.phone,
    required this.profileImage,
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

  HospitalAlert({
    required this.id,
    required this.hospitalId,
    required this.hospitalName,
    required this.timestamp,
    required this.symptoms,
    required this.message,
    required this.chargeLevels,
    required this.messageDelivered,
    required this.userLocation,
  });
}

// ==================== AUTH SERVICE ====================

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final List<User> _users = [];
  final ApiService _api = ApiService();
  User? _currentLoggedInUser;
  late SharedPreferences _prefs;

  static const _kToken = 'authToken';
  static const _kUserId = 'authUserId';
  static const _kEmail = 'lastEmail';
  static const _kName = 'lastUserName';
  static const _kPassword = 'lastPassword';

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Check if user is already logged in
  Future<void> checkAutoLogin() async {
    await _initPrefs();
    final token = _prefs.getString(_kToken);
    final userId = _prefs.getString(_kUserId);
    final email = _prefs.getString(_kEmail);
    final name = _prefs.getString(_kName);

    if (email != null && name != null) {
      if (token != null) {
        // Restore backend session; on next contact with the server we will
        // re-validate and can hard-refresh the profile if needed.
        ApiService().setAuthToken(token, userId ?? '');
      }
      _currentLoggedInUser =
          User(id: userId, name: name, email: email, password: '');
    }
  }

  // Get current logged-in user
  User? get currentLoggedInUser => _currentLoggedInUser;

  // Sign up a new user
  Future<String?> signUp(String name, String email, String password,
      String confirmPassword) async {
    // Validate inputs
    if (name.trim().isEmpty) {
      return 'Name is required';
    }
    if (!_isValidEmail(email)) {
      return 'Please enter a valid email';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }
    if (password != confirmPassword) {
      return 'Passwords do not match';
    }

    // Try server-side registration first (source of truth)
    final response = await _api.register(
      name: name.trim(),
      email: email.trim(),
      password: password,
    );

    if (response.success) {
      await _completeLoginFromApi(response.data);
      return null;
    }

    // Backend reachable and rejected the registration — surface the error.
    if (!_isNetworkError(response.error)) {
      return response.error ?? 'Registration failed';
    }

    // Offline fallback: register locally so the demo keeps working.
    if (_users.any((user) => user.email.toLowerCase() == email.toLowerCase())) {
      return 'Email already registered';
    }

    final newUser = User(name: name.trim(), email: email.trim(), password: password);
    _users.add(newUser);

    await _initPrefs();
    await _prefs.setString(_kEmail, email.trim());
    await _prefs.setString(_kName, name.trim());
    await _prefs.setString(_kPassword, password);

    _currentLoggedInUser = newUser;
    return null; // Success
  }

  // Login user
  Future<String?> login(String email, String password) async {
    if (email.trim().isEmpty) {
      return 'Email is required';
    }
    if (password.trim().isEmpty) {
      return 'Password is required';
    }

    // Try server-side login first (source of truth)
    final response = await _api.login(email: email.trim(), password: password);

    if (response.success) {
      await _completeLoginFromApi(response.data);
      return null;
    }

    // Backend reachable and rejected the credentials — surface the error.
    if (!_isNetworkError(response.error)) {
      return response.error ?? 'Login failed';
    }

    // Offline fallback: check locally registered accounts.
    final user = _users.firstWhere(
      (user) => user.email.toLowerCase() == email.toLowerCase(),
      orElse: () => User(name: '', email: '', password: ''),
    );

    if (user.email.isEmpty) {
      return 'No account found with this email';
    }

    if (user.password != password) {
      return 'Incorrect password';
    }

    await _initPrefs();
    await _prefs.setString(_kEmail, email.trim());
    await _prefs.setString(_kName, user.name);
    await _prefs.setString(_kPassword, password);

    _currentLoggedInUser = user;
    return null; // Success
  }

  Future<void> _completeLoginFromApi(dynamic data) async {
    final userData = data['user'] ?? {};
    final token = data['token'] as String?;

    final user = User(
      id: (userData['id'] as String?) ?? '',
      name: (userData['name'] as String?) ?? 'User',
      email: (userData['email'] as String?) ?? '',
      password: '',
    );

    if (!_users.any(
        (existing) => existing.email.toLowerCase() == user.email.toLowerCase())) {
      _users.add(user);
    }

    if (token != null) {
      ApiService().setAuthToken(token, user.id ?? '');
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
    await _prefs.remove(_kPassword);

    _currentLoggedInUser = user;
  }

  bool _isNetworkError(String? error) {
    if (error == null) return false;
    return error.startsWith('Network error');
  }

  // Logout user
  Future<void> logout() async {
    _currentLoggedInUser = null;
    ApiService().clearAuth();
    await _initPrefs();
    await _prefs.remove(_kToken);
    await _prefs.remove(_kUserId);
    await _prefs.remove(_kEmail);
    await _prefs.remove(_kPassword);
    await _prefs.remove(_kName);
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // Get registered users count (for debugging)
  int get userCount => _users.length;
}

// ==================== LOCATION SERVICE ====================

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Future<LocationData?> getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final result = await Geolocator.requestPermission();
        if (result == LocationPermission.deniedForever) {
          return null;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      // For demo, return a default location (Bangalore, India)
      return LocationData(latitude: 12.9716, longitude: 77.5946);
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

// ==================== DATABASE SERVICE ====================

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal() {
    _initializeSampleData();
  }

  final List<PatientRecord> _patients = [];
  final List<VitalSigns> _vitalSigns = [];
  final List<EmergencyRecord> _emergencyRecords = [];
  final List<MedicalReport> _reports = [];
  final List<HospitalLocation> _hospitals = [];
  final List<HospitalAlert> _hospitalAlerts = [];
  UserProfile? _currentUser;

  // Getters
  List<PatientRecord> get patients => List.unmodifiable(_patients);
  List<VitalSigns> get vitalSigns => List.unmodifiable(_vitalSigns);
  List<EmergencyRecord> get emergencyRecords =>
      List.unmodifiable(_emergencyRecords);
  List<MedicalReport> get reports => List.unmodifiable(_reports);
  List<HospitalLocation> get hospitals => List.unmodifiable(_hospitals);
  List<HospitalAlert> get hospitalAlerts => List.unmodifiable(_hospitalAlerts);
  UserProfile? get currentUser => _currentUser;

  // Add hospital alert
  void addHospitalAlert(HospitalAlert alert) {
    _hospitalAlerts.add(alert);
  }

  // Get nearby hospitals
  List<HospitalLocation> getNearbyHospitals(LocationData userLocation,
      {double radiusKm = 10}) {
    return _hospitals
        .where((hospital) => hospital.distanceTo(userLocation) <= radiusKm)
        .toList()
      ..sort((a, b) =>
          a.distanceTo(userLocation).compareTo(b.distanceTo(userLocation)));
  }

  void _initializeSampleData() {
    // Initialize User Profile
    _currentUser = UserProfile(
      name: 'Dr. Sarah Johnson',
      email: 'sarah.johnson@cardioaid.com',
      role: 'Emergency Physician',
      employeeId: 'EMP-2024-001',
      department: 'Emergency Medicine',
      phone: '+1 (555) 987-6543',
      profileImage: 'assets/profile_placeholder.png',
    );

    // Initialize Patient Records
    _patients.addAll([
      PatientRecord(
        id: 'P001',
        name: 'John Anderson',
        age: 65,
        bloodType: 'O+',
        condition: 'Stable - Post MI',
        admissionDate: '2026-01-10',
        roomNumber: '301',
      ),
      PatientRecord(
        id: 'P002',
        name: 'Maria Garcia',
        age: 52,
        bloodType: 'A+',
        condition: 'Critical - Cardiac Arrest',
        admissionDate: '2026-01-14',
        roomNumber: 'ICU-2',
      ),
      PatientRecord(
        id: 'P003',
        name: 'Robert Chen',
        age: 71,
        bloodType: 'B-',
        condition: 'Monitoring - Heart Failure',
        admissionDate: '2026-01-12',
        roomNumber: '215',
      ),
      PatientRecord(
        id: 'P004',
        name: 'Jennifer Williams',
        age: 48,
        bloodType: 'AB+',
        condition: 'Stable - Chest Pain Evaluation',
        admissionDate: '2026-01-13',
        roomNumber: '402',
      ),
      PatientRecord(
        id: 'P005',
        name: 'Michael Brown',
        age: 58,
        bloodType: 'O-',
        condition: 'Critical - Unstable Angina',
        admissionDate: '2026-01-14',
        roomNumber: 'ICU-5',
      ),
      PatientRecord(
        id: 'P006',
        name: 'Linda Martinez',
        age: 63,
        bloodType: 'A-',
        condition: 'Stable - Arrhythmia',
        admissionDate: '2026-01-11',
        roomNumber: '318',
      ),
      PatientRecord(
        id: 'P007',
        name: 'David Lee',
        age: 55,
        bloodType: 'B+',
        condition: 'Monitoring - Hypertension',
        admissionDate: '2026-01-13',
        roomNumber: '225',
      ),
      PatientRecord(
        id: 'P008',
        name: 'Patricia Davis',
        age: 69,
        bloodType: 'O+',
        condition: 'Stable - Recovering',
        admissionDate: '2026-01-09',
        roomNumber: '412',
      ),
      PatientRecord(
        id: 'P009',
        name: 'James Wilson',
        age: 76,
        bloodType: 'A+',
        condition: 'Critical - Heart Attack',
        admissionDate: '2026-01-15',
        roomNumber: 'ICU-1',
      ),
      PatientRecord(
        id: 'P010',
        name: 'Elizabeth Taylor',
        age: 44,
        bloodType: 'AB-',
        condition: 'Stable - Observation',
        admissionDate: '2026-01-14',
        roomNumber: '307',
      ),
    ]);

    // Initialize Vital Signs
    _vitalSigns.addAll([
      VitalSigns(
          patientId: 'P001',
          patientName: 'John Anderson',
          heartRate: 72,
          bloodPressure: '120/80',
          temperature: 98.6,
          oxygenLevel: 98,
          timestamp: '10:15 AM'),
      VitalSigns(
          patientId: 'P002',
          patientName: 'Maria Garcia',
          heartRate: 145,
          bloodPressure: '160/95',
          temperature: 99.2,
          oxygenLevel: 89,
          timestamp: '10:20 AM'),
      VitalSigns(
          patientId: 'P003',
          patientName: 'Robert Chen',
          heartRate: 88,
          bloodPressure: '135/85',
          temperature: 98.4,
          oxygenLevel: 94,
          timestamp: '10:25 AM'),
      VitalSigns(
          patientId: 'P004',
          patientName: 'Jennifer Williams',
          heartRate: 78,
          bloodPressure: '118/75',
          temperature: 98.7,
          oxygenLevel: 97,
          timestamp: '10:30 AM'),
      VitalSigns(
          patientId: 'P005',
          patientName: 'Michael Brown',
          heartRate: 132,
          bloodPressure: '155/92',
          temperature: 99.8,
          oxygenLevel: 91,
          timestamp: '10:35 AM'),
      VitalSigns(
          patientId: 'P006',
          patientName: 'Linda Martinez',
          heartRate: 76,
          bloodPressure: '125/82',
          temperature: 98.5,
          oxygenLevel: 96,
          timestamp: '10:40 AM'),
      VitalSigns(
          patientId: 'P007',
          patientName: 'David Lee',
          heartRate: 82,
          bloodPressure: '142/88',
          temperature: 98.8,
          oxygenLevel: 95,
          timestamp: '10:45 AM'),
      VitalSigns(
          patientId: 'P008',
          patientName: 'Patricia Davis',
          heartRate: 70,
          bloodPressure: '115/72',
          temperature: 98.3,
          oxygenLevel: 99,
          timestamp: '10:50 AM'),
      VitalSigns(
          patientId: 'P009',
          patientName: 'James Wilson',
          heartRate: 156,
          bloodPressure: '170/98',
          temperature: 100.1,
          oxygenLevel: 87,
          timestamp: '10:55 AM'),
      VitalSigns(
          patientId: 'P010',
          patientName: 'Elizabeth Taylor',
          heartRate: 74,
          bloodPressure: '122/78',
          temperature: 98.6,
          oxygenLevel: 97,
          timestamp: '11:00 AM'),
      VitalSigns(
          patientId: 'P001',
          patientName: 'John Anderson',
          heartRate: 68,
          bloodPressure: '118/76',
          temperature: 98.4,
          oxygenLevel: 99,
          timestamp: '11:15 AM'),
      VitalSigns(
          patientId: 'P002',
          patientName: 'Maria Garcia',
          heartRate: 138,
          bloodPressure: '158/93',
          temperature: 99.4,
          oxygenLevel: 90,
          timestamp: '11:20 AM'),
      VitalSigns(
          patientId: 'P003',
          patientName: 'Robert Chen',
          heartRate: 85,
          bloodPressure: '132/83',
          temperature: 98.3,
          oxygenLevel: 95,
          timestamp: '11:25 AM'),
      VitalSigns(
          patientId: 'P005',
          patientName: 'Michael Brown',
          heartRate: 128,
          bloodPressure: '152/90',
          temperature: 99.6,
          oxygenLevel: 92,
          timestamp: '11:35 AM'),
      VitalSigns(
          patientId: 'P009',
          patientName: 'James Wilson',
          heartRate: 148,
          bloodPressure: '165/96',
          temperature: 99.9,
          oxygenLevel: 88,
          timestamp: '11:55 AM'),
    ]);

    // Initialize Emergency Records
    _emergencyRecords.addAll([
      EmergencyRecord(
          id: 'E001',
          timestamp: '2026-01-15 09:15 AM',
          responsiveness: true,
          breathing: true,
          pulse: true,
          heartRhythm: false,
          status: 'Stable'),
      EmergencyRecord(
          id: 'E002',
          timestamp: '2026-01-15 08:45 AM',
          responsiveness: false,
          breathing: false,
          pulse: true,
          heartRhythm: false,
          status: 'Critical'),
      EmergencyRecord(
          id: 'E003',
          timestamp: '2026-01-14 11:30 PM',
          responsiveness: true,
          breathing: true,
          pulse: true,
          heartRhythm: true,
          status: 'Resolved'),
      EmergencyRecord(
          id: 'E004',
          timestamp: '2026-01-14 06:20 PM',
          responsiveness: true,
          breathing: false,
          pulse: true,
          heartRhythm: false,
          status: 'Critical'),
      EmergencyRecord(
          id: 'E005',
          timestamp: '2026-01-14 02:15 PM',
          responsiveness: true,
          breathing: true,
          pulse: true,
          heartRhythm: true,
          status: 'Stable'),
      EmergencyRecord(
          id: 'E006',
          timestamp: '2026-01-13 09:45 AM',
          responsiveness: true,
          breathing: true,
          pulse: false,
          heartRhythm: false,
          status: 'Critical'),
      EmergencyRecord(
          id: 'E007',
          timestamp: '2026-01-13 07:30 AM',
          responsiveness: true,
          breathing: true,
          pulse: true,
          heartRhythm: true,
          status: 'Resolved'),
    ]);

    // Initialize Medical Reports
    _reports.addAll([
      MedicalReport(
        id: 'R001',
        patientName: 'John Anderson',
        reportType: 'ECG Analysis',
        date: '2026-01-14',
        summary:
            'Normal sinus rhythm. No acute ST changes. Previous MI evidence present.',
        doctor: 'Dr. Sarah Johnson',
      ),
      MedicalReport(
        id: 'R002',
        patientName: 'Maria Garcia',
        reportType: 'Emergency Assessment',
        date: '2026-01-15',
        summary:
            'Cardiac arrest protocol initiated. ROSC achieved after 4 minutes. Critical condition.',
        doctor: 'Dr. Michael Roberts',
      ),
      MedicalReport(
        id: 'R003',
        patientName: 'Robert Chen',
        reportType: 'Cardiology Consult',
        date: '2026-01-13',
        summary:
            'Heart failure exacerbation. Diuretic therapy adjusted. Close monitoring required.',
        doctor: 'Dr. Emily Chen',
      ),
      MedicalReport(
        id: 'R004',
        patientName: 'Jennifer Williams',
        reportType: 'Chest Pain Evaluation',
        date: '2026-01-13',
        summary:
            'Troponin negative. Stress test scheduled. Non-cardiac chest pain likely.',
        doctor: 'Dr. Sarah Johnson',
      ),
      MedicalReport(
        id: 'R005',
        patientName: 'Michael Brown',
        reportType: 'Cardiac Catheterization',
        date: '2026-01-14',
        summary:
            '90% LAD stenosis identified. Stent placement recommended. High-risk patient.',
        doctor: 'Dr. David Martinez',
      ),
      MedicalReport(
        id: 'R006',
        patientName: 'Linda Martinez',
        reportType: 'Holter Monitor Results',
        date: '2026-01-12',
        summary:
            'Intermittent atrial fibrillation detected. Anticoagulation initiated.',
        doctor: 'Dr. Emily Chen',
      ),
      MedicalReport(
        id: 'R007',
        patientName: 'David Lee',
        reportType: 'Blood Pressure Management',
        date: '2026-01-13',
        summary:
            'Hypertension poorly controlled. Medication regimen adjusted. Follow-up in 2 weeks.',
        doctor: 'Dr. Sarah Johnson',
      ),
      MedicalReport(
        id: 'R008',
        patientName: 'James Wilson',
        reportType: 'STEMI Protocol',
        date: '2026-01-15',
        summary:
            'Anterior wall STEMI. Emergent PCI performed. Patient stabilized in ICU.',
        doctor: 'Dr. Michael Roberts',
      ),
    ]);

    // Initialize Hospital Locations (Shravanabelagola area)
    _hospitals.addAll([
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
    ]);
  }

  // Add methods (for future functionality)
  void addPatient(PatientRecord patient) => _patients.add(patient);
  void addVitalSigns(VitalSigns vitals) => _vitalSigns.add(vitals);
  void addEmergencyRecord(EmergencyRecord record) =>
      _emergencyRecords.add(record);
  void addReport(MedicalReport report) => _reports.add(report);
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