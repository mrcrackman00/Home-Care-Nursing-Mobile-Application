import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/booking_provider.dart';
import '../../widgets/healthcare_ui.dart';
import '../../config/theme.dart';

class BookingHistoryScreen extends StatelessWidget {
  const BookingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HealthcareBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TopGlassButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: SectionHeading(
                      title: 'Booking history',
                      subtitle:
                          'Review completed, ongoing, and cancelled care sessions in one premium timeline.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Consumer<BookingProvider>(
                  builder: (context, provider, _) {
                    if (provider.bookings.isEmpty) {
                      return const EmptyStateView(
                        icon: Icons.event_note_outlined,
                        title: 'No booking history yet',
                        subtitle:
                            'Your completed and ongoing care sessions will appear here after your first booking.',
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: provider.bookings.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final booking = provider.bookings[index];
                        return _HistoryCard(
                          status: booking.status,
                          title: booking.serviceName,
                          address: booking.patientAddress,
                          amount: booking.totalAmount,
                          duration: booking.duration,
                          nurseName: booking.nurseName,
                          rating: booking.rating,
                          date:
                              '${booking.createdAt.day}/${booking.createdAt.month}/${booking.createdAt.year}',
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
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.status,
    required this.title,
    required this.address,
    required this.amount,
    required this.duration,
    required this.date,
    this.nurseName,
    this.rating,
  });

  final String status;
  final String title;
  final String address;
  final double amount;
  final String duration;
  final String date;
  final String? nurseName;
  final double? rating;

  @override
  Widget build(BuildContext context) {
    final badge = switch (status) {
      'completed' => const StatusPill(label: 'Completed', color: AppTheme.success),
      'cancelled' => const StatusPill(label: 'Cancelled', color: AppTheme.error),
      'pending' => const StatusPill(label: 'Pending', color: AppTheme.warning),
      'in_progress' => const StatusPill(label: 'Ongoing', color: Color(0xFF7B4FEB)),
      'accepted' => const StatusPill(label: 'Confirmed', color: AppTheme.accent),
      _ => const StatusPill(label: 'Unknown', color: AppTheme.textDisabled),
    };

    return FrostCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(address, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              badge,
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppMetricTile(
                  label: 'Booked on',
                  value: date,
                  color: AppTheme.accent,
                  icon: Icons.calendar_today_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppMetricTile(
                  label: 'Total paid',
                  value: '₹${amount.toStringAsFixed(0)}',
                  color: AppTheme.success,
                  icon: Icons.currency_rupee_rounded,
                ),
              ),
            ],
          ),
          if (nurseName != null) ...[
            const SizedBox(height: 14),
            FrostCard(
              padding: const EdgeInsets.all(14),
              color: AppTheme.background,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.accentLight,
                    child: Text(
                      nurseName![0].toUpperCase(),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: AppTheme.accent),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nurseName!, style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 4),
                        Text(duration, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  if (rating != null)
                    Text(
                      '${rating!.toStringAsFixed(1)} ★',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: AppTheme.warning),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
