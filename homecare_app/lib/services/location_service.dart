import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  StreamSubscription<Position>? _positionStream;

  // Check and request location permissions
  Future<bool> checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  // Get current position
  Future<Position?> getCurrentPosition() async {
    try {
      bool hasPermission = await checkPermissions();
      if (!hasPermission) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  // Get current position as LatLng
  Future<LatLng?> getCurrentLatLng() async {
    Position? position = await getCurrentPosition();
    if (position != null) {
      return LatLng(position.latitude, position.longitude);
    }
    return null;
  }

  // Get current position as GeoPoint (for Firestore)
  Future<GeoPoint?> getCurrentGeoPoint() async {
    Position? position = await getCurrentPosition();
    if (position != null) {
      return GeoPoint(position.latitude, position.longitude);
    }
    return null;
  }

  // Start continuous location tracking
  void startTracking({
    required Function(Position position) onLocationUpdate,
    int distanceFilter = 10,
  }) {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      ),
    ).listen(onLocationUpdate);
  }

  // Stop tracking
  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  // Calculate distance between two points (in meters)
  double calculateDistance(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  // Calculate distance in km
  String getDistanceString(LatLng from, LatLng to) {
    double distanceInMeters = calculateDistance(from, to);
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)} m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    }
  }

  // Estimate arrival time (assuming 30 km/h average speed)
  String estimateArrivalTime(LatLng from, LatLng to) {
    double distanceInMeters = calculateDistance(from, to);
    double speedMps = 30 * 1000 / 3600; // 30 km/h in m/s
    double timeInSeconds = distanceInMeters / speedMps;
    
    if (timeInSeconds < 60) {
      return '1 min';
    } else if (timeInSeconds < 3600) {
      return '${(timeInSeconds / 60).ceil()} min';
    } else {
      return '${(timeInSeconds / 3600).toStringAsFixed(1)} hr';
    }
  }

  // Convert GeoPoint to LatLng
  static LatLng geoPointToLatLng(GeoPoint geoPoint) {
    return LatLng(geoPoint.latitude, geoPoint.longitude);
  }

  // Convert LatLng to GeoPoint
  static GeoPoint latLngToGeoPoint(LatLng latLng) {
    return GeoPoint(latLng.latitude, latLng.longitude);
  }

  void dispose() {
    stopTracking();
  }
}
