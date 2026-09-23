import 'dart:convert';
import 'package:http/http.dart' as http;

/// API Service for CardioAid Backend
/// Handles all communication with the Node.js backend server
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Base URL - change to your deployed server URL in production
  static const String baseUrl =
      'http://10.0.2.2:3000'; // Android emulator localhost
  // static const String baseUrl = 'http://localhost:3000'; // iOS simulator / web
  // static const String baseUrl = 'http://192.168.x.x:3000'; // For physical device

  String? _authToken;
  String? _userId;

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
  Future<ApiResponse> getProfile() async {
    try {
      final response =
          await http.get(Uri.parse('$baseUrl/api/auth/me'), headers: _headers(auth: true));
      final data = _tryDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse.success(data);
      }
      return ApiResponse.error(data?['error'] ?? 'Failed to fetch profile');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  dynamic _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  // ==================== AUTH ENDPOINTS ====================

  /// Register a new user
  Future<ApiResponse> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: _headers(),
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
        }),
      );

      final data = _tryDecode(response.body);

      if (response.statusCode == 201) {
        _authToken = data['token'];
        _userId = data['user']['id'];
        return ApiResponse.success(data);
      }

      return ApiResponse.error(data['error'] ?? 'Registration failed');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Login user
  Future<ApiResponse> login({
    required String email,
    required String password,
    String? fcmToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: _headers(),
        body: jsonEncode({
          'email': email,
          'password': password,
          if (fcmToken != null) 'fcmToken': fcmToken,
        }),
      );

      final data = _tryDecode(response.body);

      if (response.statusCode == 200) {
        _authToken = data['token'];
        _userId = data['user']['id'];
        return ApiResponse.success(data);
      }

      return ApiResponse.error(data['error'] ?? 'Login failed');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Update user's current location
  Future<ApiResponse> updateLocation({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/location'),
        headers: _headers(auth: true),
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
        }),
      );

      final data = _tryDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse.success(data);
      }

      return ApiResponse.error(data['error'] ?? 'Failed to update location');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Update FCM token
  Future<ApiResponse> updateFcmToken(String fcmToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/fcm-token'),
        headers: _headers(auth: true),
        body: jsonEncode({'fcmToken': fcmToken}),
      );

      final data = _tryDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse.success(data);
      }

      return ApiResponse.error(data['error'] ?? 'Failed to update FCM token');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  // ==================== HOSPITAL ENDPOINTS ====================

  /// Get nearby hospitals
  Future<ApiResponse> getNearbyHospitals({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    int limit = 10,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/hospitals/nearby').replace(
        queryParameters: {
          'lat': latitude.toString(),
          'lng': longitude.toString(),
          'radius': radiusKm.toString(),
          'limit': limit.toString(),
        },
      );

      final response = await http.get(uri, headers: _headers());

      final data = _tryDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse.success(data);
      }

      return ApiResponse.error(data['error'] ?? 'Failed to fetch hospitals');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  // ==================== PAYMENT ENDPOINTS ====================

  /// Create a payment order for emergency alert
  Future<ApiResponse> createPaymentOrder({
    required int tier, // 1, 2, or 3
    required double latitude,
    required double longitude,
    String? symptoms,
    String? message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/payments/create-order'),
        headers: _headers(auth: true),
        body: jsonEncode({
          'tier': tier,
          'latitude': latitude,
          'longitude': longitude,
          if (symptoms != null) 'symptoms': symptoms,
          if (message != null) 'message': message,
        }),
      );

      final data = _tryDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse.success(data);
      }

      return ApiResponse.error(data['error'] ?? 'Failed to create order');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Verify payment after Razorpay callback
  Future<ApiResponse> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
    required String alertId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/payments/verify'),
        headers: _headers(auth: true),
        body: jsonEncode({
          'orderId': orderId,
          'paymentId': paymentId,
          'signature': signature,
          'alertId': alertId,
        }),
      );

      final data = _tryDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse.success(data);
      }

      return ApiResponse.error(data['error'] ?? 'Payment verification failed');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  // ==================== ALERT ENDPOINTS ====================

  /// Send emergency alert (after payment is verified)
  Future<ApiResponse> sendEmergencyAlert(String alertId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/alerts/send'),
        headers: _headers(auth: true),
        body: jsonEncode({'alertId': alertId}),
      );

      final data = _tryDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse.success(data);
      }

      return ApiResponse.error(data['error'] ?? 'Failed to send alert');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Get alert history
  Future<ApiResponse> getAlertHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/alerts/history'),
        headers: _headers(auth: true),
      );

      final data = _tryDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse.success(data);
      }

      return ApiResponse.error(data['error'] ?? 'Failed to fetch alerts');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Get single alert details
  Future<ApiResponse> getAlertDetails(String alertId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/alerts/$alertId'),
        headers: _headers(auth: true),
      );

      final data = _tryDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse.success(data);
      }

      return ApiResponse.error(data['error'] ?? 'Failed to fetch alert');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  // ==================== RECORDS (PATIENTS / VITALS / REPORTS) ====================

  /// List patients for the logged-in user
  Future<ApiResponse> getPatients() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/records/patients'),
        headers: _headers(auth: true),
      );
      final data = _tryDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse.success(data);
      }
      return ApiResponse.error(data['error'] ?? 'Failed to fetch patients');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Create a patient record
  Future<ApiResponse> createPatient({
    required String name,
    required int age,
    required String bloodType,
    required String condition,
    required String admissionDate,
    required String roomNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/records/patients'),
        headers: _headers(auth: true),
        body: jsonEncode({
          'name': name,
          'age': age,
          'bloodType': bloodType,
          'condition': condition,
          'admissionDate': admissionDate,
          'roomNumber': roomNumber,
        }),
      );
      final data = _tryDecode(response.body);
      if (response.statusCode == 201) {
        return ApiResponse.success(data);
      }
      return ApiResponse.error(data['error'] ?? 'Failed to create patient');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Update a patient record
  Future<ApiResponse> updatePatient(
    String id, {
    required String name,
    required int age,
    required String bloodType,
    required String condition,
    required String admissionDate,
    required String roomNumber,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/records/patients/$id'),
        headers: _headers(auth: true),
        body: jsonEncode({
          'name': name,
          'age': age,
          'bloodType': bloodType,
          'condition': condition,
          'admissionDate': admissionDate,
          'roomNumber': roomNumber,
        }),
      );
      final data = _tryDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse.success(data);
      }
      return ApiResponse.error(data['error'] ?? 'Failed to update patient');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Delete a patient record
  Future<ApiResponse> deletePatient(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/records/patients/$id'),
        headers: _headers(auth: true),
      );
      final data = _tryDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse.success(data);
      }
      return ApiResponse.error(data['error'] ?? 'Failed to delete patient');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// List vital readings for the logged-in user
  Future<ApiResponse> getVitals() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/records/vitals'),
        headers: _headers(auth: true),
      );
      final data = _tryDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse.success(data);
      }
      return ApiResponse.error(data['error'] ?? 'Failed to fetch vitals');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Add a vital reading
  Future<ApiResponse> createVital({
    required String patientId,
    required String patientName,
    required int heartRate,
    required String bloodPressure,
    required double temperature,
    required int oxygenLevel,
    String? timestamp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/records/vitals'),
        headers: _headers(auth: true),
        body: jsonEncode({
          'patientId': patientId,
          'patientName': patientName,
          'heartRate': heartRate,
          'bloodPressure': bloodPressure,
          'temperature': temperature,
          'oxygenLevel': oxygenLevel,
          if (timestamp != null) 'timestamp': timestamp,
        }),
      );
      final data = _tryDecode(response.body);
      if (response.statusCode == 201) {
        return ApiResponse.success(data);
      }
      return ApiResponse.error(data['error'] ?? 'Failed to add vital reading');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Delete a vital reading
  Future<ApiResponse> deleteVital(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/records/vitals/$id'),
        headers: _headers(auth: true),
      );
      final data = _tryDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse.success(data);
      }
      return ApiResponse.error(data['error'] ?? 'Failed to delete vital');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// List medical reports for the logged-in user
  Future<ApiResponse> getReports() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/records/reports'),
        headers: _headers(auth: true),
      );
      final data = _tryDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse.success(data);
      }
      return ApiResponse.error(data['error'] ?? 'Failed to fetch reports');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Create a medical report
  Future<ApiResponse> createReport({
    required String patientName,
    required String reportType,
    required String date,
    required String summary,
    required String doctor,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/records/reports'),
        headers: _headers(auth: true),
        body: jsonEncode({
          'patientName': patientName,
          'reportType': reportType,
          'date': date,
          'summary': summary,
          'doctor': doctor,
        }),
      );
      final data = _tryDecode(response.body);
      if (response.statusCode == 201) {
        return ApiResponse.success(data);
      }
      return ApiResponse.error(data['error'] ?? 'Failed to create report');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Delete a medical report
  Future<ApiResponse> deleteReport(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/records/reports/$id'),
        headers: _headers(auth: true),
      );
      final data = _tryDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse.success(data);
      }
      return ApiResponse.error(data['error'] ?? 'Failed to delete report');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }
}

/// API Response wrapper
class ApiResponse {
  final bool success;
  final dynamic data;
  final String? error;

  ApiResponse._({
    required this.success,
    this.data,
    this.error,
  });

  factory ApiResponse.success(dynamic data) {
    return ApiResponse._(success: true, data: data);
  }

  factory ApiResponse.error(String error) {
    return ApiResponse._(success: false, error: error);
  }
}
