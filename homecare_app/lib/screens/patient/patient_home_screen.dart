import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/nurse_provider.dart';
import '../../services/location_service.dart';
import '../../widgets/healthcare_ui.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});
  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> with TickerProviderStateMixin {
  final _mapController = MapController();
  late final AnimationController _pulseController;
  UserModel? _selectedNurse;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<LocationProvider>().initialize();
      context.read<NurseProvider>().listenToOnlineNurses();
      final patientId = auth.user?.uid;
      if (patientId != null) {
        context.read<BookingProvider>().listenToPatientBookings(patientId);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          AppBottomNavItem(label: 'Home', icon: Icons.map_outlined, activeIcon: Icons.map),
          AppBottomNavItem(label: 'Bookings', icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long),
          AppBottomNavItem(label: 'Profile', icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded),
        ],
      ),
    );
  }

  Widget _mapTab() {
    return Consumer2<LocationProvider, NurseProvider>(
      builder: (context, location, nurses, _) {
        final center = location.currentLocation ?? const LatLng(28.6139, 77.2090);
        final onlineNurses = nurses.onlineNurses;
        _selectedNurse ??= onlineNurses.isNotEmpty ? onlineNurses.first : null;
        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: center, initialZoom: 13.8),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.homecare.app',
                ),
                if (location.currentLocation != null) MarkerLayer(markers: [_patientMarker(location.currentLocation!)]),
                MarkerLayer(
                  markers: onlineNurses.map((nurse) {
                    if (nurse.currentLocation == null) return null;
                    final point = LocationService.geoPointToLatLng(nurse.currentLocation!);
                    return Marker(
                      point: point,
                      width: 50,
                      height: 50,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedNurse = nurse),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: _selectedNurse?.uid == nurse.uid ? AppTheme.accent : AppTheme.divider, width: 2),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: const Icon(Icons.local_hospital_rounded, color: AppTheme.accent, size: 24),
                        ),
                      ),
                    );
                  }).whereType<Marker>().toList(),
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
                      colors: [Colors.white.withValues(alpha: 0.52), Colors.transparent, AppTheme.background.withValues(alpha: 0.92)],
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
                        TopGlassButton(icon: Icons.dashboard_customize_rounded, onPressed: () {}),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FrostCard(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                const Icon(Icons.search_rounded, color: AppTheme.accent, size: 20),
                                const SizedBox(width: 10),
                                Expanded(child: Text('Search your care area', style: Theme.of(context).textTheme.bodyLarge)),
                                const StatusPill(label: 'Live', color: AppTheme.success),
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
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on_outlined, color: AppTheme.accent, size: 18),
                                const SizedBox(width: 10),
                                Expanded(child: Text('${onlineNurses.length} nearby nurses online', style: Theme.of(context).textTheme.titleSmall)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        TopGlassButton(
                          icon: Icons.my_location_rounded,
                          onPressed: () {
                            if (location.currentLocation != null) _mapController.move(location.currentLocation!, 15.2);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(left: 20, right: 20, bottom: 20, child: _bottomSheet(location, onlineNurses)),
          ],
        );
      },
    );
  }

  Marker _patientMarker(LatLng point) {
    return Marker(
      point: point,
      width: 54,
      height: 54,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 54 * (0.45 + _pulseController.value * 0.55),
                height: 54 * (0.45 + _pulseController.value * 0.55),
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.accent.withValues(alpha: 0.22 * (1 - _pulseController.value))),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.accent, border: Border.all(color: Colors.white, width: 4), boxShadow: AppTheme.cardShadow),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _bottomSheet(LocationProvider location, List<UserModel> nurses) {
    return FrostCard(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      borderRadius: BorderRadius.circular(24),
      boxShadow: AppTheme.elevatedShadow,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(100)))),
          const SizedBox(height: 14),
          Text('Nearby nurses', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Choose a professional and request care instantly.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          SizedBox(
            height: 96,
            child: nurses.isEmpty
                ? const Center(child: Text('No nurses are online right now.'))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: nurses.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) => _NurseMiniCard(
                      nurse: nurses[index],
                      selected: _selectedNurse?.uid == nurses[index].uid,
                      onTap: () {
                        setState(() => _selectedNurse = nurses[index]);
                        final point = nurses[index].currentLocation;
                        if (point != null) _mapController.move(LocationService.geoPointToLatLng(point), 14.8);
                      },
                    ),
                  ),
          ),
          if (_selectedNurse != null) ...[const SizedBox(height: 16), _selectedCard(location, _selectedNurse!)],
          const SizedBox(height: 16),
          TapScale(
            onTap: () => Navigator.pushNamed(context, AppRoutes.serviceSelection),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.serviceSelection),
              icon: const Icon(Icons.medical_services_outlined),
              label: const Text('Book Nurse Now'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectedCard(LocationProvider location, UserModel nurse) {
    final nurseLocation = nurse.currentLocation == null ? null : LocationService.geoPointToLatLng(nurse.currentLocation!);
    final distance = nurseLocation != null && location.currentLocation != null ? location.getDistanceTo(nurseLocation) : '--';
    final eta = nurseLocation != null && location.currentLocation != null ? location.getETATo(nurseLocation) : '--';
    final specs = nurse.specializations?.take(3).toList() ?? ['Home Care', 'Basic Visit', 'Elder Care'];
    return FrostCard(
      padding: const EdgeInsets.all(18),
      color: AppTheme.surface,
      borderColor: AppTheme.divider,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 28, backgroundColor: AppTheme.accentLight, child: Text(nurse.name.isNotEmpty ? nurse.name[0].toUpperCase() : 'N', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.accent))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nurse.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.star_rounded, color: AppTheme.warning, size: 16),
              const SizedBox(width: 4),
              Text('${(nurse.rating ?? 4.8).toStringAsFixed(1)} (${nurse.totalRatings ?? 120})', style: Theme.of(context).textTheme.bodyMedium),
            ]),
          ])),
          const StatusPill(label: 'Available', color: AppTheme.success),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: specs.map((spec) => Chip(label: Text(spec), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)).toList()),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          InfoChip(icon: Icons.route_rounded, label: distance),
          InfoChip(icon: Icons.schedule_rounded, label: 'ETA $eta'),
          const InfoChip(icon: Icons.currency_rupee_rounded, label: '₹800+'),
        ]),
        const SizedBox(height: 16),
        TapScale(
          onTap: () => Navigator.pushNamed(context, AppRoutes.serviceSelection),
          child: ElevatedButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.serviceSelection), child: const Text('Request Nurse →')),
        ),
      ]),
    );
  }

  Widget _bookingsTab() => HealthcareBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionHeading(title: 'My bookings', subtitle: 'Track every care session, payment summary, and assigned nurse from one clean timeline.'),
            const SizedBox(height: 20),
            Expanded(
              child: Consumer<BookingProvider>(
                builder: (context, bookingProvider, _) {
                  if (bookingProvider.bookings.isEmpty) {
                    return const EmptyStateView(icon: Icons.calendar_today_rounded, title: 'No bookings yet', subtitle: 'Book a nurse from the map and your care history will appear here.');
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: bookingProvider.bookings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) => _BookingCard(status: bookingProvider.bookings[index].status, title: bookingProvider.bookings[index].serviceName, subtitle: bookingProvider.bookings[index].patientAddress, amount: bookingProvider.bookings[index].totalAmount, duration: bookingProvider.bookings[index].duration, nurseName: bookingProvider.bookings[index].nurseName),
                  );
                },
              ),
            ),
          ]),
        ),
      );

  Widget _profileTab() => HealthcareBackground(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            final user = authProvider.user;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FrostCard(
                  padding: const EdgeInsets.all(24),
                  borderRadius: BorderRadius.circular(24),
                  gradient: AppTheme.primaryGradient,
                  boxShadow: AppTheme.elevatedShadow,
                  child: Row(children: [
                    CircleAvatar(radius: 34, backgroundColor: Colors.white.withValues(alpha: 0.12), child: Text(user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'U', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white))),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(user?.name ?? 'Patient', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(user?.email ?? '', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.76))),
                    ])),
                  ]),
                ),
                const SizedBox(height: 20),
                _ProfileTile(icon: Icons.person_outline_rounded, title: 'Edit profile', subtitle: 'Update your personal details and preferences', onTap: () {}),
                const SizedBox(height: 12),
                _ProfileTile(icon: Icons.history_rounded, title: 'Booking history', subtitle: 'Review all completed and active care visits', onTap: () => Navigator.pushNamed(context, AppRoutes.bookingHistory)),
                const SizedBox(height: 12),
                _ProfileTile(icon: Icons.payments_outlined, title: 'Payment methods', subtitle: 'Manage saved payment instruments', onTap: () {}),
                const SizedBox(height: 12),
                _ProfileTile(icon: Icons.support_agent_outlined, title: 'Help & support', subtitle: 'Reach our care concierge team', onTap: () {}),
                const SizedBox(height: 20),
                FrostCard(
                  onTap: () async {
                    await authProvider.logout();
                    if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
                  },
                  padding: const EdgeInsets.all(18),
                  color: const Color(0xFFFFF3F6),
                  borderColor: AppTheme.error.withValues(alpha: 0.16),
                  child: Row(children: [
                    const Icon(Icons.logout_rounded, color: AppTheme.error),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Log out', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppTheme.error))),
                    const Icon(Icons.chevron_right_rounded, color: AppTheme.error),
                  ]),
                ),
              ]),
            );
          },
        ),
      );
}

