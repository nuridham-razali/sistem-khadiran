import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';
import '../models/office.dart';
import '../models/attendance_record.dart';
import '../models/verification_challenge.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Dynamic host detection: 10.0.2.2 for Android Emulator, localhost for Web/iOS
  String _baseUrl = kIsWeb
      ? 'http://localhost:4000/api'
      : (defaultTargetPlatform == TargetPlatform.android
          ? 'http://10.0.2.2:4000/api'
          : 'http://localhost:4000/api');

  String? _authToken;
  final Uuid _uuid = const Uuid();

  String get baseUrl => _baseUrl;
  bool get isAuthenticated => _authToken != null;

  void setBaseUrl(String newUrl) {
    _baseUrl = newUrl;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
    final savedUrl = prefs.getString('custom_base_url');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _baseUrl = savedUrl;
    }
  }

  Future<void> setAuthToken(String? token) async {
    _authToken = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString('auth_token', token);
    } else {
      await prefs.remove('auth_token');
    }
  }

  Map<String, String> _headers({bool includeIdempotency = false}) {
    final map = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null) {
      map['Authorization'] = 'Bearer $_authToken';
    }
    if (includeIdempotency) {
      map['X-Idempotency-Key'] = _uuid.v4();
    }
    return map;
  }

  // ==========================================
  // AUTH
  // ==========================================

  Future<Map<String, dynamic>> login(String identifier, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: _headers(),
      body: jsonEncode({'identifier': identifier, 'password': password}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      await setAuthToken(data['token']);
      return {
        'success': true,
        'user': User.fromJson(data['user']),
        'token': data['token'],
      };
    } else {
      throw Exception(data['message'] ?? 'Authentication failed');
    }
  }

  Future<void> logout() async {
    await setAuthToken(null);
  }

  // ==========================================
  // EMPLOYEE ATTENDANCE
  // ==========================================

  Future<Map<String, dynamic>> getDashboardStatus() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/attendance/status'),
      headers: _headers(),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return {
        'serverTimeUTC': data['serverTimeUTC'],
        'serverTimeKL': data['serverTimeKL'],
        'employee': data['employee'],
        'assignedOffice': data['assignedOffice'] != null ? Office.fromJson(data['assignedOffice']) : null,
        'openSession': data['openSession'] != null ? AttendanceRecord.fromJson(data['openSession']) : null,
        'todayRecords': (data['todayRecords'] as List?)?.map((r) => AttendanceRecord.fromJson(r)).toList() ?? [],
        'statusSummary': data['statusSummary'] ?? 'NOT_CLOCKED_IN',
      };
    } else {
      throw Exception(data['message'] ?? 'Failed fetching dashboard status');
    }
  }

  Future<AttendanceRecord> clockIn({
    required double latitude,
    required double longitude,
    required double accuracy,
    required int timestamp,
    bool isMockLocation = false,
    String? notes,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/attendance/clock-in'),
      headers: _headers(includeIdempotency: true),
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'timestamp': timestamp,
        'isMockLocation': isMockLocation,
        'notes': notes,
      }),
    );

    final data = jsonDecode(response.body);
    if ((response.statusCode == 200 || response.statusCode == 201) && data['success'] == true) {
      return AttendanceRecord.fromJson(data['session']);
    } else {
      throw Exception(data['message'] ?? 'Failed to clock in');
    }
  }

  Future<VerificationChallenge> requestClockOutChallenge() async {
    final response = await http.post(
      Uri.parse('$_baseUrl/attendance/clock-out-challenge'),
      headers: _headers(),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return VerificationChallenge.fromJson(data['challenge']);
    } else {
      throw Exception(data['message'] ?? 'Failed requesting clock-out challenge');
    }
  }

  Future<AttendanceRecord> clockOut({
    required String challengeId,
    required List<double> probeVector,
    required String completedLivenessAction,
    required double latitude,
    required double longitude,
    required double accuracy,
    required int timestamp,
    bool isMockLocation = false,
    String? notes,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/attendance/clock-out'),
      headers: _headers(includeIdempotency: true),
      body: jsonEncode({
        'challengeId': challengeId,
        'probeVector': probeVector,
        'completedLivenessAction': completedLivenessAction,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'timestamp': timestamp,
        'isMockLocation': isMockLocation,
        'notes': notes,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return AttendanceRecord.fromJson(data['session']);
    } else {
      throw Exception(data['message'] ?? 'Clock-out verification failed');
    }
  }

  Future<List<AttendanceRecord>> getMyHistory() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/attendance/my-history'),
      headers: _headers(),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      final list = (data['records'] as List?) ?? [];
      return list.map((r) => AttendanceRecord.fromJson(r)).toList();
    } else {
      throw Exception(data['message'] ?? 'Failed loading attendance history');
    }
  }

  // ==========================================
  // BIOMETRICS
  // ==========================================

  Future<void> enrollFace({
    required List<double> faceVector,
    required String consentText,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/biometrics/enroll'),
      headers: _headers(),
      body: jsonEncode({
        'faceVector': faceVector,
        'consentText': consentText,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(data['message'] ?? 'Face enrolment failed');
    }
  }

  // ==========================================
  // ADMIN DASHBOARD
  // ==========================================

  Future<Map<String, dynamic>> getAdminMetrics() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/admin/metrics'),
      headers: _headers(),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['metrics'];
    } else {
      throw Exception(data['message'] ?? 'Failed fetching admin metrics');
    }
  }

  Future<List<AttendanceRecord>> getAllAttendance({
    String? employeeId,
    String? department,
    String? officeId,
    String? startDate,
    String? endDate,
    String? status,
    String? search,
  }) async {
    final queryParams = <String, String>{};
    if (employeeId != null) queryParams['employeeId'] = employeeId;
    if (department != null) queryParams['department'] = department;
    if (officeId != null) queryParams['officeId'] = officeId;
    if (startDate != null) queryParams['startDate'] = startDate;
    if (endDate != null) queryParams['endDate'] = endDate;
    if (status != null) queryParams['status'] = status;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final uri = Uri.parse('$_baseUrl/admin/attendance').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _headers());

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      final list = (data['records'] as List?) ?? [];
      return list.map((r) => AttendanceRecord.fromJson(r)).toList();
    } else {
      throw Exception(data['message'] ?? 'Failed fetching attendance records');
    }
  }

  Future<void> correctAttendance({
    required String sessionId,
    String? clockInTimeKL,
    String? clockOutTimeKL,
    String? attendanceStatus,
    int? workedMinutes,
    required String reason,
  }) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/admin/attendance/$sessionId/correct'),
      headers: _headers(),
      body: jsonEncode({
        'clockInTimeKL': clockInTimeKL,
        'clockOutTimeKL': clockOutTimeKL,
        'attendanceStatus': attendanceStatus,
        'workedMinutes': workedMinutes,
        'reason': reason,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed correcting attendance record');
    }
  }

  Future<List<Office>> getOffices() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/admin/offices'),
      headers: _headers(),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      final list = (data['offices'] as List?) ?? [];
      return list.map((o) => Office.fromJson(o)).toList();
    } else {
      throw Exception(data['message'] ?? 'Failed loading offices');
    }
  }

  Future<void> createOffice(Office office) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/offices'),
      headers: _headers(),
      body: jsonEncode(office.toJson()),
    );

    if (response.statusCode != 201) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed creating office');
    }
  }

  Future<List<User>> getEmployees() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/admin/employees'),
      headers: _headers(),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      final list = (data['employees'] as List?) ?? [];
      return list.map((e) => User.fromJson(e)).toList();
    } else {
      throw Exception(data['message'] ?? 'Failed loading employees');
    }
  }

  Future<Map<String, dynamic>> getPayrollPreview({String? startDate, String? endDate}) async {
    final queryParams = <String, String>{};
    if (startDate != null) queryParams['startDate'] = startDate;
    if (endDate != null) queryParams['endDate'] = endDate;

    final uri = Uri.parse('$_baseUrl/admin/payroll/preview').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _headers());

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed loading payroll preview');
    }
  }

  String getPayrollCsvUrl({String? startDate, String? endDate}) {
    final query = <String>[];
    if (startDate != null) query.add('startDate=$startDate');
    if (endDate != null) query.add('endDate=$endDate');
    return '$_baseUrl/admin/payroll/export.csv?${query.join('&')}';
  }
}
