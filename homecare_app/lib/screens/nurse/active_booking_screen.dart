import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../config/theme.dart';
import '../../providers/booking_provider.dart';
import '../../providers/location_provider.dart';

class ActiveBookingScreen extends StatefulWidget {
  const ActiveBookingScreen({super.key});

  @override
  State<ActiveBookingScreen> createState() => _ActiveBookingScreenState();
}

class _ActiveBookingScreenState extends State<ActiveBookingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bookingId = ModalRoute.of(context)!.settings.arguments as String?;
      if (bookingId != null) {
        final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
        bookingProvider.listenToBooking(bookingId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer2<BookingProvider, LocationProvider>(
        builder: (context, bookingProvider, locationProvider, _) {
          final booking = bookingProvider.activeBooking;
          if (booking == null) {
            return Container(
              decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
              child: const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal)),
            );
          }

          final patientLocation = LatLng(booking.patientLocation.latitude, booking.patientLocation.longitude);
          final nurseLocation = locationProvider.currentLocation ?? patientLocation;

          return Stack(
            children: [
              // Map showing route
              FlutterMap(
                options: MapOptions(initialCenter: nurseLocation, initialZoom: 14),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.homecare.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: patientLocation,
                        width: 40, height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.error,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(Icons.person, color: Colors.white, size: 20),
                        ),
                      ),
                      Marker(
                        point: nurseLocation,
                        width: 40, height: 40,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.medical_services, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                  // Route line
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [nurseLocation, patientLocation],
                        strokeWidth: 3,
                        color: AppTheme.primaryTeal,
                      ),
                    ],
                  ),
                ],
              ),

              // Back button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    decoration: BoxDecoration(color: AppTheme.bgCard, shape: BoxShape.circle, boxShadow: AppTheme.cardShadow),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ),

              // Bottom details
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, -5))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: AppTheme.bgCardLight, borderRadius: BorderRadius.circular(2))),
                      
                      // Service + Patient
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(booking.serviceName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('Patient: ${booking.patientName}', style: const TextStyle(color: AppTheme.textSecondary)),
                            ],
                          ),
                          Text('₹${booking.nurseEarning.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.success, fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ETA
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.navigation, color: AppTheme.primaryTeal, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              '${locationProvider.getDistanceTo(patientLocation)} • ETA: ${locationProvider.getETATo(patientLocation)}',
                              style: const TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Action buttons
                      Row(
                        children: [
                          // Call
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.call, size: 18),
                              label: const Text('Call'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.success,
                                side: const BorderSide(color: AppTheme.success),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Chat
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.chat, size: 18),
                              label: const Text('Chat'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.info,
                                side: const BorderSide(color: AppTheme.info),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Start/Complete service
                      if (booking.status == 'accepted')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => bookingProvider.startService(booking.id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryTeal,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Start Service', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),

                      if (booking.status == 'in_progress')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              // Nurse waits for patient to mark complete
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Waiting for patient to confirm completion')),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.success,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Service In Progress...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
}
