import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as ll;

import '../config/google_maps_config.dart';

class GoogleRouteSnapshot {
  const GoogleRouteSnapshot({
    required this.points,
    required this.distanceText,
    required this.durationText,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.bounds,
    this.isFallback = false,
  });

  final List<gmap.LatLng> points;
  final String distanceText;
  final String durationText;
  final int distanceMeters;
  final int durationSeconds;
  final gmap.LatLngBounds bounds;
  final bool isFallback;
}

class GoogleMapsService {
  static final ll.Distance _distance = ll.Distance();

  Future<String> loadMapStyle() async {
    return rootBundle.loadString('assets/map_style.json');
  }

  Future<GoogleRouteSnapshot> fetchDrivingRoute({
    required ll.LatLng origin,
    required ll.LatLng destination,
  }) async {
    final fallback = _fallbackRoute(origin: origin, destination: destination);
    final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'mode': 'driving',
      'key': GoogleMapsConfig.apiKey,
    });

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        return fallback;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if ((decoded['status'] as String?) != 'OK') {
        return fallback;
      }

      final routes = decoded['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        return fallback;
      }

      final route = routes.first as Map<String, dynamic>;
      final overview =
          route['overview_polyline'] as Map<String, dynamic>? ?? const {};
      final encoded = overview['points'] as String?;
      final legs = route['legs'] as List<dynamic>?;
      final leg = legs != null && legs.isNotEmpty
          ? legs.first as Map<String, dynamic>
          : const <String, dynamic>{};

      final distanceMap = leg['distance'] as Map<String, dynamic>? ?? const {};
      final durationMap = leg['duration'] as Map<String, dynamic>? ?? const {};

      final polylinePoints = encoded != null && encoded.isNotEmpty
          ? _decodePolyline(encoded)
          : fallback.points;
      final bounds = polylinePoints.isNotEmpty
          ? _boundsForPoints(polylinePoints)
          : fallback.bounds;

      return GoogleRouteSnapshot(
        points: polylinePoints,
        distanceText: distanceMap['text'] as String? ?? fallback.distanceText,
        durationText: durationMap['text'] as String? ?? fallback.durationText,
        distanceMeters:
            (distanceMap['value'] as num?)?.round() ?? fallback.distanceMeters,
        durationSeconds:
            (durationMap['value'] as num?)?.round() ?? fallback.durationSeconds,
        bounds: bounds,
      );
    } catch (_) {
      return fallback;
    }
  }

  GoogleRouteSnapshot _fallbackRoute({
    required ll.LatLng origin,
    required ll.LatLng destination,
  }) {
    final distanceMeters = _distance(origin, destination).round();
    final durationSeconds = ((distanceMeters / 1000) / 28 * 3600).round();
    final originPoint = gmap.LatLng(origin.latitude, origin.longitude);
    final destinationPoint = gmap.LatLng(
      destination.latitude,
      destination.longitude,
    );
    final points = [originPoint, destinationPoint];

    return GoogleRouteSnapshot(
      points: points,
      distanceText: _formatDistance(distanceMeters),
      durationText: _formatDuration(durationSeconds),
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      bounds: _boundsForPoints(points),
      isFallback: true,
    );
  }

  List<gmap.LatLng> _decodePolyline(String encoded) {
    final points = <gmap.LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      final deltaLat = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      lat += deltaLat;

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      final deltaLng = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      lng += deltaLng;

      points.add(gmap.LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }

  gmap.LatLngBounds _boundsForPoints(List<gmap.LatLng> points) {
    final latitudes = points.map((point) => point.latitude);
    final longitudes = points.map((point) => point.longitude);

    return gmap.LatLngBounds(
      southwest: gmap.LatLng(
        latitudes.reduce((a, b) => a < b ? a : b),
        longitudes.reduce((a, b) => a < b ? a : b),
      ),
      northeast: gmap.LatLng(
        latitudes.reduce((a, b) => a > b ? a : b),
        longitudes.reduce((a, b) => a > b ? a : b),
      ),
    );
  }

  String _formatDistance(int meters) {
    if (meters < 1000) {
      return '$meters m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '1 min';
    }
    if (seconds < 3600) {
      return '${(seconds / 60).ceil()} min';
    }
    return '${(seconds / 3600).toStringAsFixed(1)} hr';
  }
}
