import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../services/firestore_service.dart';

class LocationProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  final FirestoreService _firestoreService = FirestoreService();

  LatLng? _currentLocation;
  bool _isTracking = false;
  bool _hasPermission = false;

  LatLng? get currentLocation => _currentLocation;
  bool get isTracking => _isTracking;
  bool get hasPermission => _hasPermission;

  // Initialize location
  Future<void> initialize() async {
    _hasPermission = await _locationService.checkPermissions();
    if (_hasPermission) {
      _currentLocation = await _locationService.getCurrentLatLng();
      notifyListeners();
    }
  }

  // Start tracking for nurses
  void startTracking(String nurseId) {
    if (_isTracking) return;
    _isTracking = true;
    
    _locationService.startTracking(
      onLocationUpdate: (Position position) {
        _currentLocation = LatLng(position.latitude, position.longitude);
        // Update nurse location in Firestore
        _firestoreService.updateNurseLocation(
          nurseId,
          LocationService.latLngToGeoPoint(_currentLocation!),
        );
        notifyListeners();
      },
    );
    notifyListeners();
  }

  // Stop tracking
  void stopTracking() {
    _locationService.stopTracking();
    _isTracking = false;
    notifyListeners();
  }

  // Get distance to a point
  String getDistanceTo(LatLng target) {
    if (_currentLocation == null) return 'N/A';
    return _locationService.getDistanceString(_currentLocation!, target);
  }

  // Get ETA to a point
  String getETATo(LatLng target) {
    if (_currentLocation == null) return 'N/A';
    return _locationService.estimateArrivalTime(_currentLocation!, target);
  }

  @override
  void dispose() {
    _locationService.dispose();
    super.dispose();
  }
}
