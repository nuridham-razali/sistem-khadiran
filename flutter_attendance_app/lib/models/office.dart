class Office {
  final String officeId;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final double maxAccuracyMeters;
  final int maxAgeSeconds;
  final String address;
  final bool active;

  Office({
    required this.officeId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.maxAccuracyMeters = 50.0,
    this.maxAgeSeconds = 60,
    this.address = '',
    this.active = true,
  });

  factory Office.fromJson(Map<String, dynamic> json) {
    return Office(
      officeId: json['officeId'] ?? json['OfficeID'] ?? '',
      name: json['name'] ?? json['Name'] ?? 'Office',
      latitude: (json['latitude'] ?? json['Latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? json['Longitude'] ?? 0.0).toDouble(),
      radiusMeters: (json['radiusMeters'] ?? json['RadiusMeters'] ?? 100.0).toDouble(),
      maxAccuracyMeters: (json['maxAccuracyMeters'] ?? json['MaxAccuracyMeters'] ?? 50.0).toDouble(),
      maxAgeSeconds: (json['maxAgeSeconds'] ?? json['MaxAgeSeconds'] ?? 60).toInt(),
      address: json['address'] ?? json['Address'] ?? '',
      active: (json['active'] ?? json['Active'] ?? true).toString().toLowerCase() != 'false',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'officeId': officeId,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'maxAccuracyMeters': maxAccuracyMeters,
      'maxAgeSeconds': maxAgeSeconds,
      'address': address,
      'active': active,
    };
  }
}