class _NurseMiniCard extends StatelessWidget {
  const _NurseMiniCard({required this.nurse, required this.selected, required this.onTap});
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(radius: 20, backgroundColor: AppTheme.surface, child: Text(nurse.name.isNotEmpty ? nurse.name[0].toUpperCase() : 'N', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.accent))),
            const SizedBox(height: 10),
            Text(nurse.name.split(' ').first, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 2),
            Text('${(nurse.rating ?? 4.8).toStringAsFixed(1)} ★', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.warning)),
          ]),
        ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.status, required this.title, required this.subtitle, required this.amount, required this.duration, this.nurseName});
  final String status;
  final String title;
  final String subtitle;
  final double amount;
  final String duration;
  final String? nurseName;
  @override
  Widget build(BuildContext context) {
    final badge = switch (status) {
      'pending' => const StatusPill(label: 'Pending', color: AppTheme.warning),
      'accepted' => const StatusPill(label: 'Confirmed', color: AppTheme.accent),
      'in_progress' => const StatusPill(label: 'Ongoing', color: Color(0xFF7B4FEB)),
      'completed' => const StatusPill(label: 'Completed', color: AppTheme.success),
      'cancelled' => const StatusPill(label: 'Cancelled', color: AppTheme.error),
      _ => const StatusPill(label: 'Unknown', color: AppTheme.textDisabled),
    };
    return FrostCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          ])),
          const SizedBox(width: 12),
          badge,
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: AppMetricTile(label: 'Total paid', value: '₹${amount.toStringAsFixed(0)}', color: AppTheme.accent, icon: Icons.currency_rupee_rounded)),
          const SizedBox(width: 12),
          Expanded(child: AppMetricTile(label: 'Duration', value: duration, color: AppTheme.warning, icon: Icons.schedule_rounded)),
        ]),
        if (nurseName != null) ...[
          const SizedBox(height: 16),
          FrostCard(
            padding: const EdgeInsets.all(14),
            color: AppTheme.background,
            child: Row(children: [
              CircleAvatar(backgroundColor: AppTheme.accentLight, child: Text(nurseName![0].toUpperCase(), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.accent))),
              const SizedBox(width: 12),
              Expanded(child: Text('Assigned nurse: $nurseName', style: Theme.of(context).textTheme.titleSmall)),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return FrostCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(children: [
        DecoratedBox(
          decoration: BoxDecoration(color: AppTheme.accentLight, borderRadius: BorderRadius.circular(14)),
          child: SizedBox(width: 44, height: 44, child: Icon(icon, color: AppTheme.accent, size: 20)),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ])),
        const Icon(Icons.chevron_right_rounded, color: AppTheme.textDisabled),
      ]),
    );
  }
}
