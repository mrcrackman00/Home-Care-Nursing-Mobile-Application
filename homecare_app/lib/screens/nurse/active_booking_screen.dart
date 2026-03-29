import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/location_provider.dart';
import '../../widgets/healthcare_ui.dart';
import '../shared/chat_screen.dart';

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
        context.read<BookingProvider>().listenToBooking(bookingId);
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
            return const HealthcareBackground(child: Center(child: CircularProgressIndicator()));
          }

          final patientLocation = LatLng(booking.patientLocation.latitude, booking.patientLocation.longitude);
          final nurseLocation = locationProvider.currentLocation ?? patientLocation;

          return Stack(children: [
            FlutterMap(
              options: MapOptions(initialCenter: nurseLocation, initialZoom: 14),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.homecare.app',
                ),
                PolylineLayer(polylines: [Polyline(points: [nurseLocation, patientLocation], strokeWidth: 5, color: AppTheme.accent)]),
                MarkerLayer(markers: [
                  Marker(point: patientLocation, width: 44, height: 44, child: Container(decoration: BoxDecoration(color: AppTheme.error, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)), child: const Icon(Icons.home_rounded, color: Colors.white, size: 20))),
                  Marker(point: nurseLocation, width: 52, height: 52, child: DecoratedBox(decoration: const BoxDecoration(gradient: AppTheme.primaryGradient, shape: BoxShape.circle), child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 24))),
                ]),
              ],
            ),
            Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white.withValues(alpha: 0.38), Colors.transparent, AppTheme.background.withValues(alpha: 0.92)]))))),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(children: [
                  TopGlassButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => Navigator.pop(context)),
                  const SizedBox(width: 12),
                  Expanded(child: FrostCard(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: Text(booking.status == 'accepted' ? 'You are on the way to the patient' : 'Service is currently in progress', style: Theme.of(context).textTheme.titleSmall))),
                ]),
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
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(100)))),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(booking.serviceName, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text('Patient: ${booking.patientName}', style: Theme.of(context).textTheme.bodyMedium),
                    ])),
                    const SizedBox(width: 12),
                    StatusPill(label: booking.status.toUpperCase().replaceAll('_', ' '), color: booking.status == 'accepted' ? AppTheme.accent : const Color(0xFF7B4FEB)),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: AppMetricTile(label: 'Expected earning', value: '₹${booking.nurseEarning.toStringAsFixed(0)}', color: AppTheme.success, icon: Icons.currency_rupee_rounded)),
                    const SizedBox(width: 12),
                    Expanded(child: AppMetricTile(label: 'Distance / ETA', value: '${locationProvider.getDistanceTo(patientLocation)} / ${locationProvider.getETATo(patientLocation)}', color: AppTheme.accent, icon: Icons.navigation_outlined)),
                  ]),
                  const SizedBox(height: 16),
                  FrostCard(
                    padding: const EdgeInsets.all(14),
                    color: AppTheme.background,
                    child: Column(children: [
                      Row(children: [
                        const Icon(Icons.location_on_outlined, color: AppTheme.accent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(booking.patientAddress, style: Theme.of(context).textTheme.bodyMedium)),
                      ]),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(child: OutlinedButton.icon(onPressed: () => _launchPhone(booking.patientPhone), icon: const Icon(Icons.call_rounded, size: 18), label: const Text('Call'))),
                        const SizedBox(width: 12),
                        Expanded(child: OutlinedButton.icon(onPressed: () => _openChat(booking.id, booking.patientName), icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18), label: const Text('Chat'))),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  if (booking.status == 'accepted')
                    TapScale(onTap: () => bookingProvider.startService(booking.id), child: ElevatedButton(onPressed: () => bookingProvider.startService(booking.id), child: const Text('Start Service'))),
                  if (booking.status == 'in_progress')
                    TapScale(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Waiting for patient confirmation to complete the service.')));
                      },
                      child: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Waiting for patient confirmation to complete the service.')));
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                        child: const Text('Service In Progress'),
                      ),
                    ),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _openChat(String bookingId, String counterpartName) {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(threadId: bookingId, bookingId: bookingId, currentUserId: user.uid, currentUserName: user.name, counterpartName: counterpartName)));
  }
}
