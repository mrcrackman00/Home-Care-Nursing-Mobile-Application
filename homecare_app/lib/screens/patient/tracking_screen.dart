import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/booking_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../models/user_model.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final FirestoreService _firestoreService = FirestoreService();
  late AnimationController _pulseController;
  UserModel? _nurse;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bookingId = ModalRoute.of(context)!.settings.arguments as String?;
      if (bookingId != null) {
        final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
        bookingProvider.listenToBooking(bookingId);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _loadNurseData(String nurseId) async {
    final nurse = await _firestoreService.getUser(nurseId);
    if (mounted) setState(() => _nurse = nurse);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer2<BookingProvider, LocationProvider>(
        builder: (context, bookingProvider, locationProvider, _) {
          final booking = bookingProvider.activeBooking;
          if (booking == null) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal));
          }

          // Load nurse data if accepted
          if (booking.nurseId != null && _nurse == null) {
            _loadNurseData(booking.nurseId!);
          }

          final patientLocation = LatLng(
            booking.patientLocation.latitude,
            booking.patientLocation.longitude,
          );

          final nurseLocation = _nurse?.currentLocation != null
              ? LocationService.geoPointToLatLng(_nurse!.currentLocation!)
              : null;

          return Stack(
            children: [
              // Map
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: patientLocation,
                  initialZoom: 14,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.homecare.app',
                  ),
                  // Patient marker
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: patientLocation,
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.info,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(Icons.person, color: Colors.white, size: 20),
                        ),
                      ),
                      // Nurse marker (if accepted)
                      if (nurseLocation != null)
                        Marker(
                          point: nurseLocation,
                          width: 48,
                          height: 48,
                          child: AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, _) {
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryTeal.withValues(alpha: 0.4 * (1 - _pulseController.value)),
                                      blurRadius: 20 * _pulseController.value,
                                      spreadRadius: 5 * _pulseController.value,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.medical_services, color: Colors.white, size: 24),
                              );
                            },
                          ),
                        ),
                    ],
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
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                          onPressed: () {
                            bookingProvider.clearActive();
                            Navigator.pushReplacementNamed(context, AppRoutes.patientHome);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.bgCard,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Text(
                            _getStatusText(booking.status),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Card
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, -5))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle bar
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.bgCardLight,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Status
                      _buildStatusBanner(booking.status),
                      const SizedBox(height: 16),

                      // Service info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(booking.serviceName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                              Text(booking.duration, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                            ],
                          ),
                          Text('₹${booking.totalAmount.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.primaryTeal, fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),

                      // Nurse info (if accepted)
                      if (_nurse != null && booking.status != 'pending') ...[
                        const SizedBox(height: 16),
                        const Divider(color: AppTheme.bgCardLight),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: AppTheme.primaryTeal,
                              child: Text(
                                _nurse!.name.isNotEmpty ? _nurse!.name[0] : 'N',
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_nurse!.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                  Row(
                                    children: [
                                      const Icon(Icons.star, color: AppTheme.accentGold, size: 14),
                                      const SizedBox(width: 4),
                                      Text('${(_nurse!.rating ?? 0).toStringAsFixed(1)}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Call button
                            Container(
                              decoration: BoxDecoration(
                                color: AppTheme.success.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.call, color: AppTheme.success),
                                onPressed: () {},
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Chat button
                            Container(
                              decoration: BoxDecoration(
                                color: AppTheme.info.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.chat, color: AppTheme.info),
                                onPressed: () {},
                              ),
                            ),
                          ],
                        ),
                        // ETA
                        if (nurseLocation != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.directions_walk, color: AppTheme.primaryTeal, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'ETA: ${locationProvider.getETATo(nurseLocation)} • ${locationProvider.getDistanceTo(nurseLocation)} away',
                                  style: const TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],

                      const SizedBox(height: 16),

                      // Action buttons
                      if (booking.status == 'pending')
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              bookingProvider.cancelBooking(booking.id, 'Patient cancelled');
                              Navigator.pushReplacementNamed(context, AppRoutes.patientHome);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.error,
                              side: const BorderSide(color: AppTheme.error),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Cancel Booking'),
                          ),
                        ),

                      if (booking.status == 'in_progress')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              _showCompleteDialog(bookingProvider, booking.id, booking.nurseId!);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.success,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Mark Service Completed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCompleteDialog(BookingProvider bookingProvider, String bookingId, String nurseId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Complete Service?', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure the service is completed? Payment will be processed.', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Not Yet')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await bookingProvider.markCompleted(bookingId, nurseId);
              if (mounted) {
                Navigator.pushReplacementNamed(context, AppRoutes.rating, arguments: {
                  'bookingId': bookingId,
                  'nurseId': nurseId,
                });
              }
            },
            child: const Text('Yes, Complete'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(String status) {
    IconData icon;
    String text;
    Color color;
    
    switch (status) {
      case 'pending':
        icon = Icons.hourglass_top;
        text = 'Finding a nurse near you...';
        color = AppTheme.warning;
        break;
      case 'accepted':
        icon = Icons.check_circle;
        text = 'Nurse is on the way!';
        color = AppTheme.success;
        break;
      case 'in_progress':
        icon = Icons.medical_services;
        text = 'Service in progress';
        color = AppTheme.primaryTeal;
        break;
      case 'completed':
        icon = Icons.done_all;
        text = 'Service completed';
        color = AppTheme.success;
        break;
      default:
        icon = Icons.info;
        text = status;
        color = AppTheme.textMuted;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          if (status == 'pending') ...[
            const SizedBox(width: 8),
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: color)),
          ],
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return '🔍 Finding Nurse...';
      case 'accepted': return '✅ Nurse On The Way';
      case 'in_progress': return '🏥 Service In Progress';
      case 'completed': return '✨ Completed';
      default: return status;
    }
  }
}
