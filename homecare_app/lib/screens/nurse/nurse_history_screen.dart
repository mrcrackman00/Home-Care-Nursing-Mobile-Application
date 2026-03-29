import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/booking_provider.dart';

class NurseHistoryScreen extends StatelessWidget {
  const NurseHistoryScreen({super.key});

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
                    const Text('Job History', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Consumer<BookingProvider>(
                  builder: (context, provider, _) {
                    if (provider.bookings.isEmpty) {
                      return const Center(child: Text('No jobs yet', style: TextStyle(color: AppTheme.textMuted)));
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
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _getColor(booking.status).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  booking.status == 'completed' ? Icons.check_circle : Icons.pending,
                                  color: _getColor(booking.status),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(booking.serviceName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                    Text('${booking.createdAt.day}/${booking.createdAt.month}/${booking.createdAt.year}',
                                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                                    Text(booking.status.toUpperCase(),
                                      style: TextStyle(color: _getColor(booking.status), fontSize: 11, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('+₹${booking.nurseEarning.toStringAsFixed(0)}',
                                    style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 16)),
                                  if (booking.rating != null)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star, color: AppTheme.accentGold, size: 14),
                                        Text('${booking.rating!.toStringAsFixed(1)}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                      ],
                                    ),
                                ],
                              ),
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

  Color _getColor(String status) {
    switch (status) {
      case 'completed': return AppTheme.success;
      case 'cancelled': return AppTheme.error;
      case 'in_progress': return AppTheme.primaryTeal;
      default: return AppTheme.warning;
    }
  }
}
