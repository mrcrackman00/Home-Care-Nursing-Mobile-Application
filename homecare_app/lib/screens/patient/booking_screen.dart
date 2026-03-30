import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/nurse_provider.dart';
import '../../services/location_service.dart';
import '../../widgets/healthcare_ui.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  bool _isInstant = true;
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;
  double _selectedPrice = 0;
  final _addressController = TextEditingController();
  bool _useCurrentLocation = true;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments;
    final payload = args is Map<String, dynamic> ? args : null;
    final service =
        payload?['service'] as Map<String, dynamic>? ??
        (args is Map<String, dynamic> ? args : null);
    final preferredNurse = payload?['preferredNurse'] as UserModel?;
    final scanBooking = payload?['scanBooking'] == true;
    if (service == null) {
      return const Scaffold(body: Center(child: Text('No service selected')));
    }

    _selectedPrice = _selectedPrice == 0
        ? (service['basePrice'] as int).toDouble()
        : _selectedPrice;
    final nurseEarning = service['noCommission'] == true
        ? _selectedPrice
        : AppConstants.calculateNurseEarning(_selectedPrice);
    final commission = service['noCommission'] == true
        ? 0.0
        : AppConstants.calculateCommission(_selectedPrice);

    return Scaffold(
      body: HealthcareBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(
                children: [
                  TopGlassButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Book ${service['name']}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FrostCard(
                      padding: const EdgeInsets.all(22),
                      borderRadius: BorderRadius.circular(22),
                      gradient: AppTheme.primaryGradient,
                      boxShadow: AppTheme.elevatedShadow,
                      child: Row(
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: SizedBox(
                              width: 74,
                              height: 74,
                              child: Center(
                                child: Text(
                                  service['emoji'] ?? '🏥',
                                  style: const TextStyle(fontSize: 34),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  service['name'],
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(color: Colors.white),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  service['description'],
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.76,
                                        ),
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    const StatusPill(
                                      label: 'Live dispatch',
                                      color: Colors.white,
                                    ),
                                    StatusPill(
                                      label: '${service['duration']}',
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const SectionHeading(
                      title: 'Booking setup',
                      subtitle:
                          'Choose timing, address, and price before we send the request to nearby nurses.',
                    ),
                    const SizedBox(height: 16),
                    AppSectionCard(
                      title: 'When do you need care?',
                      child: Row(
                        children: [
                          Expanded(
                            child: _ChoiceTile(
                              title: 'Instant',
                              subtitle: 'Request now',
                              icon: Icons.flash_on_rounded,
                              selected: _isInstant,
                              onTap: () => setState(() => _isInstant = true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ChoiceTile(
                              title: 'Schedule',
                              subtitle: 'Choose a slot',
                              icon: Icons.event_available_rounded,
                              selected: !_isInstant,
                              accent: AppTheme.warning,
                              onTap: () => setState(() => _isInstant = false),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_isInstant) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _PickerTile(
                              icon: Icons.calendar_today_outlined,
                              label: _scheduledDate != null
                                  ? '${_scheduledDate!.day}/${_scheduledDate!.month}/${_scheduledDate!.year}'
                                  : 'Select date',
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now().add(
                                    const Duration(hours: 1),
                                  ),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 30),
                                  ),
                                );
                                if (date != null)
                                  setState(() => _scheduledDate = date);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _PickerTile(
                              icon: Icons.schedule_rounded,
                              label: _scheduledTime != null
                                  ? _scheduledTime!.format(context)
                                  : 'Select time',
                              onTap: () async {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.now(),
                                );
                                if (time != null)
                                  setState(() => _scheduledTime = time);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    AppSectionCard(
                      title: 'Service address',
                      child: Column(
                        children: [
                          _AddressTile(
                            selected: _useCurrentLocation,
                            icon: Icons.my_location_rounded,
                            title: 'Use current location',
                            subtitle: 'Fastest dispatch for nearby nurses',
                            onTap: () =>
                                setState(() => _useCurrentLocation = true),
                          ),
                          const SizedBox(height: 10),
                          _AddressTile(
                            selected: !_useCurrentLocation,
                            icon: Icons.edit_location_alt_outlined,
                            title: 'Enter address manually',
                            subtitle: 'Use a custom care address',
                            accent: AppTheme.warning,
                            onTap: () =>
                                setState(() => _useCurrentLocation = false),
                          ),
                          if (!_useCurrentLocation) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _addressController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText:
                                    'Enter building, area, landmark, and city',
                                prefixIcon: Icon(Icons.home_outlined),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (preferredNurse != null) ...[
                      const SizedBox(height: 16),
                      AppSectionCard(
                        title: scanBooking
                            ? 'Scanned nurse'
                            : 'Requested nurse',
                        subtitle: scanBooking
                            ? 'This booking came from the nurse QR scan and will go directly to that nurse.'
                            : 'This request will go straight to the selected nurse first.',
                        child: Row(
                          children: [
                            AppUserAvatar(
                              name: preferredNurse.name,
                              imageUrl: preferredNurse.profileImage,
                              radius: 24,
                              backgroundColor: AppTheme.accentLight,
                              foregroundColor: AppTheme.accent,
                              borderColor:
                                  preferredNurse.hasPatientVisibleVerificationBadge
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
                                          preferredNurse.name,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                      ),
                                      if (preferredNurse
                                          .hasPatientVisibleVerificationBadge)
                                        const StatusPill(
                                          label: 'Verified',
                                          color: AppTheme.success,
                                          icon: Icons.verified_rounded,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    preferredNurse.specializations?.join(
                                          ', ',
                                        ) ??
                                        'General home nursing',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            const StatusPill(
                              label: 'Direct request',
                              color: AppTheme.accent,
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    AppSectionCard(
                      title: 'Set your price',
                      subtitle:
                          'Transparent pricing helps nurses respond faster.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: AnimatedAmountText(
                              amount: _selectedPrice,
                              size: 34,
                              color: AppTheme.primary,
                            ),
                          ),
                          Slider(
                            value: _selectedPrice,
                            min: (service['basePrice'] as int).toDouble(),
                            max: (service['maxPrice'] as int).toDouble(),
                            divisions:
                                (((service['maxPrice'] as int) -
                                            (service['basePrice'] as int)) ~/
                                        100)
                                    .clamp(1, 100),
                            activeColor: AppTheme.accent,
                            inactiveColor: AppTheme.divider,
                            onChanged: (value) =>
                                setState(() => _selectedPrice = value),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '₹${service['basePrice']}',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              Text(
                                '₹${service['maxPrice']}',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppSectionCard(
                      title: 'Payment summary',
                      child: Column(
                        children: [
                          _Row(
                            label: 'Service charge',
                            value: '₹${_selectedPrice.toStringAsFixed(0)}',
                          ),
                          const SizedBox(height: 10),
                          _Row(
                            label: 'Platform fee',
                            value: '₹${commission.toStringAsFixed(0)}',
                            tone: AppTheme.textSecondary,
                          ),
                          const SizedBox(height: 10),
                          _Row(
                            label: 'Nurse receives',
                            value: '₹${nurseEarning.toStringAsFixed(0)}',
                            tone: AppTheme.success,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Divider(),
                          ),
                          _Row(
                            label: 'Total payable',
                            value: '₹${_selectedPrice.toStringAsFixed(0)}',
                            tone: AppTheme.primary,
                            emphasize: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.divider)),
        ),
        child: SafeArea(
          top: false,
          child: Consumer<BookingProvider>(
            builder: (context, bookingProvider, _) => TapScale(
              onTap: bookingProvider.isLoading
                  ? null
                  : () => _createBooking(service, preferredNurse),
              child: ElevatedButton(
                onPressed: bookingProvider.isLoading
                    ? null
                    : () => _createBooking(service, preferredNurse),
                child: bookingProvider.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        preferredNurse != null
                            ? 'Send Request to ${preferredNurse.name}'
                            : 'Book Nurse Now',
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createBooking(
    Map<String, dynamic> service,
    UserModel? preferredNurse,
  ) async {
    final authProvider = context.read<AuthProvider>();
    final bookingProvider = context.read<BookingProvider>();
    final locationProvider = context.read<LocationProvider>();
    if (authProvider.user == null) return;

    GeoPoint location;
    String address;
    if (_useCurrentLocation) {
      final geoPoint = locationProvider.currentLocation;
      if (geoPoint == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to get location')),
          );
        }
        return;
      }
      location = GeoPoint(geoPoint.latitude, geoPoint.longitude);
      address = 'Current Location';
    } else {
      if (_addressController.text.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter your address')),
          );
        }
        return;
      }
      location = const GeoPoint(28.6139, 77.2090);
      address = _addressController.text;
    }

    DateTime? scheduled;
    if (!_isInstant && _scheduledDate != null && _scheduledTime != null) {
      scheduled = DateTime(
        _scheduledDate!.year,
        _scheduledDate!.month,
        _scheduledDate!.day,
        _scheduledTime!.hour,
        _scheduledTime!.minute,
      );
    }

    final effectiveNurse =
        preferredNurse ??
        _pickNearestNurse(
          GeoPoint(location.latitude, location.longitude),
          context.read<NurseProvider>().onlineNurses,
        );

    if (effectiveNurse == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No nearby live nurse is online right now. Ask a nurse to allow location and stay online.',
            ),
          ),
        );
      }
      return;
    }

    final bookingId = await bookingProvider.createBooking(
      patient: authProvider.user!,
      service: service,
      location: location,
      address: address,
      price: _selectedPrice,
      preferredNurse: effectiveNurse,
      isInstant: _isInstant,
      scheduledTime: scheduled,
    );
    if (!mounted) {
      return;
    }

    if (bookingId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Request sent to ${effectiveNurse.name}. Waiting for response.',
          ),
        ),
      );
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.tracking,
        arguments: bookingId,
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          bookingProvider.error ??
              'Request could not be sent. Please try again.',
        ),
      ),
    );
  }

  UserModel? _pickNearestNurse(
    GeoPoint patientLocation,
    List<UserModel> nurses,
  ) {
    final locationService = LocationService();
    final patientPoint = LatLng(
      patientLocation.latitude,
      patientLocation.longitude,
    );

    final candidates = nurses.where((nurse) {
      if (nurse.currentLocation == null) {
        return false;
      }
      final nursePoint = LocationService.geoPointToLatLng(
        nurse.currentLocation!,
      );
      final distance = locationService.calculateDistance(
        patientPoint,
        nursePoint,
      );
      final radiusKm = nurse.serviceRadiusKm ?? 10;
      return distance <= radiusKm * 1000;
    }).toList();

    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((a, b) {
      final aPoint = LocationService.geoPointToLatLng(a.currentLocation!);
      final bPoint = LocationService.geoPointToLatLng(b.currentLocation!);
      final aDistance = locationService.calculateDistance(patientPoint, aPoint);
      final bDistance = locationService.calculateDistance(patientPoint, bPoint);
      return aDistance.compareTo(bDistance);
    });

    return candidates.first;
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.accent = AppTheme.accent,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    return FrostCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      color: selected ? accent.withValues(alpha: 0.08) : AppTheme.surface,
      borderColor: selected ? accent.withValues(alpha: 0.3) : AppTheme.divider,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return FrostCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      color: AppTheme.background,
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = AppTheme.accent,
  });
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    return FrostCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      color: selected ? accent.withValues(alpha: 0.08) : AppTheme.surface,
      borderColor: selected ? accent.withValues(alpha: 0.3) : AppTheme.divider,
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              width: 38,
              height: 38,
              child: Icon(icon, color: accent, size: 18),
            ),
          ),
          const SizedBox(width: 12),
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
          if (selected)
            const Icon(Icons.check_circle_rounded, color: AppTheme.accent),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.tone = AppTheme.textPrimary,
    this.emphasize = false,
  });
  final String label;
  final String value;
  final Color tone;
  final bool emphasize;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: emphasize ? FontWeight.w600 : FontWeight.w500,
            color: emphasize ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
        ),
        AppAmountText(value, color: tone, size: emphasize ? 20 : 15),
      ],
    );
  }
}
