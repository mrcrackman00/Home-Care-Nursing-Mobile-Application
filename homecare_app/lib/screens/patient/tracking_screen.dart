import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../widgets/healthcare_ui.dart';
import '../shared/chat_screen.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});
  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final _mapController = MapController();
  final _firestoreService = FirestoreService();

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

          if (booking.nurseId == null) {
            return _content(bookingProvider, locationProvider, booking, nurse: null);
          }

          return StreamBuilder<UserModel?>(
            stream: _firestoreService.streamUser(booking.nurseId!),
            builder: (context, snapshot) {
              return _content(bookingProvider, locationProvider, booking, nurse: snapshot.data);
            },
          );
        },
      ),
    );
  }

  Widget _content(BookingProvider bookingProvider, LocationProvider locationProvider, dynamic booking, {UserModel? nurse}) {
    final patientLocation = LatLng(booking.patientLocation.latitude, booking.patientLocation.longitude);
    final nurseLocation = nurse?.currentLocation != null ? LocationService.geoPointToLatLng(nurse!.currentLocation!) : null;
    return Stack(children: [
      FlutterMap(
        mapController: _mapController,
        options: MapOptions(initialCenter: nurseLocation ?? patientLocation, initialZoom: 14.5),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
            userAgentPackageName: 'com.homecare.app',
          ),
          if (nurseLocation != null)
            PolylineLayer(
              polylines: [Polyline(points: [nurseLocation, patientLocation], strokeWidth: 5, color: AppTheme.accent)],
            ),
          MarkerLayer(markers: [
            Marker(point: patientLocation, width: 46, height: 46, child: Container(decoration: BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4), boxShadow: AppTheme.cardShadow), child: const Icon(Icons.home_rounded, color: Colors.white, size: 20))),
            if (nurseLocation != null) Marker(point: nurseLocation, width: 54, height: 54, child: DecoratedBox(decoration: const BoxDecoration(gradient: AppTheme.primaryGradient, shape: BoxShape.circle), child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 26))),
          ]),
        ],
      ),
      Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white.withValues(alpha: 0.38), Colors.transparent, AppTheme.background.withValues(alpha: 0.92)]))))),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(children: [
            TopGlassButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () { bookingProvider.clearActive(); Navigator.pushReplacementNamed(context, AppRoutes.patientHome); }),
            const SizedBox(width: 12),
            Expanded(child: FrostCard(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: _statusColor(booking.status))),
              const SizedBox(width: 10),
              Expanded(child: Text(_statusTitle(booking.status), style: Theme.of(context).textTheme.titleSmall)),
            ]))),
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
                Text(_statusDescription(booking.status), style: Theme.of(context).textTheme.bodyMedium),
              ])),
              const SizedBox(width: 12),
              StatusPill(label: booking.status.toUpperCase().replaceAll('_', ' '), color: _statusColor(booking.status)),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: AppMetricTile(label: 'Total payable', value: '₹${booking.totalAmount.toStringAsFixed(0)}', color: AppTheme.accent, icon: Icons.currency_rupee_rounded)),
              const SizedBox(width: 12),
              Expanded(child: AppMetricTile(label: 'Duration', value: booking.duration, color: AppTheme.warning, icon: Icons.schedule_rounded)),
            ]),
            if (nurse != null && booking.status != 'pending') ...[
              const SizedBox(height: 16),
              FrostCard(
                padding: const EdgeInsets.all(16),
                color: AppTheme.background,
                child: Column(children: [
                  Row(children: [
                    CircleAvatar(radius: 28, backgroundColor: AppTheme.accentLight, child: Text(nurse.name.isNotEmpty ? nurse.name[0].toUpperCase() : 'N', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.accent))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(nurse.name, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('${(nurse.rating ?? 0).toStringAsFixed(1)} rating', style: Theme.of(context).textTheme.bodyMedium),
                    ])),
                    if (nurseLocation != null) Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(locationProvider.getDistanceTo(nurseLocation), style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppTheme.accent)),
                      Text('ETA ${locationProvider.getETATo(nurseLocation)}', style: Theme.of(context).textTheme.labelSmall),
                    ]),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(onPressed: () => _launchPhone(nurse.phone), icon: const Icon(Icons.call_rounded, size: 18), label: const Text('Call'))),
                    const SizedBox(width: 12),
                    Expanded(child: OutlinedButton.icon(onPressed: () => _openChat(booking.id, nurse.name), icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18), label: const Text('Chat'))),
                  ]),
                ]),
              ),
            ],
            const SizedBox(height: 16),
            if (booking.status == 'pending')
              TapScale(
                onTap: () async { await bookingProvider.cancelBooking(booking.id, 'Patient cancelled'); if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.patientHome); },
                child: FrostCard(
                  onTap: () async { await bookingProvider.cancelBooking(booking.id, 'Patient cancelled'); if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.patientHome); },
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  color: const Color(0xFFFFF3F6),
                  borderColor: AppTheme.error.withValues(alpha: 0.16),
                  child: Center(child: Text('Cancel Booking', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppTheme.error))),
                ),
              ),
            if (booking.status == 'in_progress')
              TapScale(
                onTap: () => _showCompleteDialog(bookingProvider, booking.id, booking.nurseId!),
                child: ElevatedButton(onPressed: () => _showCompleteDialog(bookingProvider, booking.id, booking.nurseId!), child: const Text('Mark Service Completed')),
              ),
          ]),
        ),
      ),
    ]);
  }

  void _showCompleteDialog(BookingProvider bookingProvider, String bookingId, String nurseId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete service?'),
        content: Text('Payment gateway is paused in this build. If you continue, the visit will close and the nurse settlement will be recorded securely in the backend.', style: Theme.of(context).textTheme.bodyMedium),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Not Yet')),
          ElevatedButton(onPressed: () { Navigator.pop(ctx); _finalizeCompletion(bookingProvider, bookingId, nurseId); }, child: const Text('Complete Service')),
        ],
      ),
    );
  }

  Future<void> _finalizeCompletion(BookingProvider bookingProvider, String bookingId, String nurseId) async {
    await bookingProvider.markCompleted(bookingId);
    if (!mounted) return;
    if (bookingProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(bookingProvider.error!)));
      return;
    }
    Navigator.pushReplacementNamed(context, AppRoutes.rating, arguments: {'bookingId': bookingId, 'nurseId': nurseId});
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

  String _statusTitle(String status) => switch (status) {
        'pending' => 'Finding the best nearby nurse',
        'accepted' => 'Nurse accepted your booking',
        'in_progress' => 'Service currently in progress',
        'completed' => 'Visit completed',
        _ => status,
      };
  String _statusDescription(String status) => switch (status) {
        'pending' => 'We are notifying available nurses around your location in real time.',
        'accepted' => 'Your nurse is preparing and heading to your address.',
        'in_progress' => 'Care is underway. Confirm completion once the visit ends.',
        'completed' => 'Thank you for choosing NurseCare. Please rate the experience.',
        _ => status,
      };
  Color _statusColor(String status) => switch (status) {
        'pending' => AppTheme.warning,
        'accepted' => AppTheme.accent,
        'in_progress' => const Color(0xFF7B4FEB),
        'completed' => AppTheme.success,
        _ => AppTheme.textDisabled,
      };
}
