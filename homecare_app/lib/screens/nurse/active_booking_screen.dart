import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/map_platform.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/google_maps_service.dart';
import '../../services/location_service.dart';
import '../../widgets/healthcare_ui.dart';
import '../shared/chat_screen.dart';

class ActiveBookingScreen extends StatefulWidget {
  const ActiveBookingScreen({super.key});

  @override
  State<ActiveBookingScreen> createState() => _ActiveBookingScreenState();
}

class _ActiveBookingScreenState extends State<ActiveBookingScreen> {
  final _googleMapsService = GoogleMapsService();
  final _locationService = LocationService();

  final _desktopMapController = fmap.MapController();
  gmap.GoogleMapController? _mapController;
  GoogleRouteSnapshot? _route;
  String? _mapStyle;
  String? _cameraKey;
  ll.LatLng? _lastRouteOrigin;
  ll.LatLng? _lastRouteDestination;
  DateTime? _lastRouteRequestAt;
  bool _isRefreshingRoute = false;

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final bookingId = ModalRoute.of(context)?.settings.arguments as String?;
      if (bookingId != null) {
        context.read<BookingProvider>().listenToBooking(bookingId);
      }
      final auth = context.read<AuthProvider>();
      final nurseId = auth.user?.uid;
      if (nurseId != null) {
        final locationProvider = context.read<LocationProvider>();
        await locationProvider.initialize();
        if (auth.user?.isOnline == true) {
          await locationProvider.startTracking(nurseId);
        }
      }
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer2<BookingProvider, LocationProvider>(
        builder: (context, bookingProvider, locationProvider, _) {
          final booking = bookingProvider.activeBooking;
          if (booking == null) {
            return const HealthcareBackground(
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final patientLocation = ll.LatLng(
            booking.patientLocation.latitude,
            booking.patientLocation.longitude,
          );
          final nurseLocation =
              locationProvider.currentLocation ?? patientLocation;

          _maybeRefreshRoute(patientLocation, nurseLocation);
          _syncMapView(patientLocation, nurseLocation);

          final distanceText =
              _route?.distanceText ??
              locationProvider.getDistanceTo(patientLocation);
          final etaText =
              _route?.durationText ??
              locationProvider.getETATo(patientLocation);

          return SizedBox.expand(
            child: Stack(
              fit: StackFit.expand,
              children: [
              Positioned.fill(
                child: ColoredBox(
                  color: AppTheme.background,
                  child: AppMapPlatform.supportsGoogleMaps
                      ? gmap.GoogleMap(
                          initialCameraPosition: gmap.CameraPosition(
                            target: _googleLatLng(nurseLocation),
                            zoom: 14.8,
                          ),
                          onMapCreated: (controller) {
                            _mapController = controller;
                            final style = _mapStyle;
                            if (style != null) {
                              controller.setMapStyle(style);
                            }
                            _syncMapView(
                              patientLocation,
                              nurseLocation,
                              force: true,
                            );
                          },
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: false,
                          mapToolbarEnabled: false,
                          markers: _buildMarkers(nurseLocation, patientLocation),
                          circles: _buildPatientCircles(patientLocation),
                          polylines: _buildPolylines(),
                        )
                      : fmap.FlutterMap(
                          mapController: _desktopMapController,
                          options: fmap.MapOptions(
                            initialCenter: nurseLocation,
                            initialZoom: 14.8,
                          ),
                          children: [
                            fmap.TileLayer(
                              urlTemplate:
                                  'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                              subdomains: const ['a', 'b', 'c', 'd'],
                              userAgentPackageName: 'com.homecare.app',
                            ),
                            fmap.PolylineLayer(
                              polylines: _buildDesktopPolylines(),
                            ),
                            fmap.CircleLayer(
                              circles: _buildDesktopPatientCircles(
                                patientLocation,
                              ),
                            ),
                            fmap.MarkerLayer(
                              markers: _buildDesktopMarkers(
                                nurseLocation,
                                patientLocation,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.38),
                          Colors.transparent,
                          AppTheme.background.withValues(alpha: 0.92),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      TopGlassButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FrostCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Text(
                            booking.status == 'accepted'
                                ? 'You are on the way to the patient'
                                : 'Service is currently in progress',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: FrostCard(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppTheme.elevatedShadow,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppTheme.divider,
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  booking.serviceName,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Patient: ${booking.patientName}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          StatusPill(
                            label: booking.status.toUpperCase().replaceAll(
                              '_',
                              ' ',
                            ),
                            color: booking.status == 'accepted'
                                ? AppTheme.accent
                                : const Color(0xFF7B4FEB),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: AppMetricTile(
                              label: 'Expected earning',
                              value:
                                  '₹${booking.nurseEarning.toStringAsFixed(0)}',
                              color: AppTheme.success,
                              icon: Icons.currency_rupee_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppMetricTile(
                              label: 'Distance / ETA',
                              value: '$distanceText / $etaText',
                              color: AppTheme.accent,
                              icon: Icons.navigation_outlined,
                            ),
                          ),
                        ],
                      ),
                      if (_route?.isFallback == true) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Live route is using a fallback preview path here. On device, Google driving directions should appear when the Directions API is enabled for this key.',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                      const SizedBox(height: 16),
                      FrostCard(
                        padding: const EdgeInsets.all(14),
                        color: AppTheme.background,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  color: AppTheme.accent,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    booking.patientAddress,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _launchPhone(booking.patientPhone),
                                    icon: const Icon(
                                      Icons.call_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Call'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _openChat(
                                      booking.id,
                                      booking.patientName,
                                    ),
                                    icon: const Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Chat'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TapScale(
                        onTap: () => _openExternalNavigation(patientLocation),
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _openExternalNavigation(patientLocation),
                          icon: const Icon(Icons.navigation_rounded, size: 18),
                          label: const Text('Start Navigation'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (booking.status == 'accepted')
                        TapScale(
                          onTap: () => bookingProvider.startService(booking.id),
                          child: ElevatedButton(
                            onPressed: () =>
                                bookingProvider.startService(booking.id),
                            child: const Text('Start Service'),
                          ),
                        ),
                      if (booking.status == 'in_progress')
                        TapScale(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Waiting for patient confirmation to complete the service.',
                                ),
                              ),
                            );
                          },
                          child: ElevatedButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Waiting for patient confirmation to complete the service.',
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.success,
                            ),
                            child: const Text('Service In Progress'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadMapStyle() async {
    final style = await _googleMapsService.loadMapStyle();
    if (!mounted) {
      return;
    }
    setState(() => _mapStyle = style);
    _mapController?.setMapStyle(style);
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openExternalNavigation(ll.LatLng patientLocation) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${patientLocation.latitude},${patientLocation.longitude}&travelmode=driving',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openChat(String bookingId, String counterpartName) {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          threadId: bookingId,
          bookingId: bookingId,
          currentUserId: user.uid,
          currentUserName: user.name,
          counterpartName: counterpartName,
        ),
      ),
    );
  }

  void _maybeRefreshRoute(ll.LatLng patientLocation, ll.LatLng nurseLocation) {
    if (_isRefreshingRoute) {
      return;
    }

    final now = DateTime.now();
    final movedFromLastOrigin = _lastRouteOrigin == null
        ? double.infinity
        : _locationService.calculateDistance(_lastRouteOrigin!, nurseLocation);
    final movedFromLastDestination = _lastRouteDestination == null
        ? double.infinity
        : _locationService.calculateDistance(
            _lastRouteDestination!,
            patientLocation,
          );

    if (_lastRouteRequestAt != null &&
        now.difference(_lastRouteRequestAt!) < const Duration(seconds: 8) &&
        movedFromLastOrigin < 25 &&
        movedFromLastDestination < 10) {
      return;
    }

    _lastRouteOrigin = nurseLocation;
    _lastRouteDestination = patientLocation;
    _lastRouteRequestAt = now;
    _isRefreshingRoute = true;

    _googleMapsService
        .fetchDrivingRoute(origin: nurseLocation, destination: patientLocation)
        .then((route) {
          if (!mounted) {
            return;
          }
          setState(() {
            _route = route;
            _isRefreshingRoute = false;
          });
          _syncMapView(patientLocation, nurseLocation, force: true);
        })
        .catchError((_) {
          if (!mounted) {
            return;
          }
          setState(() => _isRefreshingRoute = false);
        });
  }

  void _syncMapView(
    ll.LatLng patientLocation,
    ll.LatLng nurseLocation, {
    bool force = false,
  }) {
    final routeDistance = _route?.distanceMeters ?? 0;
    final nextCameraKey =
        '${patientLocation.latitude.toStringAsFixed(4)}:${patientLocation.longitude.toStringAsFixed(4)}:${nurseLocation.latitude.toStringAsFixed(4)}:${nurseLocation.longitude.toStringAsFixed(4)}:$routeDistance';

    if (!force && _cameraKey == nextCameraKey) {
      return;
    }
    _cameraKey = nextCameraKey;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      if (AppMapPlatform.supportsGoogleMaps) {
        final controller = _mapController;
        if (controller == null) {
          return;
        }
        try {
          final bounds =
              _route?.bounds ?? _boundsFor(patientLocation, nurseLocation);
          await controller.animateCamera(
            gmap.CameraUpdate.newLatLngBounds(bounds, 84),
          );
        } catch (_) {
          // Bounds animation can fail during the first web/native layout pass.
        }
        return;
      }

      final center = ll.LatLng(
        (patientLocation.latitude + nurseLocation.latitude) / 2,
        (patientLocation.longitude + nurseLocation.longitude) / 2,
      );
      _desktopMapController.move(center, _desktopZoomForRoute());
    });
  }

  gmap.LatLngBounds _boundsFor(ll.LatLng patient, ll.LatLng nurse) {
    final south = patient.latitude < nurse.latitude
        ? patient.latitude
        : nurse.latitude;
    final north = patient.latitude > nurse.latitude
        ? patient.latitude
        : nurse.latitude;
    final west = patient.longitude < nurse.longitude
        ? patient.longitude
        : nurse.longitude;
    final east = patient.longitude > nurse.longitude
        ? patient.longitude
        : nurse.longitude;

    return gmap.LatLngBounds(
      southwest: gmap.LatLng(south, west),
      northeast: gmap.LatLng(north, east),
    );
  }

  Set<gmap.Marker> _buildMarkers(
    ll.LatLng nurseLocation,
    ll.LatLng patientLocation,
  ) {
    return {
      gmap.Marker(
        markerId: const gmap.MarkerId('nurse-live'),
        position: _googleLatLng(nurseLocation),
        icon: gmap.BitmapDescriptor.defaultMarkerWithHue(
          gmap.BitmapDescriptor.hueAzure,
        ),
      ),
      gmap.Marker(
        markerId: const gmap.MarkerId('patient-home'),
        position: _googleLatLng(patientLocation),
        icon: gmap.BitmapDescriptor.defaultMarkerWithHue(
          gmap.BitmapDescriptor.hueRose,
        ),
      ),
    };
  }

  Set<gmap.Circle> _buildPatientCircles(ll.LatLng patientLocation) {
    final center = _googleLatLng(patientLocation);
    return {
      gmap.Circle(
        circleId: const gmap.CircleId('patient-focus'),
        center: center,
        radius: 36,
        fillColor: AppTheme.accent.withValues(alpha: 0.08),
        strokeColor: AppTheme.accent.withValues(alpha: 0.18),
        strokeWidth: 1,
      ),
    };
  }

  List<fmap.CircleMarker> _buildDesktopPatientCircles(
    ll.LatLng patientLocation,
  ) {
    return [
      fmap.CircleMarker(
        point: patientLocation,
        radius: 36,
        useRadiusInMeter: false,
        color: AppTheme.accent.withValues(alpha: 0.08),
        borderColor: AppTheme.accent.withValues(alpha: 0.18),
        borderStrokeWidth: 1,
      ),
    ];
  }

  Set<gmap.Polyline> _buildPolylines() {
    final route = _route;
    if (route == null || route.points.length < 2) {
      return const <gmap.Polyline>{};
    }

    return {
      gmap.Polyline(
        polylineId: const gmap.PolylineId('patient-route'),
        points: route.points,
        color: AppTheme.accent,
        width: 5,
      ),
    };
  }

  List<fmap.Marker> _buildDesktopMarkers(
    ll.LatLng nurseLocation,
    ll.LatLng patientLocation,
  ) {
    return [
      fmap.Marker(
        point: nurseLocation,
        width: 52,
        height: 52,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.local_hospital_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
      fmap.Marker(
        point: patientLocation,
        width: 44,
        height: 44,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.error,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
          ),
          child: const Icon(Icons.home_rounded, color: Colors.white, size: 20),
        ),
      ),
    ];
  }

  List<fmap.Polyline> _buildDesktopPolylines() {
    final route = _route;
    if (route == null || route.points.length < 2) {
      return const <fmap.Polyline>[];
    }

    return [
      fmap.Polyline(
        points: route.points
            .map((point) => ll.LatLng(point.latitude, point.longitude))
            .toList(),
        strokeWidth: 5,
        color: AppTheme.accent,
      ),
    ];
  }

  double _desktopZoomForRoute() {
    final distance = _route?.distanceMeters ?? 0;
    if (distance < 800) {
      return 15.5;
    }
    if (distance < 2000) {
      return 14.8;
    }
    if (distance < 5000) {
      return 13.9;
    }
    return 13.1;
  }

  gmap.LatLng _googleLatLng(ll.LatLng point) =>
      gmap.LatLng(point.latitude, point.longitude);
}
