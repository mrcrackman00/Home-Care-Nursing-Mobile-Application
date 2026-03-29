import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../widgets/healthcare_ui.dart';

class NurseHistoryScreen extends StatefulWidget {
  const NurseHistoryScreen({super.key});

  @override
  State<NurseHistoryScreen> createState() => _NurseHistoryScreenState();
}

class _NurseHistoryScreenState extends State<NurseHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nurseId = context.read<AuthProvider>().user?.uid;
      if (nurseId != null) {
        context.read<BookingProvider>().listenToNurseBookings(nurseId);
      }
    });
  }

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
                      title: 'Job history',
                      subtitle:
                          'Review completed visits, ongoing assignments, and payout-relevant service records.',
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
                        icon: Icons.history_rounded,
                        title: 'No service history yet',
                        subtitle:
                            'Accepted and completed assignments will start appearing here once you begin taking jobs.',
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: provider.bookings.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final booking = provider.bookings[index];
                        return _JobCard(
                          status: booking.status,
                          title: booking.serviceName,
                          patientName: booking.patientName,
                          address: booking.patientAddress,
                          earning: booking.nurseEarning,
                          duration: booking.duration,
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

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.status,
    required this.title,
    required this.patientName,
    required this.address,
    required this.earning,
    required this.duration,
    required this.date,
  });

  final String status;
  final String title;
  final String patientName;
  final String address;
  final double earning;
  final String duration;
  final String date;

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
                    Text('Patient: $patientName', style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 4),
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
                  label: 'Earning',
                  value: '₹${earning.toStringAsFixed(0)}',
                  color: AppTheme.success,
                  icon: Icons.currency_rupee_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppMetricTile(
                  label: 'Duration',
                  value: duration,
                  color: AppTheme.warning,
                  icon: Icons.schedule_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FrostCard(
            padding: const EdgeInsets.all(14),
            color: AppTheme.background,
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  color: AppTheme.accent,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(date, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
