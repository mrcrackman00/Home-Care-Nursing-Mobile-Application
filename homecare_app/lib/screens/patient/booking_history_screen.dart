import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/booking_provider.dart';

class BookingHistoryScreen extends StatelessWidget {
  const BookingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios, color: Colors.white)),
                    const Text('Booking History', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Consumer<BookingProvider>(
                  builder: (context, provider, _) {
                    if (provider.bookings.isEmpty) {
                      return const Center(
                        child: Text('No bookings yet', style: TextStyle(color: AppTheme.textMuted)),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: provider.bookings.length,
                      itemBuilder: (context, index) {
                        final booking = provider.bookings[index];
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
                                  Text(booking.serviceName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(booking.status).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      booking.status.toUpperCase(),
                                      style: TextStyle(color: _getStatusColor(booking.status), fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 14, color: AppTheme.textMuted),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${booking.createdAt.day}/${booking.createdAt.month}/${booking.createdAt.year}',
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                  ),
                                  const SizedBox(width: 16),
                                  Text('₹${booking.totalAmount.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              if (booking.nurseName != null) ...[
                                const SizedBox(height: 6),
                                Text('Nurse: ${booking.nurseName}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                              ],
                              if (booking.rating != null) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: List.generate(5, (i) => Icon(
                                    i < booking.rating! ? Icons.star : Icons.star_border,
                                    color: AppTheme.accentGold,
                                    size: 16,
                                  )),
                                ),
                              ],
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
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed': return AppTheme.success;
      case 'cancelled': return AppTheme.error;
      case 'pending': return AppTheme.warning;
      case 'in_progress': return AppTheme.primaryTeal;
      default: return AppTheme.textMuted;
    }
  }
}
