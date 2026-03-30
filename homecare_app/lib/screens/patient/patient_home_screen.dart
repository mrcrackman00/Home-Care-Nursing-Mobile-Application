import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../config/map_platform.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../models/nurse_qr_payload.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/nurse_provider.dart';
import '../patient/patient_profile_screen.dart';
import '../../services/google_maps_service.dart';
import '../../services/location_service.dart';
import '../../widgets/healthcare_ui.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});
  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  final _googleMapsService = GoogleMapsService();
  UserModel? _selectedNurse;
  Map<String, dynamic>? _scanSelectedService;
  int _currentIndex = 0;
  bool _didBootstrapMap = false;
  String? _boundPatientId;
  final _desktopMapController = fmap.MapController();
  gmap.GoogleMapController? _mapController;
  String? _mapStyle;

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authUser = context.watch<AuthProvider>().user;
    if (authUser == null || authUser.role != 'patient') {
      _boundPatientId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final route = authUser == null
            ? AppRoutes.login
            : authUser.role == 'nurse'
            ? AppRoutes.nurseHome
            : AppRoutes.login;
        Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
      });
      return const Scaffold(
        body: HealthcareBackground(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    _ensurePatientBindings(authUser);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: IndexedStack(
        index: _currentIndex,
        children: [_mapTab(), _bookingsTab(), _profileTab()],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          AppBottomNavItem(
            label: 'Home',
            icon: Icons.map_outlined,
            activeIcon: Icons.map,
          ),
          AppBottomNavItem(
            label: 'Bookings',
            icon: Icons.receipt_long_outlined,
            activeIcon: Icons.receipt_long,
          ),
          AppBottomNavItem(
            label: 'Profile',
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
          ),
        ],
      ),
    );
  }

  void _ensurePatientBindings(UserModel authUser) {
    if (!_didBootstrapMap) {
      _didBootstrapMap = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        context.read<LocationProvider>().initialize();
        context.read<NurseProvider>().listenToOnlineNurses();
      });
    }

    if (_boundPatientId == authUser.uid) {
      return;
    }

    _boundPatientId = authUser.uid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<BookingProvider>().listenToPatientBookings(authUser.uid);
    });
  }

  Widget _mapTab() {
    return Consumer2<LocationProvider, NurseProvider>(
      builder: (context, location, nurses, _) {
        final center =
            location.currentLocation ?? const LatLng(28.6139, 77.2090);
        final nearbyNurses = _nearbyNurses(
          location.currentLocation,
          nurses.onlineNurses,
        );
        if (_selectedNurse != null &&
            nurses.onlineNurses.every(
              (nurse) => nurse.uid != _selectedNurse!.uid,
            )) {
          _selectedNurse = null;
          _scanSelectedService = null;
        }
        final displayNurses = [...nearbyNurses];
        if (_selectedNurse != null &&
            _selectedNurse!.currentLocation != null &&
            displayNurses.every((nurse) => nurse.uid != _selectedNurse!.uid)) {
          displayNurses.insert(0, _selectedNurse!);
        }
        _selectedNurse ??= displayNurses.isNotEmpty
            ? displayNurses.first
            : null;
        return Stack(
          children: [
            AppMapPlatform.supportsGoogleMaps
                ? gmap.GoogleMap(
                    initialCameraPosition: gmap.CameraPosition(
                      target: _googleLatLng(center),
                      zoom: 13.8,
                    ),
                    onMapCreated: (controller) {
                      _mapController = controller;
                      final style = _mapStyle;
                      if (style != null) {
                        controller.setMapStyle(style);
                      }
                      _animateToPoint(center, zoom: 13.8);
                    },
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    compassEnabled: false,
                    markers: _buildNurseMarkers(displayNurses),
                    circles: _buildPatientLocationCircles(
                      location.currentLocation,
                    ),
                  )
                : fmap.FlutterMap(
                    mapController: _desktopMapController,
                    options: fmap.MapOptions(
                      initialCenter: center,
                      initialZoom: 13.8,
                    ),
                    children: [
                      fmap.TileLayer(
                        urlTemplate:
                            'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                        subdomains: const ['a', 'b', 'c', 'd'],
                        userAgentPackageName: 'com.homecare.app',
                      ),
                      if (location.currentLocation != null)
                        fmap.CircleLayer(
                          circles: _buildDesktopPatientCircles(
                            location.currentLocation!,
                          ),
                        ),
                      fmap.MarkerLayer(
                        markers: _buildDesktopNurseMarkers(displayNurses),
                      ),
                    ],
                  ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.52),
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
                child: Column(
                  children: [
                    Row(
                      children: [
                        TopGlassButton(
                          icon: Icons.dashboard_customize_rounded,
                          onPressed: () {},
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
                                const Icon(
                                  Icons.search_rounded,
                                  color: AppTheme.accent,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Search your care area',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
                                  ),
                                ),
                                const StatusPill(
                                  label: 'Live',
                                  color: AppTheme.success,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FrostCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  color: AppTheme.accent,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${displayNurses.length} nearby nurses online',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        TopGlassButton(
                          icon: Icons.my_location_rounded,
                          onPressed: () {
                            if (location.currentLocation != null) {
                              _animateToPoint(
                                location.currentLocation!,
                                zoom: 15.2,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 20,
              bottom: 250,
              child: SafeArea(
                child: TapScale(
                  onTap: () => _scanNurseFromQr(nurses.onlineNurses),
                  child: ElevatedButton.icon(
                    onPressed: () => _scanNurseFromQr(nurses.onlineNurses),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Scan Nurse'),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: DraggableScrollableSheet(
                    expand: false,
                    initialChildSize: 0.42,
                    minChildSize: 0.18,
                    maxChildSize: 0.84,
                    snap: true,
                    snapSizes: const [0.18, 0.42, 0.84],
                    builder: (context, scrollController) => _bottomSheet(
                      location,
                      displayNurses,
                      scrollController,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
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

  Future<void> _animateToPoint(LatLng point, {double zoom = 14.8}) async {
    if (AppMapPlatform.supportsGoogleMaps) {
      final controller = _mapController;
      if (controller == null) {
        return;
      }
      await controller.animateCamera(
        gmap.CameraUpdate.newCameraPosition(
          gmap.CameraPosition(target: _googleLatLng(point), zoom: zoom),
        ),
      );
      return;
    }

    _desktopMapController.move(point, zoom);
  }

  gmap.LatLng _googleLatLng(LatLng point) =>
      gmap.LatLng(point.latitude, point.longitude);

  Set<gmap.Circle> _buildPatientLocationCircles(LatLng? patientLocation) {
    if (patientLocation == null) {
      return const <gmap.Circle>{};
    }

    final center = _googleLatLng(patientLocation);
    return {
      gmap.Circle(
        circleId: const gmap.CircleId('patient-pulse'),
        center: center,
        radius: 42,
        fillColor: AppTheme.accent.withValues(alpha: 0.14),
        strokeColor: AppTheme.accent.withValues(alpha: 0.28),
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

  List<fmap.CircleMarker> _buildDesktopPatientCircles(LatLng patientLocation) {
    return [
      fmap.CircleMarker(
        point: patientLocation,
        radius: 42,
        useRadiusInMeter: false,
        color: AppTheme.accent.withValues(alpha: 0.14),
        borderColor: AppTheme.accent.withValues(alpha: 0.28),
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

  Set<gmap.Marker> _buildNurseMarkers(List<UserModel> nurses) {
    return nurses.where((nurse) => nurse.currentLocation != null).map((nurse) {
      final point = LocationService.geoPointToLatLng(nurse.currentLocation!);
      final selected = _selectedNurse?.uid == nurse.uid;
      return gmap.Marker(
        markerId: gmap.MarkerId('nurse-${nurse.uid}'),
        position: _googleLatLng(point),
        icon: gmap.BitmapDescriptor.defaultMarkerWithHue(
          selected ? gmap.BitmapDescriptor.hueAzure : 210,
        ),
        onTap: () {
          setState(() {
            if (_scanSelectedService != null &&
                _selectedNurse?.uid != nurse.uid) {
              _scanSelectedService = null;
            }
            _selectedNurse = nurse;
          });
        },
        infoWindow: gmap.InfoWindow(
          title: nurse.name,
          snippet: nurse.specializations?.isNotEmpty == true
              ? nurse.specializations!.join(', ')
              : 'Home nursing',
        ),
      );
    }).toSet();
  }

  List<fmap.Marker> _buildDesktopNurseMarkers(List<UserModel> nurses) {
    return nurses.where((nurse) => nurse.currentLocation != null).map((nurse) {
      final point = LocationService.geoPointToLatLng(nurse.currentLocation!);
      final selected = _selectedNurse?.uid == nurse.uid;
      return fmap.Marker(
        point: point,
        width: 50,
        height: 50,
        child: GestureDetector(
          onTap: () {
            setState(() {
              if (_scanSelectedService != null &&
                  _selectedNurse?.uid != nurse.uid) {
                _scanSelectedService = null;
              }
              _selectedNurse = nurse;
            });
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppTheme.accent : AppTheme.divider,
                width: 2,
              ),
              boxShadow: AppTheme.cardShadow,
            ),
            child: const Icon(
              Icons.local_hospital_rounded,
              color: AppTheme.accent,
              size: 24,
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _bottomSheet(
    LocationProvider location,
    List<UserModel> nurses,
    ScrollController scrollController,
  ) {
    final canContinue = _selectedNurse != null;
    return FrostCard(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      borderRadius: BorderRadius.circular(24),
      boxShadow: AppTheme.elevatedShadow,
      child: SingleChildScrollView(
        controller: scrollController,
        physics: const ClampingScrollPhysics(),
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
            Text('Nearby nurses', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              _scanSelectedService != null
                  ? 'Scan shortcut active. Review the selected nurse and confirm the pre-filled service instantly.'
                  : 'Choose a live nurse, review their professional details, and request care confidently.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 96,
              child: nurses.isEmpty
                  ? const Center(
                      child: Text(
                        'No nearby live nurses are visible right now. Ask the nurse to allow location and stay online.',
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: nurses.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) => _NurseMiniCard(
                        nurse: nurses[index],
                        selected: _selectedNurse?.uid == nurses[index].uid,
                        onTap: () {
                          setState(() {
                            if (_scanSelectedService != null &&
                                _selectedNurse?.uid != nurses[index].uid) {
                              _scanSelectedService = null;
                            }
                            _selectedNurse = nurses[index];
                          });
                          final point = nurses[index].currentLocation;
                          if (point != null) {
                            _animateToPoint(
                              LocationService.geoPointToLatLng(point),
                              zoom: 14.8,
                            );
                          }
                        },
                      ),
                    ),
            ),
            if (_selectedNurse != null) ...[
              const SizedBox(height: 16),
              _selectedNurseProfileCard(
                location,
                _selectedNurse!,
                selectedService: _scanSelectedService,
              ),
            ],
            const SizedBox(height: 16),
            TapScale(
              onTap: canContinue ? _continueBookingFlow : null,
              child: ElevatedButton.icon(
                onPressed: canContinue ? _continueBookingFlow : null,
                icon: Icon(
                  !canContinue
                      ? Icons.hourglass_empty_rounded
                      : _scanSelectedService != null
                      ? Icons.flash_on_rounded
                      : Icons.medical_services_outlined,
                ),
                label: Text(
                  !canContinue
                      ? 'No nurse available right now'
                      : _scanSelectedService != null
                      ? 'Book ${_scanSelectedService!['name']} Now'
                      : 'Book Nurse Now',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectedCard(LocationProvider location, UserModel nurse) {
    final nurseLocation = nurse.currentLocation == null
        ? null
        : LocationService.geoPointToLatLng(nurse.currentLocation!);
    final distance = nurseLocation != null && location.currentLocation != null
        ? location.getDistanceTo(nurseLocation)
        : '--';
    final eta = nurseLocation != null && location.currentLocation != null
        ? location.getETATo(nurseLocation)
        : '--';
    final specs =
        nurse.specializations?.take(3).toList() ??
        ['Home Care', 'Basic Visit', 'Elder Care'];
    return FrostCard(
      padding: const EdgeInsets.all(18),
      color: AppTheme.surface,
      borderColor: AppTheme.divider,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppUserAvatar(
                name: nurse.name,
                imageUrl: nurse.profileImage,
                radius: 28,
                backgroundColor: AppTheme.accentLight,
                foregroundColor: AppTheme.accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nurse.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: AppTheme.warning,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${(nurse.rating ?? 4.8).toStringAsFixed(1)} (${nurse.totalRatings ?? 120})',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: nurse.hasPatientVisibleVerificationBadge
                    ? 'Verified'
                    : 'Available',
                color: nurse.hasPatientVisibleVerificationBadge
                    ? AppTheme.success
                    : AppTheme.success,
                icon: nurse.hasPatientVisibleVerificationBadge
                    ? Icons.verified_rounded
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: specs
                .map(
                  (spec) => Chip(
                    label: Text(spec),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              InfoChip(icon: Icons.route_rounded, label: distance),
              InfoChip(icon: Icons.schedule_rounded, label: 'ETA $eta'),
              const InfoChip(
                icon: Icons.currency_rupee_rounded,
                label: '₹800+',
              ),
            ],
          ),
          const SizedBox(height: 16),
          TapScale(
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.serviceSelection),
            child: ElevatedButton(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.serviceSelection),
              child: const Text('Request Nurse →'),
            ),
          ),
        ],
      ),
    );
  }

  List<UserModel> _nearbyNurses(
    LatLng? patientLocation,
    List<UserModel> nurses,
  ) {
    final locationService = LocationService();
    final filtered = nurses.where((nurse) {
      if (nurse.currentLocation == null) {
        return false;
      }
      if (patientLocation == null) {
        return true;
      }

      final nurseLocation = LocationService.geoPointToLatLng(
        nurse.currentLocation!,
      );
      final distance = locationService.calculateDistance(
        patientLocation,
        nurseLocation,
      );
      final radiusKm = nurse.serviceRadiusKm ?? 10;
      return distance <= radiusKm * 1000;
    }).toList();

    if (patientLocation == null) {
      return filtered;
    }

    filtered.sort((a, b) {
      final aLocation = LocationService.geoPointToLatLng(a.currentLocation!);
      final bLocation = LocationService.geoPointToLatLng(b.currentLocation!);
      final aDistance = locationService.calculateDistance(
        patientLocation,
        aLocation,
      );
      final bDistance = locationService.calculateDistance(
        patientLocation,
        bLocation,
      );
      return aDistance.compareTo(bDistance);
    });

    return filtered;
  }

  Widget _selectedNurseProfileCard(
    LocationProvider location,
    UserModel nurse, {
    Map<String, dynamic>? selectedService,
  }) {
    final nurseLocation = nurse.currentLocation == null
        ? null
        : LocationService.geoPointToLatLng(nurse.currentLocation!);
    final distance = nurseLocation != null && location.currentLocation != null
        ? location.getDistanceTo(nurseLocation)
        : '--';
    final eta = nurseLocation != null && location.currentLocation != null
        ? location.getETATo(nurseLocation)
        : '--';
    final specs =
        nurse.specializations?.take(3).toList() ??
        ['Home Care', 'Basic Visit', 'Elder Care'];
    final qualification = (nurse.qualification?.isNotEmpty == true)
        ? nurse.qualification!
        : 'Home nursing professional';
    final experience = (nurse.experience?.isNotEmpty == true)
        ? nurse.experience!
        : 'Experienced for home care visits';
    final languages = (nurse.languages?.isNotEmpty == true)
        ? nurse.languages!.join(', ')
        : 'Hindi';
    final shiftPreference = (nurse.shiftPreference?.isNotEmpty == true)
        ? nurse.shiftPreference!
        : 'Flexible timing';
    final about = (nurse.about?.isNotEmpty == true)
        ? nurse.about!
        : 'Focused on safe, compassionate home care for families.';

    return FrostCard(
      padding: const EdgeInsets.all(18),
      color: AppTheme.surface,
      borderColor: AppTheme.divider,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppUserAvatar(
                name: nurse.name,
                imageUrl: nurse.profileImage,
                radius: 28,
                backgroundColor: AppTheme.accentLight,
                foregroundColor: AppTheme.accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nurse.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: AppTheme.warning,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${(nurse.rating ?? 4.8).toStringAsFixed(1)} (${nurse.totalRatings ?? 0})',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: nurse.hasPatientVisibleVerificationBadge
                    ? 'Verified'
                    : 'Live',
                color: nurse.hasPatientVisibleVerificationBadge
                    ? AppTheme.success
                    : AppTheme.warning,
                icon: nurse.hasPatientVisibleVerificationBadge
                    ? Icons.verified_rounded
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: specs
                .map(
                  (spec) => Chip(
                    label: Text(spec),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          Text(qualification, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(about, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              InfoChip(icon: Icons.route_rounded, label: distance),
              InfoChip(icon: Icons.schedule_rounded, label: 'ETA $eta'),
              InfoChip(
                icon: Icons.currency_rupee_rounded,
                label:
                    'Starts ₹${(nurse.startingPrice ?? 500).toStringAsFixed(0)}',
              ),
              InfoChip(
                icon: Icons.workspace_premium_outlined,
                label: experience,
              ),
              InfoChip(icon: Icons.translate_rounded, label: languages),
              InfoChip(icon: Icons.timelapse_rounded, label: shiftPreference),
              InfoChip(
                icon: Icons.pin_drop_outlined,
                label:
                    '${(nurse.serviceRadiusKm ?? 10).toStringAsFixed(0)} km radius',
              ),
            ],
          ),
          if (selectedService != null) ...[
            const SizedBox(height: 16),
            FrostCard(
              padding: const EdgeInsets.all(14),
              color: AppTheme.accentLight,
              borderColor: AppTheme.accent.withValues(alpha: 0.16),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Text(
                          selectedService['emoji'] as String? ?? '🏥',
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedService['name'] as String,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${selectedService['basePrice']} - ₹${selectedService['maxPrice']}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const StatusPill(
                    label: 'Scan selected',
                    color: AppTheme.accent,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          TapScale(
            onTap: () {
              if (selectedService != null) {
                Navigator.pushNamed(
                  context,
                  AppRoutes.booking,
                  arguments: {
                    'service': selectedService,
                    'preferredNurse': nurse,
                    'scanBooking': true,
                  },
                );
                return;
              }
              Navigator.pushNamed(
                context,
                AppRoutes.serviceSelection,
                arguments: {'preferredNurse': nurse},
              );
            },
            child: ElevatedButton(
              onPressed: () {
                if (selectedService != null) {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.booking,
                    arguments: {
                      'service': selectedService,
                      'preferredNurse': nurse,
                      'scanBooking': true,
                    },
                  );
                  return;
                }
                Navigator.pushNamed(
                  context,
                  AppRoutes.serviceSelection,
                  arguments: {'preferredNurse': nurse},
                );
              },
              child: Text(
                selectedService != null ? 'Book Now' : 'Request Nurse',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _scanNurseFromQr(List<UserModel> onlineNurses) async {
    final result = await Navigator.pushNamed(context, AppRoutes.scanNurse);
    if (!mounted || result is! NurseQrPayload) {
      return;
    }

    UserModel? matchedNurse;
    for (final nurse in onlineNurses) {
      if (nurse.uid == result.nurseId) {
        matchedNurse = nurse;
        break;
      }
    }

    if (matchedNurse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.nurseName} is not online right now. Ask the nurse to go live and try again.',
          ),
        ),
      );
      return;
    }

    final selectedService =
        AppConstants.serviceById(result.nurseServiceType) ??
        AppConstants.fallbackServiceForNurse(matchedNurse.specializations);

    setState(() {
      _currentIndex = 0;
      _selectedNurse = matchedNurse;
      _scanSelectedService = selectedService;
    });

    if (matchedNurse.currentLocation != null) {
      _animateToPoint(
        LocationService.geoPointToLatLng(matchedNurse.currentLocation!),
        zoom: 15,
      );
    }
  }

  void _continueBookingFlow() {
    if (_selectedNurse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No nearby live nurse is selected right now. Ask the nurse to stay online and allow location, then try again.',
          ),
        ),
      );
      return;
    }

    if (_scanSelectedService != null) {
      Navigator.pushNamed(
        context,
        AppRoutes.booking,
        arguments: {
          'service': _scanSelectedService,
          'preferredNurse': _selectedNurse,
          'scanBooking': true,
        },
      );
      return;
    }

    Navigator.pushNamed(
      context,
      AppRoutes.serviceSelection,
      arguments: {'preferredNurse': _selectedNurse},
    );
  }

  Widget _bookingsTab() => HealthcareBackground(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(
            title: 'My bookings',
            subtitle:
                'Track every care session, payment summary, and assigned nurse from one clean timeline.',
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Consumer<BookingProvider>(
              builder: (context, bookingProvider, _) {
                if (bookingProvider.bookings.isEmpty) {
                  return const EmptyStateView(
                    icon: Icons.calendar_today_rounded,
                    title: 'No bookings yet',
                    subtitle:
                        'Book a nurse from the map and your care history will appear here.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: bookingProvider.bookings.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final booking = bookingProvider.bookings[index];
                    final trackable = const {
                      'pending',
                      'accepted',
                      'in_progress',
                    }.contains(booking.status);
                    return _BookingCard(
                      status: booking.status,
                      title: booking.serviceName,
                      subtitle: booking.patientAddress,
                      amount: booking.totalAmount,
                      duration: booking.duration,
                      nurseName: booking.nurseName,
                      actionLabel: trackable ? 'Track live' : null,
                      onTap: trackable
                          ? () => Navigator.pushNamed(
                              context,
                              AppRoutes.tracking,
                              arguments: booking.id,
                            )
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  Widget _profileTab() => HealthcareBackground(
    child: Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.user;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FrostCard(
                padding: const EdgeInsets.all(24),
                borderRadius: BorderRadius.circular(24),
                gradient: AppTheme.primaryGradient,
                boxShadow: AppTheme.elevatedShadow,
                child: Row(
                  children: [
                    AppUserAvatar(
                      name: user?.name ?? 'Patient',
                      imageUrl: user?.profileImage ?? '',
                      radius: 34,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      foregroundColor: Colors.white,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'Patient',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.76),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _ProfileTile(
                icon: Icons.person_outline_rounded,
                title: 'Edit profile',
                subtitle: 'Update your personal details and preferences',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PatientProfileScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _ProfileTile(
                icon: Icons.history_rounded,
                title: 'Booking history',
                subtitle: 'Review all completed and active care visits',
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.bookingHistory),
              ),
              const SizedBox(height: 12),
              _ProfileTile(
                icon: Icons.payments_outlined,
                title: 'Payment methods',
                subtitle: 'Manage saved payment instruments',
                onTap: () {},
              ),
              const SizedBox(height: 12),
              _ProfileTile(
                icon: Icons.support_agent_outlined,
                title: 'Help & support',
                subtitle: 'Reach our care concierge team',
                onTap: () {},
              ),
              const SizedBox(height: 20),
              FrostCard(
                onTap: () async {
                  await authProvider.logout();
                  if (mounted)
                    Navigator.pushReplacementNamed(context, AppRoutes.login);
                },
                padding: const EdgeInsets.all(18),
                color: const Color(0xFFFFF3F6),
                borderColor: AppTheme.error.withValues(alpha: 0.16),
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded, color: AppTheme.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Log out',
                        style: Theme.of(
                          context,
                        ).textTheme.titleSmall?.copyWith(color: AppTheme.error),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.error,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _NurseMiniCard extends StatelessWidget {
  const _NurseMiniCard({
    required this.nurse,
    required this.selected,
    required this.onTap,
  });
  final UserModel nurse;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return FrostCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: selected ? AppTheme.accentLight : AppTheme.surface,
      borderColor: selected ? AppTheme.accent : AppTheme.divider,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 88,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppUserAvatar(
              name: nurse.name,
              imageUrl: nurse.profileImage,
              radius: 20,
              backgroundColor: AppTheme.surface,
              foregroundColor: AppTheme.accent,
            ),
            const SizedBox(height: 10),
            Text(
              nurse.name.split(' ').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${(nurse.rating ?? 4.8).toStringAsFixed(1)} ★',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppTheme.warning),
                  ),
                ),
                if (nurse.hasPatientVisibleVerificationBadge)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.verified_rounded,
                      size: 14,
                      color: AppTheme.success,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.status,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.duration,
    this.nurseName,
    this.actionLabel,
    this.onTap,
  });
  final String status;
  final String title;
  final String subtitle;
  final double amount;
  final String duration;
  final String? nurseName;
  final String? actionLabel;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final badge = switch (status) {
      'pending' => const StatusPill(label: 'Pending', color: AppTheme.warning),
      'accepted' => const StatusPill(
        label: 'Confirmed',
        color: AppTheme.accent,
      ),
      'in_progress' => const StatusPill(
        label: 'Ongoing',
        color: Color(0xFF7B4FEB),
      ),
      'completed' => const StatusPill(
        label: 'Completed',
        color: AppTheme.success,
      ),
      'cancelled' => const StatusPill(
        label: 'Cancelled',
        color: AppTheme.error,
      ),
      _ => const StatusPill(label: 'Unknown', color: AppTheme.textDisabled),
    };
    return FrostCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              badge,
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppMetricTile(
                  label: 'Total paid',
                  value: '₹${amount.toStringAsFixed(0)}',
                  color: AppTheme.accent,
                  icon: Icons.currency_rupee_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppMetricTile(
                  label: 'Duration',
                  value: duration,
                  color: AppTheme.warning,
                  icon: Icons.schedule_rounded,
                ),
              ),
            ],
          ),
          if (nurseName != null) ...[
            const SizedBox(height: 16),
            FrostCard(
              padding: const EdgeInsets.all(14),
              color: AppTheme.background,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.accentLight,
                    child: Text(
                      nurseName![0].toUpperCase(),
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: AppTheme.accent),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Assigned nurse: $nurseName',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Spacer(),
                Text(
                  actionLabel!,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: AppTheme.accent),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppTheme.accent,
                  size: 18,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: FrostCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.accentLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(icon, color: AppTheme.accent, size: 20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textDisabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
