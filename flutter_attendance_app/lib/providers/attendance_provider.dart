import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/office.dart';
import '../models/attendance_record.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

enum GeofenceStatus {
  determining,
  inside,
  outside,
  gpsDisabled,
  permissionDenied,
  error,
}

class AttendanceProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  final LocationService _locationService = LocationService();

  Office? _assignedOffice;
  AttendanceRecord? _openSession;
  List<AttendanceRecord> _todayRecords = [];
  List<AttendanceRecord> _historyRecords = [];
  String _statusSummary = 'NOT_CLOCKED_IN';

  Position? _currentPosition;
  double _distanceToOfficeMeters = 0.0;
  GeofenceStatus _geofenceStatus = GeofenceStatus.determining;
  String? _locationErrorMessage;
  bool _isLoading = false;
  bool _isActionSubmitting = false;

  Office? get assignedOffice => _assignedOffice;
  AttendanceRecord? get openSession => _openSession;
  List<AttendanceRecord> get todayRecords => _todayRecords;
  List<AttendanceRecord> get historyRecords => _historyRecords;
  String get statusSummary => _statusSummary;
  Position? get currentPosition => _currentPosition;
  double get distanceToOfficeMeters => _distanceToOfficeMeters;
  GeofenceStatus get geofenceStatus => _geofenceStatus;
  String? get locationErrorMessage => _locationErrorMessage;
  bool get isLoading => _isLoading;
  bool get isActionSubmitting => _isActionSubmitting;

  bool get isInsideAttendanceArea => _geofenceStatus == GeofenceStatus.inside;
  bool get canClockIn => _openSession == null && isInsideAttendanceArea && !_isActionSubmitting;
  bool get canClockOut => _openSession != null && isInsideAttendanceArea && !_isActionSubmitting;

  /// Loads dashboard status from backend
  Future<void> refreshDashboard() async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _api.getDashboardStatus();
      _assignedOffice = res['assignedOffice'] as Office?;
      _openSession = res['openSession'] as AttendanceRecord?;
      _todayRecords = (res['todayRecords'] as List<AttendanceRecord>?) ?? [];
      _statusSummary = res['statusSummary'] as String? ?? 'NOT_CLOCKED_IN';

      // Update location and geofence
      await checkCurrentLocation();
    } catch (e) {
      debugPrint('Error refreshing dashboard: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refreshes current GPS position and evaluates Haversine distance to office
  Future<void> checkCurrentLocation() async {
    final result = await _locationService.getCurrentLocation();

    if (!result.isSuccess) {
      if (result.isServiceDisabled) {
        _geofenceStatus = GeofenceStatus.gpsDisabled;
      } else if (result.isPermissionDenied) {
        _geofenceStatus = GeofenceStatus.permissionDenied;
      } else {
        _geofenceStatus = GeofenceStatus.error;
      }
      _locationErrorMessage = result.errorMessage;
      notifyListeners();
      return;
    }

    _currentPosition = result.position;
    _locationErrorMessage = null;

    if (_assignedOffice != null && _currentPosition != null) {
      _distanceToOfficeMeters = _locationService.calculateDistanceMeters(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _assignedOffice!.latitude,
        _assignedOffice!.longitude,
      );

      if (_distanceToOfficeMeters <= _assignedOffice!.radiusMeters) {
        _geofenceStatus = GeofenceStatus.inside;
      } else {
        _geofenceStatus = GeofenceStatus.outside;
      }
    } else {
      _geofenceStatus = GeofenceStatus.determining;
    }

    notifyListeners();
  }

  /// Clocks In with current location
  Future<Map<String, dynamic>> performClockIn({String? notes}) async {
    if (_currentPosition == null) {
      await checkCurrentLocation();
    }
    if (_currentPosition == null || !isInsideAttendanceArea) {
      return {'success': false, 'message': 'You must be inside your assigned office radius to clock in.'};
    }

    _isActionSubmitting = true;
    notifyListeners();

    try {
      final session = await _api.clockIn(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        accuracy: _currentPosition!.accuracy,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        isMockLocation: _currentPosition!.isMocked,
        notes: notes,
      );

      _openSession = session;
      _statusSummary = 'IN_PROGRESS';
      _isActionSubmitting = false;
      notifyListeners();
      return {'success': true, 'session': session};
    } catch (e) {
      _isActionSubmitting = false;
      notifyListeners();
      return {'success': false, 'message': e.toString().replaceAll('Exception: ', '')};
    }
  }

  /// Clocks Out after biometric face verification
  Future<Map<String, dynamic>> performClockOut({
    required String challengeId,
    required List<double> probeVector,
    required String completedLivenessAction,
    String? notes,
  }) async {
    if (_currentPosition == null) {
      await checkCurrentLocation();
    }
    if (_currentPosition == null || !isInsideAttendanceArea) {
      return {'success': false, 'message': 'You must be inside your assigned office radius to clock out.'};
    }

    _isActionSubmitting = true;
    notifyListeners();

    try {
      final session = await _api.clockOut(
        challengeId: challengeId,
        probeVector: probeVector,
        completedLivenessAction: completedLivenessAction,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        accuracy: _currentPosition!.accuracy,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        isMockLocation: _currentPosition!.isMocked,
        notes: notes,
      );

      _openSession = null;
      _statusSummary = 'COMPLETED';
      _todayRecords.insert(0, session);
      _isActionSubmitting = false;
      notifyListeners();
      return {'success': true, 'session': session};
    } catch (e) {
      _isActionSubmitting = false;
      notifyListeners();
      return {'success': false, 'message': e.toString().replaceAll('Exception: ', '')};
    }
  }

  Future<void> loadMyHistory() async {
    _isLoading = true;
    notifyListeners();
    try {
      _historyRecords = await _api.getMyHistory();
    } catch (e) {
      debugPrint('Error loading history: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
