import 'dart:math';
import 'package:geolocator/geolocator.dart';

class LocationResult {
  final bool isSuccess;
  final Position? position;
  final String? errorMessage;
  final bool isPermissionDenied;
  final bool isServiceDisabled;

  LocationResult({
    required this.isSuccess,
    this.position,
    this.errorMessage,
    this.isPermissionDenied = false,
    this.isServiceDisabled = false,
  });
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// Requests permission and fetches fresh GPS location on-demand.
  /// Does not run background tracking.
  Future<LocationResult> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Check if GPS service is enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationResult(
        isSuccess: false,
        isServiceDisabled: true,
        errorMessage: 'Location services (GPS) are disabled on your device. Please enable GPS to verify office attendance.',
      );
    }

    // 2. Check and request permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationResult(
          isSuccess: false,
          isPermissionDenied: true,
          errorMessage: 'Location permission was denied. GeoAttend requires your location only while clocking in/out to verify you are at the office.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationResult(
        isSuccess: false,
        isPermissionDenied: true,
        errorMessage: 'Location permissions are permanently denied. Please enable them in device App Settings to check in.',
      );
    }

    // 3. Acquire fresh position with high accuracy
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      return LocationResult(isSuccess: true, position: position);
    } catch (e) {
      // Fallback: try last known if available and recent
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          final ageSeconds = DateTime.now().difference(last.timestamp).inSeconds;
          if (ageSeconds < 60) {
            return LocationResult(isSuccess: true, position: last);
          }
        }
      } catch (_) {}

      return LocationResult(
        isSuccess: false,
        errorMessage: 'Could not obtain a fresh GPS fix (${e.toString()}). Ensure you are not in a basement or tunnel.',
      );
    }
  }

  /// Calculates Haversine distance in metres between two points
  double calculateDistanceMeters(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    const double earthRadius = 6371000.0;
    final dLat = _degreesToRadians(endLatitude - startLatitude);
    final dLon = _degreesToRadians(endLongitude - startLongitude);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(startLatitude)) *
            cos(_degreesToRadians(endLatitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }
}
