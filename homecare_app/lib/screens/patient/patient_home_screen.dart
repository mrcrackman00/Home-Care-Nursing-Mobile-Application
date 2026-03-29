import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/nurse_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/booking_provider.dart';
import '../../services/location_service.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  UserModel? _selectedNurse;
  late AnimationController _pulseController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      locationProvider.initialize();
      
      final nurseProvider = Provider.of<NurseProvider>(context, listen: false);
      nurseProvider.listenToOnlineNurses();
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
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildMapView(),
          _buildBookingsView(),
          _buildProfileView(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'Bookings'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView() {
    return Consumer2<LocationProvider, NurseProvider>(
      builder: (context, locationProvider, nurseProvider, _) {
        final center = locationProvider.currentLocation ?? const LatLng(28.6139, 77.2090); // Default to Delhi

        return Stack(
          children: [
            // Full Screen Map (OpenStreetMap)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 14,
                onTap: (_, __) {
                  setState(() => _selectedNurse = null);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.homecare.app',
                ),
                // Patient location marker
                if (locationProvider.currentLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: locationProvider.currentLocation!,
                        width: 40,
                        height: 40,
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                // Pulse ring
                                Container(
                                  width: 40 * (0.5 + _pulseController.value * 0.5),
                                  height: 40 * (0.5 + _pulseController.value * 0.5),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.info.withValues(alpha: 0.3 * (1 - _pulseController.value)),
                                  ),
                                ),
                                // Center dot
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.info,
                                    border: Border.all(color: Colors.white, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.info.withValues(alpha: 0.5),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                // Nurse markers
                MarkerLayer(
                  markers: nurseProvider.onlineNurses.map((nurse) {
                    if (nurse.currentLocation == null) return null;
                    final nurseLatLng = LocationService.geoPointToLatLng(nurse.currentLocation!);
                    return Marker(
                      point: nurseLatLng,
                      width: 48,
                      height: 48,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedNurse = nurse);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryTeal.withValues(alpha: 0.4),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.medical_services_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    );
                  }).whereType<Marker>().toList(),
                ),
              ],
            ),
            // Top Bar
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        shape: BoxShape.circle,
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.menu, color: Colors.white),
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppTheme.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Your location',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                              ),
                            ),
                            const Icon(Icons.search, color: AppTheme.textMuted, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Number of nurses nearby badge
            Positioned(
              top: 100,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.medical_services, color: AppTheme.primaryTeal, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${nurseProvider.onlineNurses.length} nurses nearby',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
            // My location button
            Positioned(
              bottom: _selectedNurse != null ? 280 : 120,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.cardShadow,
                ),
                child: IconButton(
                  icon: const Icon(Icons.my_location, color: AppTheme.primaryTeal),
                  onPressed: () {
                    if (locationProvider.currentLocation != null) {
                      _mapController.move(locationProvider.currentLocation!, 15);
                    }
                  },
                ),
              ),
            ),
            // Book Now Button (at bottom)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.serviceSelection);
                },
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppTheme.elevatedShadow,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.medical_services_rounded, color: Colors.white, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'Book a Nurse',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
            // Selected Nurse Card
            if (_selectedNurse != null)
              Positioned(
                bottom: 100,
                left: 16,
                right: 16,
                child: _buildNurseCard(_selectedNurse!, locationProvider),
              ),
          ],
        );
      },
    );
  }

  Widget _buildNurseCard(UserModel nurse, LocationProvider locationProvider) {
    final nurseLocation = nurse.currentLocation != null
        ? LocationService.geoPointToLatLng(nurse.currentLocation!)
        : null;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Nurse photo
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.primaryTeal,
                child: nurse.profileImage.isNotEmpty
                    ? ClipOval(child: Image.network(nurse.profileImage, fit: BoxFit.cover))
                    : Text(
                        nurse.name.isNotEmpty ? nurse.name[0].toUpperCase() : 'N',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nurse.name,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, color: AppTheme.accentGold, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${(nurse.rating ?? 0).toStringAsFixed(1)} (${nurse.totalRatings ?? 0})',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                        if (nurse.verified == true) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.verified, color: AppTheme.primaryTeal, size: 16),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (nurseLocation != null && locationProvider.currentLocation != null) ...[
                    Text(
                      locationProvider.getDistanceTo(nurseLocation),
                      style: const TextStyle(color: AppTheme.primaryTeal, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '~${locationProvider.getETATo(nurseLocation)}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Specializations
          if (nurse.specializations != null && nurse.specializations!.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: nurse.specializations!.take(3).map((spec) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(spec, style: const TextStyle(color: AppTheme.primaryTeal, fontSize: 11)),
              )).toList(),
            ),
          const SizedBox(height: 12),
          // Request Nurse Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.serviceSelection);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Request Nurse', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsView() {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('My Bookings', style: Theme.of(context).textTheme.displaySmall),
            ),
            Expanded(
              child: Consumer<BookingProvider>(
                builder: (context, bookingProvider, _) {
                  if (bookingProvider.bookings.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 64, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          const Text('No bookings yet', style: TextStyle(color: AppTheme.textMuted, fontSize: 16)),
                          const SizedBox(height: 8),
                          const Text('Book a nurse to get started', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: bookingProvider.bookings.length,
                    itemBuilder: (context, index) {
                      final booking = bookingProvider.bookings[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(booking.serviceName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                _buildStatusChip(booking.status),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('₹${booking.totalAmount.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.w600)),
                            if (booking.nurseName != null)
                              Text('Nurse: ${booking.nurseName}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          ],
                        ),
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
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'pending': color = AppTheme.warning; break;
      case 'accepted': color = AppTheme.info; break;
      case 'in_progress': color = AppTheme.primaryTeal; break;
      case 'completed': color = AppTheme.success; break;
      case 'cancelled': color = AppTheme.error; break;
      default: color = AppTheme.textMuted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase().replaceAll('_', ' '),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildProfileView() {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
      child: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            final user = authProvider.user;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppTheme.primaryTeal,
                    child: Text(
                      user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'U',
                      style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(user?.name ?? 'User', style: Theme.of(context).textTheme.headlineMedium),
                  Text(user?.email ?? '', style: const TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 32),
                  _buildProfileTile(Icons.person_outline, 'Edit Profile', () {}),
                  _buildProfileTile(Icons.history, 'Booking History', () => Navigator.pushNamed(context, AppRoutes.bookingHistory)),
                  _buildProfileTile(Icons.payment, 'Payment Methods', () {}),
                  _buildProfileTile(Icons.help_outline, 'Help & Support', () {}),
                  _buildProfileTile(Icons.info_outline, 'About', () {}),
                  const SizedBox(height: 16),
                  _buildProfileTile(
                    Icons.logout,
                    'Logout',
                    () async {
                      await authProvider.logout();
                      if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
                    },
                    isDestructive: true,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileTile(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: isDestructive ? AppTheme.error : AppTheme.primaryTeal),
        title: Text(title, style: TextStyle(color: isDestructive ? AppTheme.error : Colors.white)),
        trailing: Icon(Icons.chevron_right, color: isDestructive ? AppTheme.error : AppTheme.textMuted),
        tileColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
