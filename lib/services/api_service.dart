import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// API Service for Élan Backend
/// Handles all communication with the Node.js backend server
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  /// Backend address. Defaults to the Android emulator's view of the host
  /// machine; override per build with
  /// `--dart-define=API_BASE_URL=https://api.example.com`
  /// (e.g. `http://localhost:3000` for iOS simulator / web, or the LAN IP of
  /// your machine for a physical device).
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  /// How long any single request may take before it is treated as a network
  /// failure. Without this an emergency request could hang indefinitely.
  static const Duration requestTimeout = Duration(seconds: 15);

  String? _authToken;
  String? _userId;

  /// Called once when an authenticated request comes back 401 (token expired
  /// or revoked) so the app can sign the user out instead of failing silently.
  void Function()? onUnauthorized;

  // Getters
  String? get authToken => _authToken;
  String? get userId => _userId;
  bool get isAuthenticated => _authToken != null;

  // Set auth token (called after login)
  void setAuthToken(String token, String id) {
    _authToken = token;
    _userId = id;
  }

  // Clear auth token (called on logout)
  void clearAuth() {
    _authToken = null;
    _userId = null;
  }

  // Headers with auth
  Map<String, String> _headers({bool auth = false}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (auth && _authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  dynamic _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  /// Every endpoint goes through here: one place for timeouts, error
  /// extraction (bodies may be non-JSON, e.g. a proxy's HTML error page) and
  /// expired-session handling.
  Future<ApiResponse> _request(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    bool auth = false,
    int expectStatus = 200,
    Duration timeout = requestTimeout,
    required String fallbackError,
  }) async {
    var uri = Uri.parse('$baseUrl$path');
    if (query != null) uri = uri.replace(queryParameters: query);

    final headers = _headers(auth: auth);
    final encoded = body == null ? null : jsonEncode(body);

    final http.Response response;
    try {
      final Future<http.Response> call = switch (method) {
        'GET' => http.get(uri, headers: headers),
        'POST' => http.post(uri, headers: headers, body: encoded),
        'PUT' => http.put(uri, headers: headers, body: encoded),
        'DELETE' => http.delete(uri, headers: headers),
        _ => throw ArgumentError('Unsupported method $method'),
      };
      response = await call.timeout(timeout);
    } on TimeoutException {
      return ApiResponse.networkError('the server did not respond in time');
    } catch (e) {
      return ApiResponse.networkError('could not reach the server');
    }

    final data = _tryDecode(response.body);

    if (response.statusCode == expectStatus) {
      return ApiResponse.success(data);
    }

    if (response.statusCode == 401 && auth && _authToken != null) {
      clearAuth();
      onUnauthorized?.call();
      return ApiResponse.error('Your session has expired. Please sign in again.');
    }

    final message = data is Map && data['error'] is String
        ? data['error'] as String
        : fallbackError;
    return ApiResponse.error(message, data: data);
  }

  // ==================== SERVER / PROFILE ====================

  /// Check whether the backend is reachable
  Future<bool> checkServerHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get current user profile from the server
  Future<ApiResponse> getProfile() => _request('GET', '/api/auth/me',
      auth: true, fallbackError: 'Failed to fetch profile');

  /// Update current user profile (name / phone)
  Future<ApiResponse> updateProfile({String? name, String? phone}) =>
      _request('PUT', '/api/auth/me',
          auth: true,
          body: {
            if (name != null) 'name': name,
            if (phone != null) 'phone': phone,
          },
          fallbackError: 'Failed to update profile');

  // ==================== AUTH ENDPOINTS ====================

  /// Register a new user
  Future<ApiResponse> register({
    required String name,
    required String email,
    required String password,
    String role = 'member',
    String? hospitalId,
  }) async {
    final response = await _request('POST', '/api/auth/register',
        body: {
          'name': name,
          'email': email,
          'password': password,
          'role': role,
          if (hospitalId != null && hospitalId.isNotEmpty)
            'hospitalId': hospitalId,
        },
        expectStatus: 201,
        fallbackError: 'Registration failed');
    _captureSession(response);
    return response;
  }

  /// Login user
  Future<ApiResponse> login({
    required String email,
    required String password,
    String? fcmToken,
  }) async {
    final response = await _request('POST', '/api/auth/login',
        body: {
          'email': email,
          'password': password,
          if (fcmToken != null) 'fcmToken': fcmToken,
        },
        fallbackError: 'Login failed');
    _captureSession(response);
    return response;
  }

  void _captureSession(ApiResponse response) {
    final data = response.data;
    if (!response.success || data is! Map) return;
    final token = data['token'];
    final user = data['user'];
    if (token is String && user is Map && user['id'] is String) {
      setAuthToken(token, user['id'] as String);
    }
  }

  /// Update user's current location
  Future<ApiResponse> updateLocation({
    required double latitude,
    required double longitude,
  }) =>
      _request('POST', '/api/auth/location',
          auth: true,
          body: {'latitude': latitude, 'longitude': longitude},
          fallbackError: 'Failed to update location');

  /// Update FCM token
  Future<ApiResponse> updateFcmToken(String fcmToken) =>
      _request('POST', '/api/auth/fcm-token',
          auth: true,
          body: {'fcmToken': fcmToken},
          fallbackError: 'Failed to update FCM token');

  // ==================== HOSPITAL ENDPOINTS ====================

  /// Get every verified hospital (used to pick a facility when signing up as staff)
  Future<ApiResponse> getHospitals() => _request('GET', '/api/hospitals',
      fallbackError: 'Failed to fetch hospitals');

  /// Get nearby hospitals
  Future<ApiResponse> getNearbyHospitals({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    int limit = 10,
  }) =>
      _request('GET', '/api/hospitals/nearby',
          query: {
            'lat': latitude.toString(),
            'lng': longitude.toString(),
            'radius': radiusKm.toString(),
            'limit': limit.toString(),
          },
          fallbackError: 'Failed to fetch hospitals');

  // ==================== PAYMENT ENDPOINTS ====================

  /// Create a payment order for emergency alert
  Future<ApiResponse> createPaymentOrder({
    required int tier, // 1, 2, or 3
    required double latitude,
    required double longitude,
    String? symptoms,
    String? message,
  }) =>
      _request('POST', '/api/payments/create-order',
          auth: true,
          body: {
            'tier': tier,
            'latitude': latitude,
            'longitude': longitude,
            if (symptoms != null) 'symptoms': symptoms,
            if (message != null) 'message': message,
          },
          fallbackError: 'Failed to create order');

  /// Verify payment after Razorpay callback
  Future<ApiResponse> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
    required String alertId,
  }) =>
      _request('POST', '/api/payments/verify',
          auth: true,
          body: {
            'orderId': orderId,
            'paymentId': paymentId,
            'signature': signature,
            'alertId': alertId,
          },
          fallbackError: 'Payment verification failed');

  // ==================== ALERT ENDPOINTS ====================

  /// Send emergency alert (after payment is verified)
  Future<ApiResponse> sendEmergencyAlert(String alertId) =>
      _request('POST', '/api/alerts/send',
          auth: true,
          body: {'alertId': alertId},
          // Dispatch fans out push + email to every hospital; give it room
          timeout: const Duration(seconds: 45),
          fallbackError: 'Failed to send alert');

  /// Get alert history
  Future<ApiResponse> getAlertHistory() => _request('GET', '/api/alerts/history',
      auth: true, fallbackError: 'Failed to fetch alerts');

  /// Get single alert details
  Future<ApiResponse> getAlertDetails(String alertId) =>
      _request('GET', '/api/alerts/${Uri.encodeComponent(alertId)}',
          auth: true, fallbackError: 'Failed to fetch alert');

  // ==================== HOSPITAL RECEIVER ENDPOINTS ====================

  /// Alerts addressed to the signed-in hospital
  Future<ApiResponse> getReceiverInbox({String? status, int limit = 50}) =>
      _request('GET', '/api/receiver/inbox',
          auth: true,
          query: {
            if (status != null && status != 'all') 'status': status,
            'limit': '$limit',
          },
          fallbackError: 'Failed to fetch receiver inbox');

  /// Get a single alert as the hospital sees it
  Future<ApiResponse> getReceiverAlert(String alertId) =>
      _request('GET', '/api/receiver/inbox/${Uri.encodeComponent(alertId)}',
          auth: true, fallbackError: 'Failed to fetch alert');

  /// Take the alert: the patient sees the hospital as acknowledged
  Future<ApiResponse> acknowledgeReceiverAlert(
    String alertId, {
    int? etaMinutes,
  }) =>
      _request('POST',
          '/api/receiver/alerts/${Uri.encodeComponent(alertId)}/acknowledge',
          auth: true,
          body: {if (etaMinutes != null) 'etaMinutes': etaMinutes},
          fallbackError: 'Failed to acknowledge alert');

  /// Pass the alert on to the other notified hospitals
  Future<ApiResponse> declineReceiverAlert(String alertId, {String? reason}) =>
      _request('POST',
          '/api/receiver/alerts/${Uri.encodeComponent(alertId)}/decline',
          auth: true,
          body: {if (reason != null && reason.isNotEmpty) 'reason': reason},
          fallbackError: 'Failed to decline alert');

  /// The facility the signed-in staff member works for
  Future<ApiResponse> getReceiverProfile() =>
      _request('GET', '/api/receiver/profile',
          auth: true, fallbackError: 'Failed to fetch receiver profile');

  // ==================== RECORDS (PATIENTS / VITALS / REPORTS) ====================

  /// List patients for the logged-in user
  Future<ApiResponse> getPatients() => _request('GET', '/api/records/patients',
      auth: true, fallbackError: 'Failed to fetch patients');

  /// Create a patient record
  Future<ApiResponse> createPatient({
    required String name,
    required int age,
    required String bloodType,
    required String condition,
    required String admissionDate,
    required String roomNumber,
  }) =>
      _request('POST', '/api/records/patients',
          auth: true,
          body: {
            'name': name,
            'age': age,
            'bloodType': bloodType,
            'condition': condition,
            'admissionDate': admissionDate,
            'roomNumber': roomNumber,
          },
          expectStatus: 201,
          fallbackError: 'Failed to create patient');

  /// Update a patient record
  Future<ApiResponse> updatePatient(
    String id, {
    required String name,
    required int age,
    required String bloodType,
    required String condition,
    required String admissionDate,
    required String roomNumber,
  }) =>
      _request('PUT', '/api/records/patients/${Uri.encodeComponent(id)}',
          auth: true,
          body: {
            'name': name,
            'age': age,
            'bloodType': bloodType,
            'condition': condition,
            'admissionDate': admissionDate,
            'roomNumber': roomNumber,
          },
          fallbackError: 'Failed to update patient');

  /// Delete a patient record
  Future<ApiResponse> deletePatient(String id) => _request(
      'DELETE', '/api/records/patients/${Uri.encodeComponent(id)}',
      auth: true, fallbackError: 'Failed to delete patient');

  /// List vital readings for the logged-in user
  Future<ApiResponse> getVitals() => _request('GET', '/api/records/vitals',
      auth: true, fallbackError: 'Failed to fetch vitals');

  /// Add a vital reading
  Future<ApiResponse> createVital({
    required String patientId,
    required String patientName,
    required int heartRate,
    required String bloodPressure,
    required double temperature,
    required int oxygenLevel,
    String? timestamp,
  }) =>
      _request('POST', '/api/records/vitals',
          auth: true,
          body: {
            'patientId': patientId,
            'patientName': patientName,
            'heartRate': heartRate,
            'bloodPressure': bloodPressure,
            'temperature': temperature,
            'oxygenLevel': oxygenLevel,
            if (timestamp != null) 'timestamp': timestamp,
          },
          expectStatus: 201,
          fallbackError: 'Failed to add vital reading');

  /// Delete a vital reading
  Future<ApiResponse> deleteVital(String id) => _request(
      'DELETE', '/api/records/vitals/${Uri.encodeComponent(id)}',
      auth: true, fallbackError: 'Failed to delete vital');

  /// List medical reports for the logged-in user
  Future<ApiResponse> getReports() => _request('GET', '/api/records/reports',
      auth: true, fallbackError: 'Failed to fetch reports');

  /// Create a medical report
  Future<ApiResponse> createReport({
    required String patientName,
    required String reportType,
    required String date,
    required String summary,
    required String doctor,
  }) =>
      _request('POST', '/api/records/reports',
          auth: true,
          body: {
            'patientName': patientName,
            'reportType': reportType,
            'date': date,
            'summary': summary,
            'doctor': doctor,
          },
          expectStatus: 201,
          fallbackError: 'Failed to create report');

  /// Delete a medical report
  Future<ApiResponse> deleteReport(String id) => _request(
      'DELETE', '/api/records/reports/${Uri.encodeComponent(id)}',
      auth: true, fallbackError: 'Failed to delete report');
}

/// API Response wrapper
class ApiResponse {
  final bool success;
  final dynamic data;
  final String? error;

  /// True when the server could not be reached at all (as opposed to the
  /// server answering with an error).
  final bool isNetworkError;

  ApiResponse._({
    required this.success,
    this.data,
    this.error,
    this.isNetworkError = false,
  });

  factory ApiResponse.success(dynamic data) {
    return ApiResponse._(success: true, data: data);
  }

  factory ApiResponse.error(String error, {dynamic data}) {
    return ApiResponse._(success: false, error: error, data: data);
  }

  factory ApiResponse.networkError(String detail) {
    return ApiResponse._(
      success: false,
      error: 'Network error: $detail',
      isNetworkError: true,
    );
  }
}
