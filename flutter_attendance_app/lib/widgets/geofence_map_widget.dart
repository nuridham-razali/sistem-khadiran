import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/office.dart';
import 'package:geolocator/geolocator.dart';

class GeofenceMapWidget extends StatelessWidget {
  final Office? office;
  final Position? userPosition;
  final bool isInside;
  final VoidCallback? onRefreshLocation;

  const GeofenceMapWidget({
    super.key,
    required this.office,
    required this.userPosition,
    required this.isInside,
    this.onRefreshLocation,
  });

  @override
  Widget build(BuildContext context) {
    if (office == null) {
      return Container(
        height: 240,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('No office location assigned'),
        ),
      );
    }

    final officeCenter = LatLng(office!.latitude, office!.longitude);
    final userCenter = userPosition != null
        ? LatLng(userPosition!.latitude, userPosition!.longitude)
        : null;

    final mapCenter = userCenter ?? officeCenter;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          SizedBox(
            height: 240,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: mapCenter,
                initialZoom: 16.5,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.geoattend.app',
                ),
                // Geofence Circle around Office
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: officeCenter,
                      color: isInside
                          ? Colors.green.withOpacity(0.2)
                          : Colors.blue.withOpacity(0.18),
                      borderColor: isInside ? Colors.green : Colors.blue,
                      borderStrokeWidth: 2,
                      useRadiusInMeter: true,
                      radius: office!.radiusMeters,
                    ),
                    if (userCenter != null && userPosition?.accuracy != null)
                      CircleMarker(
                        point: userCenter,
                        color: Colors.indigo.withOpacity(0.15),
                        borderColor: Colors.indigo.withOpacity(0.4),
                        borderStrokeWidth: 1,
                        useRadiusInMeter: true,
                        radius: userPosition!.accuracy,
                      ),
                  ],
                ),
                // Markers
                MarkerLayer(
                  markers: [
                    // Office Marker
                    Marker(
                      point: officeCenter,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.shade700,
                          shape: BoxShape.circle,
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: const Icon(Icons.business, color: Colors.white, size: 24),
                      ),
                    ),
                    // User Position Marker
                    if (userCenter != null)
                      Marker(
                        point: userCenter,
                        width: 44,
                        height: 44,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isInside ? Colors.green.shade600 : Colors.red.shade600,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                          ),
                          child: const Icon(Icons.person_pin_circle, color: Colors.white, size: 26),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Top badge overlay: Office Name & Radius
          Positioned(
            top: 12,
            left: 12,
            right: 56,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${office!.name} (Radius: ${office!.radiusMeters.toInt()}m)',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // Refresh button
          if (onRefreshLocation != null)
            Positioned(
              bottom: 12,
              right: 12,
              child: FloatingActionButton.small(
                heroTag: 'refresh_loc_btn',
                onPressed: onRefreshLocation,
                backgroundColor: Colors.white,
                child: const Icon(Icons.my_location, color: Colors.blueAccent),
              ),
            ),
        ],
      ),
    );
  }
}
