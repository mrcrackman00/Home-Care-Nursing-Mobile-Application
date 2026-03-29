import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/location_provider.dart';

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
    final service = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    if (service == null) {
      return const Scaffold(body: Center(child: Text('No service selected')));
    }

    _selectedPrice = _selectedPrice == 0 ? (service['basePrice'] as int).toDouble() : _selectedPrice;
    final nurseEarning = service['noCommission'] == true
        ? _selectedPrice
        : AppConstants.calculateNurseEarning(_selectedPrice);
    final commission = service['noCommission'] == true
        ? 0.0
        : AppConstants.calculateCommission(_selectedPrice);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    const Text('Book Service', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Service Info Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Text(service['emoji'] ?? '🏥', style: const TextStyle(fontSize: 40)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(service['name'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(service['description'], style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text('Duration: ${service['duration']}', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Booking Type
                      const Text('Booking Type', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isInstant = true),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  gradient: _isInstant ? AppTheme.primaryGradient : null,
                                  color: _isInstant ? null : AppTheme.bgCard,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.flash_on, color: _isInstant ? Colors.white : AppTheme.textMuted),
                                    const SizedBox(height: 4),
                                    Text('Instant', style: TextStyle(color: _isInstant ? Colors.white : AppTheme.textMuted, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isInstant = false),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  gradient: !_isInstant ? AppTheme.primaryGradient : null,
                                  color: !_isInstant ? null : AppTheme.bgCard,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.schedule, color: !_isInstant ? Colors.white : AppTheme.textMuted),
                                    const SizedBox(height: 4),
                                    Text('Schedule', style: TextStyle(color: !_isInstant ? Colors.white : AppTheme.textMuted, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Schedule picker
                      if (!_isInstant) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now().add(const Duration(hours: 1)),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(const Duration(days: 30)),
                                  );
                                  if (date != null) setState(() => _scheduledDate = date);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppTheme.bgCard,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today, color: AppTheme.primaryTeal, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        _scheduledDate != null
                                            ? '${_scheduledDate!.day}/${_scheduledDate!.month}/${_scheduledDate!.year}'
                                            : 'Select Date',
                                        style: const TextStyle(color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.now(),
                                  );
                                  if (time != null) setState(() => _scheduledTime = time);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppTheme.bgCard,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.access_time, color: AppTheme.primaryTeal, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        _scheduledTime != null
                                            ? _scheduledTime!.format(context)
                                            : 'Select Time',
                                        style: const TextStyle(color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Location
                      const Text('Location', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => setState(() => _useCurrentLocation = true),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _useCurrentLocation ? AppTheme.primaryTeal.withValues(alpha: 0.15) : AppTheme.bgCard,
                            borderRadius: BorderRadius.circular(12),
                            border: _useCurrentLocation ? Border.all(color: AppTheme.primaryTeal) : null,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.my_location, color: _useCurrentLocation ? AppTheme.primaryTeal : AppTheme.textMuted),
                              const SizedBox(width: 12),
                              const Text('Use Current Location', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => setState(() => _useCurrentLocation = false),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: !_useCurrentLocation ? AppTheme.primaryTeal.withValues(alpha: 0.15) : AppTheme.bgCard,
                            borderRadius: BorderRadius.circular(12),
                            border: !_useCurrentLocation ? Border.all(color: AppTheme.primaryTeal) : null,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.edit_location_alt, color: !_useCurrentLocation ? AppTheme.primaryTeal : AppTheme.textMuted),
                              const SizedBox(width: 12),
                              const Text('Enter Address Manually', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                      if (!_useCurrentLocation) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _addressController,
                          style: const TextStyle(color: Colors.white),
                          maxLines: 2,
                          decoration: const InputDecoration(
                            hintText: 'Enter your full address',
                            prefixIcon: Icon(Icons.location_on, color: AppTheme.primaryTeal),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Price Slider
                      const Text('Select Price', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '₹${_selectedPrice.toStringAsFixed(0)}',
                              style: const TextStyle(color: AppTheme.primaryTeal, fontSize: 36, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            Slider(
                              value: _selectedPrice,
                              min: (service['basePrice'] as int).toDouble(),
                              max: (service['maxPrice'] as int).toDouble(),
                              divisions: ((service['maxPrice'] as int) - (service['basePrice'] as int)) ~/ 100,
                              activeColor: AppTheme.primaryTeal,
                              inactiveColor: AppTheme.bgCardLight,
                              onChanged: (v) => setState(() => _selectedPrice = v),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('₹${service['basePrice']}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                                Text('₹${service['maxPrice']}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Price Breakdown
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            _buildBreakdownRow('Service Charge', '₹${_selectedPrice.toStringAsFixed(0)}'),
                            const Divider(color: AppTheme.bgCardLight, height: 20),
                            _buildBreakdownRow('Platform Fee', '₹${commission.toStringAsFixed(0)}', valueColor: AppTheme.textMuted),
                            _buildBreakdownRow('Nurse Receives', '₹${nurseEarning.toStringAsFixed(0)}', valueColor: AppTheme.success),
                            const Divider(color: AppTheme.bgCardLight, height: 20),
                            _buildBreakdownRow(
                              'Total',
                              '₹${_selectedPrice.toStringAsFixed(0)}',
                              isBold: true,
                              valueColor: AppTheme.primaryTeal,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // Book Now FAB
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, -5))],
        ),
        child: SafeArea(
          child: Consumer<BookingProvider>(
            builder: (context, bookingProvider, _) {
              return SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: bookingProvider.isLoading ? null : () => _createBooking(service),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: bookingProvider.isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Book Now', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            color: isBold ? Colors.white : AppTheme.textSecondary,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          )),
          Text(value, style: TextStyle(
            color: valueColor ?? Colors.white,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            fontSize: isBold ? 18 : 14,
          )),
        ],
      ),
    );
  }

  Future<void> _createBooking(Map<String, dynamic> service) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);

    if (authProvider.user == null) return;

    GeoPoint location;
    String address;

    if (_useCurrentLocation) {
      final geoPoint = await locationProvider.currentLocation;
      if (geoPoint == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to get location')),
        );
        return;
      }
      location = GeoPoint(geoPoint.latitude, geoPoint.longitude);
      address = 'Current Location';
    } else {
      if (_addressController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your address')),
        );
        return;
      }
      location = const GeoPoint(28.6139, 77.2090); // Default fallback
      address = _addressController.text;
    }

    DateTime? scheduled;
    if (!_isInstant && _scheduledDate != null && _scheduledTime != null) {
      scheduled = DateTime(
        _scheduledDate!.year, _scheduledDate!.month, _scheduledDate!.day,
        _scheduledTime!.hour, _scheduledTime!.minute,
      );
    }

    final bookingId = await bookingProvider.createBooking(
      patient: authProvider.user!,
      service: service,
      location: location,
      address: address,
      price: _selectedPrice,
      isInstant: _isInstant,
      scheduledTime: scheduled,
    );

    if (bookingId != null && mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.tracking, arguments: bookingId);
    }
  }
}
