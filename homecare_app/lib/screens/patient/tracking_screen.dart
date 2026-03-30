import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/map_platform.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/google_maps_service.dart';
import '../../services/location_service.dart';
import '../../widgets/healthcare_ui.dart';
import '../shared/chat_screen.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final _firestoreService = FirestoreService();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocationProvider>().initialize();
      final bookingId = ModalRoute.of(context)?.settings.arguments as String?;
      if (bookingId != null) {
        context.read<BookingProvider>().listenToBooking(bookingId);
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

          if (booking.nurseId == null) {
            return _content(
              bookingProvider,
              locationProvider,
              booking,
              nurse: null,
            );
          }

          return StreamBuilder<UserModel?>(
            stream: _firestoreService.streamUser(booking.nurseId!),
            builder: (context, snapshot) {
              return _content(
                bookingProvider,
                locationProvider,
                booking,
                nurse: snapshot.data,
              );
            },
          );
        },
      ),
    );
  }

  Widget _content(
    BookingProvider bookingProvider,
    LocationProvider locationProvider,
    dynamic booking, {
    UserModel? nurse,
  }) {
    final patientLocation = ll.LatLng(
      booking.patientLocation.latitude,
      booking.patientLocation.longitude,
    );
    final nurseLocation = nurse?.currentLocation != null
        ? LocationService.geoPointToLatLng(nurse!.currentLocation!)
        : null;

    if (booking.status == 'pending') {
      return _pendingRequestView(bookingProvider, booking);
    }

    _maybeRefreshRoute(patientLocation, nurseLocation);
    _syncMapView(patientLocation, nurseLocation);

    final distanceText = nurseLocation != null
        ? (_route?.distanceText ??
              locationProvider.getDistanceTo(nurseLocation))
        : '--';
    final etaText = nurseLocation != null
        ? (_route?.durationText ?? locationProvider.getETATo(nurseLocation))
        : '--';

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
                      target: _googleLatLng(nurseLocation ?? patientLocation),
                      zoom: 14.8,
                    ),
                    onMapCreated: (controller) {
                      _mapController = controller;
                      final style = _mapStyle;
                      if (style != null) {
                        controller.setMapStyle(style);
                      }
                      _syncMapView(patientLocation, nurseLocation, force: true);
                    },
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    markers: _buildMarkers(nurseLocation),
                    circles: _buildPatientCircles(patientLocation),
                    polylines: _buildPolylines(),
                  )
                : fmap.FlutterMap(
                    mapController: _desktopMapController,
                    options: fmap.MapOptions(
                      initialCenter: nurseLocation ?? patientLocation,
                      initialZoom: 14.8,
                    ),
                    children: [
                      fmap.TileLayer(
                        urlTemplate:
                            'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                        subdomains: const ['a', 'b', 'c', 'd'],
                        userAgentPackageName: 'com.homecare.app',
                      ),
                      fmap.PolylineLayer(polylines: _buildDesktopPolylines()),
                      fmap.CircleLayer(
                        circles: _buildDesktopPatientCircles(patientLocation),
                      ),
                      fmap.MarkerLayer(
                        markers: _buildDesktopMarkers(nurseLocation),
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
                  onPressed: () {
                    bookingProvider.clearActive();
                    Navigator.pushReplacementNamed(
                      context,
                      AppRoutes.patientHome,
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FrostCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _statusColor(booking.status),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _statusTitle(booking),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ],
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
                            _statusDescription(booking),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    StatusPill(
                      label: booking.status.toUpperCase().replaceAll('_', ' '),
                      color: _statusColor(booking.status),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AppMetricTile(
                        label: 'Distance left',
                        value: distanceText,
                        color: AppTheme.accent,
                        icon: Icons.route_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppMetricTile(
                        label: 'Live ETA',
                        value: etaText,
                        color: AppTheme.warning,
                        icon: Icons.schedule_rounded,
                      ),
                    ),
                  ],
                ),
                if (_route?.isFallback == true && nurseLocation != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Live route line is using a fallback path in this preview. On device, Google driving directions should render when the Directions API is enabled for the key.',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
                if (booking.status != 'pending' && nurseLocation == null) ...[
                  const SizedBox(height: 16),
                  FrostCard(
                    padding: const EdgeInsets.all(14),
                    color: AppTheme.background,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.my_location_rounded,
                          color: AppTheme.warning,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Waiting for the nurse live location. Ask the nurse to stay online and keep location access enabled.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (nurse != null && booking.status != 'pending') ...[
                  const SizedBox(height: 16),
                  FrostCard(
                    padding: const EdgeInsets.all(16),
                    color: AppTheme.background,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            AppUserAvatar(
                              name: nurse.name,
                              imageUrl: nurse.profileImage,
                              radius: 28,
                              backgroundColor: AppTheme.accentLight,
                              foregroundColor: AppTheme.accent,
                              borderColor:
                                  nurse.hasPatientVisibleVerificationBadge
                                  ? AppTheme.success
                                  : null,
                              borderWidth: 2,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          nurse.name,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                      ),
                                      if (nurse.hasPatientVisibleVerificationBadge)
                                        const StatusPill(
                                          label: 'Verified',
                                          color: AppTheme.success,
                                          icon: Icons.verified_rounded,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${(nurse.rating ?? 0).toStringAsFixed(1)} rating',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  distanceText,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(color: AppTheme.accent),
                                ),
                                Text(
                                  'ETA $etaText',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _launchPhone(nurse.phone),
                                icon: const Icon(Icons.call_rounded, size: 18),
                                label: const Text('Call'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _openChat(booking.id, nurse.name),
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
                ],
                const SizedBox(height: 16),
                if (booking.status == 'pending')
                  TapScale(
                    onTap: () async {
                      await bookingProvider.cancelBooking(
                        booking.id,
                        'Patient cancelled',
                      );
                      if (mounted) {
                        Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.patientHome,
                        );
                      }
                    },
                    child: FrostCard(
                      onTap: () async {
                        await bookingProvider.cancelBooking(
                          booking.id,
                          'Patient cancelled',
                        );
                        if (mounted) {
                          Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.patientHome,
                          );
                        }
                      },
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      color: const Color(0xFFFFF3F6),
                      borderColor: AppTheme.error.withValues(alpha: 0.16),
                      child: Center(
                        child: Text(
                          'Cancel Booking',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: AppTheme.error),
                        ),
                      ),
                    ),
                  ),
                if (booking.status == 'in_progress')
                  TapScale(
                    onTap: () => _showCompleteDialog(
                      bookingProvider,
                      booking.id,
                      booking.nurseId!,
                    ),
                    child: ElevatedButton(
                      onPressed: () => _showCompleteDialog(
                        bookingProvider,
                        booking.id,
                        booking.nurseId!,
                      ),
                      child: const Text('Mark Service Completed'),
                    ),
                  ),
              ],
            ),
          ),
        ),
        ],
      ),
    );
  }

  Widget _pendingRequestView(BookingProvider bookingProvider, dynamic booking) {
    return HealthcareBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TopGlassButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onPressed: () {
                      bookingProvider.clearActive();
                      Navigator.pushReplacementNamed(
                        context,
                        AppRoutes.patientHome,
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Booking request sent',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FrostCard(
                padding: const EdgeInsets.all(24),
                borderRadius: BorderRadius.circular(24),
                boxShadow: AppTheme.elevatedShadow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: AppTheme.warning,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Waiting for nurse response',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const StatusPill(
                          label: 'Pending',
                          color: AppTheme.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Your request has been sent. Once the nurse accepts, this page will automatically switch to live tracking.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: AppMetricTile(
                            label: 'Service',
                            value: booking.serviceName,
                            color: AppTheme.accent,
                            icon: Icons.medical_services_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppMetricTile(
                            label: 'Total payable',
                            value: '₹${booking.totalAmount.toStringAsFixed(0)}',
                            color: AppTheme.success,
                            icon: Icons.currency_rupee_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FrostCard(
                      padding: const EdgeInsets.all(16),
                      color: AppTheme.background,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: AppTheme.accent,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              booking.patientAddress,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    TapScale(
                      onTap: () async {
                        await bookingProvider.cancelBooking(
                          booking.id,
                          'Patient cancelled',
                        );
                        if (!mounted) {
                          return;
                        }
                        Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.patientHome,
                        );
                      },
                      child: FrostCard(
                        onTap: () async {
                          await bookingProvider.cancelBooking(
                            booking.id,
                            'Patient cancelled',
                          );
                          if (!mounted) {
                            return;
                          }
                          Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.patientHome,
                          );
                        },
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        color: const Color(0xFFFFF3F6),
                        borderColor: AppTheme.error.withValues(alpha: 0.16),
                        child: Center(
                          child: Text(
                            'Cancel Booking',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(color: AppTheme.error),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

  void _showCompleteDialog(
    BookingProvider bookingProvider,
    String bookingId,
    String nurseId,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete service?'),
        content: Text(
          'If you continue, the visit will close now and the nurse earnings will be released to the dashboard immediately in this MVP build.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not Yet'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _finalizeCompletion(bookingProvider, bookingId, nurseId);
            },
            child: const Text('Complete Service'),
          ),
        ],
      ),
    );
  }

  Future<void> _finalizeCompletion(
    BookingProvider bookingProvider,
    String bookingId,
    String nurseId,
  ) async {
    await bookingProvider.markCompleted(bookingId);
    if (!mounted) return;
    if (bookingProvider.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(bookingProvider.error!)));
      return;
    }
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.rating,
      arguments: {'bookingId': bookingId, 'nurseId': nurseId},
    );
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
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

  void _maybeRefreshRoute(ll.LatLng patientLocation, ll.LatLng? nurseLocation) {
    if (nurseLocation == null || _isRefreshingRoute) {
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
    ll.LatLng? nurseLocation, {
    bool force = false,
  }) {
    final routeDistance = _route?.distanceMeters ?? 0;
    final nextCameraKey = nurseLocation == null
        ? '${patientLocation.latitude.toStringAsFixed(4)}:${patientLocation.longitude.toStringAsFixed(4)}:solo'
        : '${patientLocation.latitude.toStringAsFixed(4)}:${patientLocation.longitude.toStringAsFixed(4)}:${nurseLocation.latitude.toStringAsFixed(4)}:${nurseLocation.longitude.toStringAsFixed(4)}:$routeDistance';

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
          if (nurseLocation == null) {
            await controller.animateCamera(
              gmap.CameraUpdate.newCameraPosition(
                gmap.CameraPosition(
                  target: _googleLatLng(patientLocation),
                  zoom: 15.2,
                ),
              ),
            );
            return;
          }

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

      if (nurseLocation == null) {
        _desktopMapController.move(patientLocation, 15.2);
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

  Set<gmap.Marker> _buildMarkers(ll.LatLng? nurseLocation) {
    if (nurseLocation == null) {
      return const <gmap.Marker>{};
    }

    return {
      gmap.Marker(
        markerId: const gmap.MarkerId('nurse-live'),
        position: _googleLatLng(nurseLocation),
        icon: gmap.BitmapDescriptor.defaultMarkerWithHue(
          gmap.BitmapDescriptor.hueAzure,
        ),
        anchor: const Offset(0.5, 0.5),
      ),
    };
  }

  Set<gmap.Circle> _buildPatientCircles(ll.LatLng patientLocation) {
    final center = _googleLatLng(patientLocation);
    return {
      gmap.Circle(
        circleId: const gmap.CircleId('patient-pulse'),
        center: center,
        radius: 42,
        fillColor: AppTheme.accent.withValues(alpha: 0.14),
        strokeColor: AppTheme.accent.withValues(alpha: 0.26),
        strokeWidth: 1,
      ),
      gmap.Circle(
        circleId: const gmap.CircleId('patient-dot'),
        center: center,
        radius: 10,
        fillColor: AppTheme.accent,
        strokeColor: Colors.white,
        strokeWidth: 3,
      ),
    };
  }

  List<fmap.CircleMarker> _buildDesktopPatientCircles(
    ll.LatLng patientLocation,
  ) {
    return [
      fmap.CircleMarker(
        point: patientLocation,
        radius: 42,
        useRadiusInMeter: false,
        color: AppTheme.accent.withValues(alpha: 0.14),
        borderColor: AppTheme.accent.withValues(alpha: 0.26),
        borderStrokeWidth: 1,
      ),
      fmap.CircleMarker(
        point: patientLocation,
        radius: 10,
        useRadiusInMeter: false,
        color: AppTheme.accent,
        borderColor: Colors.white,
        borderStrokeWidth: 3,
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
        polylineId: const gmap.PolylineId('nurse-route'),
        points: route.points,
        color: AppTheme.accent,
        width: 5,
      ),
    };
  }

  List<fmap.Marker> _buildDesktopMarkers(ll.LatLng? nurseLocation) {
    if (nurseLocation == null) {
      return const <fmap.Marker>[];
    }

    return [
      fmap.Marker(
        point: nurseLocation,
        width: 54,
        height: 54,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.local_hospital_rounded,
            color: Colors.white,
            size: 26,
          ),
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

  String _statusTitle(dynamic booking) => switch (booking.status as String) {
    'pending' when booking.dispatchState == 'requested_to_nurse' =>
      'Waiting for your selected nurse to respond',
    'pending' when booking.dispatchState == 'needs_reassignment' =>
      'Needs a new nurse request',
    'pending' => 'Waiting for assignment',
    'accepted' => 'Nurse accepted your booking',
    'in_progress' => 'Service currently in progress',
    'completed' => 'Visit completed',
    _ => booking.status,
  };

  String _statusDescription(dynamic booking) => switch (booking.status
      as String) {
    'pending' when booking.dispatchState == 'requested_to_nurse' =>
      'Your request has been sent directly to the selected nurse. Once accepted, live navigation will start here.',
    'pending' when booking.dispatchState == 'needs_reassignment' =>
      'The earlier nurse could not take this visit. Please choose another nurse or let admin manually offer it again.',
    'pending' =>
      'Your booking is saved and waiting for a nurse or admin assignment.',
    'accepted' =>
      'Your nurse is on the way and the live route is updating in real time.',
    'in_progress' =>
      'Care is underway. Confirm completion once the visit ends.',
    'completed' =>
      'Thank you for choosing NurseCare. Please rate the experience.',
    _ => booking.status,
  };

  Color _statusColor(String status) => switch (status) {
    'pending' => AppTheme.warning,
    'accepted' => AppTheme.accent,
    'in_progress' => const Color(0xFF7B4FEB),
    'completed' => AppTheme.success,
    _ => AppTheme.textDisabled,
  };
}
