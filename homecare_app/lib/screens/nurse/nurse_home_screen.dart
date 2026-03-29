import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../models/booking_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/earning_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/nurse_provider.dart';
import '../../widgets/healthcare_ui.dart';

class NurseHomeScreen extends StatefulWidget {
  const NurseHomeScreen({super.key});
  @override
  State<NurseHomeScreen> createState() => _NurseHomeScreenState();
}

class _NurseHomeScreenState extends State<NurseHomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final nurseId = auth.user?.uid;
      if (nurseId != null) {
        context.read<BookingProvider>().listenToPendingBookings(nurseId);
        context.read<BookingProvider>().listenToActiveNurseBooking(nurseId);
        context.read<EarningProvider>().listenToEarnings(nurseId);
        context.read<LocationProvider>().initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: IndexedStack(
        index: _currentIndex,
        children: [_homeTab(), _requestsTab(), _earningsTab(), _profileTab()],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          AppBottomNavItem(label: 'Home', icon: Icons.home_outlined, activeIcon: Icons.home),
          AppBottomNavItem(label: 'Requests', icon: Icons.notifications_outlined, activeIcon: Icons.notifications),
          AppBottomNavItem(label: 'Earnings', icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet),
          AppBottomNavItem(label: 'Profile', icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded),
        ],
      ),
    );
  }

  Widget _homeTab() {
    return HealthcareBackground(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Consumer3<AuthProvider, NurseProvider, EarningProvider>(
          builder: (context, auth, nurseProvider, earningProvider, _) {
            final user = auth.user;
            final balance = earningProvider.earnings?.withdrawableBalance ?? 0;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.accentLight,
                  child: Text(user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'N', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.accent)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Hello, ${user?.name ?? 'Nurse'}', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  StatusPill(label: nurseProvider.isOnline ? 'Online' : 'Offline', color: nurseProvider.isOnline ? AppTheme.success : AppTheme.error),
                ])),
                TopGlassButton(icon: Icons.notifications_outlined, onPressed: () => setState(() => _currentIndex = 1)),
              ]),
              const SizedBox(height: 20),
              FrostCard(
                padding: const EdgeInsets.all(20),
                borderRadius: BorderRadius.circular(20),
                gradient: nurseProvider.isOnline ? AppTheme.primaryGradient : null,
                color: nurseProvider.isOnline ? null : AppTheme.surface,
                borderColor: nurseProvider.isOnline ? Colors.transparent : AppTheme.divider,
                boxShadow: nurseProvider.isOnline ? AppTheme.elevatedShadow : AppTheme.cardShadow,
                child: Row(children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: nurseProvider.isOnline ? Colors.white.withValues(alpha: 0.12) : AppTheme.accentLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: Icon(nurseProvider.isOnline ? Icons.wifi_tethering_rounded : Icons.wifi_off_rounded, color: nurseProvider.isOnline ? Colors.white : AppTheme.accent),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(nurseProvider.isOnline ? 'You are live for nearby bookings' : 'Go online to receive requests', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: nurseProvider.isOnline ? Colors.white : AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Text(nurseProvider.isOnline ? 'Patients around you can now see and request your profile in real time.' : 'Turn on availability and let the dispatch engine start routing requests to you.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: nurseProvider.isOnline ? Colors.white.withValues(alpha: 0.76) : AppTheme.textSecondary)),
                  ])),
                  Switch(
                    value: nurseProvider.isOnline,
                    onChanged: (value) {
                      if (user == null) return;
                      nurseProvider.toggleOnlineStatus(user.uid, value);
                      final location = context.read<LocationProvider>();
                      if (value) {
                        location.startTracking(user.uid);
                      } else {
                        location.stopTracking();
                      }
                    },
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: AppMetricTile(label: 'Today', value: '₹${earningProvider.todayEarnings.toStringAsFixed(0)}', color: AppTheme.accent, icon: Icons.today_outlined)),
                const SizedBox(width: 12),
                Expanded(child: AppMetricTile(label: 'Balance', value: '₹${balance.toStringAsFixed(0)}', color: AppTheme.success, icon: Icons.account_balance_wallet_outlined)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: AppMetricTile(label: 'Weekly', value: '₹${earningProvider.weeklyEarnings.toStringAsFixed(0)}', color: AppTheme.warning, icon: Icons.bar_chart_rounded)),
                const SizedBox(width: 12),
                Expanded(child: AppMetricTile(label: 'Jobs', value: '${earningProvider.earnings?.totalJobs ?? 0}', color: AppTheme.primary, icon: Icons.work_outline_rounded)),
              ]),
              if (context.watch<BookingProvider>().activeBooking != null) ...[
                const SizedBox(height: 20),
                _ActiveBookingCard(booking: context.watch<BookingProvider>().activeBooking!),
              ],
              const SizedBox(height: 20),
              Text('Quick actions', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _QuickAction(icon: Icons.account_balance_wallet_outlined, title: 'Withdraw', accent: AppTheme.success, onTap: () => Navigator.pushNamed(context, AppRoutes.withdrawal))),
                const SizedBox(width: 12),
                Expanded(child: _QuickAction(icon: Icons.history_rounded, title: 'History', accent: AppTheme.warning, onTap: () => Navigator.pushNamed(context, AppRoutes.nurseHistory))),
              ]),
            ]);
          },
        ),
      ),
    );
  }

  Widget _requestsTab() {
    return HealthcareBackground(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeading(title: 'Incoming requests', subtitle: 'Review nearby patient requests and accept the ones that match your availability.'),
          const SizedBox(height: 20),
          Expanded(
            child: Consumer2<BookingProvider, AuthProvider>(
              builder: (context, bookingProvider, auth, _) {
                if (bookingProvider.bookings.isEmpty) {
                  return const EmptyStateView(icon: Icons.inbox_outlined, title: 'No pending requests', subtitle: 'New nearby service requests will appear here once patients start booking.');
                }
                final nurseId = auth.user?.uid;
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: bookingProvider.bookings.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) => _RequestCard(
                    booking: bookingProvider.bookings[index],
                    onAccept: () async {
                      final user = auth.user;
                      if (user == null) return;
                      await bookingProvider.acceptBooking(bookingProvider.bookings[index].id, user.uid, user.name);
                    },
                    onReject: () async {
                      if (nurseId == null) return;
                      await bookingProvider.rejectBooking(bookingProvider.bookings[index].id, nurseId);
                    },
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _earningsTab() {
    return HealthcareBackground(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Consumer<EarningProvider>(
          builder: (context, provider, _) {
            final earnings = provider.earnings;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionHeading(title: 'Earnings dashboard', subtitle: 'Monitor your balance, weekly performance, and recent money movement in one place.'),
              const SizedBox(height: 20),
              FrostCard(
                padding: const EdgeInsets.all(24),
                borderRadius: BorderRadius.circular(20),
                gradient: AppTheme.primaryGradient,
                boxShadow: AppTheme.elevatedShadow,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Withdrawable balance', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.7))),
                  const SizedBox(height: 8),
                  AnimatedAmountText(amount: earnings?.withdrawableBalance ?? 0, size: 38, color: Colors.white),
                  const SizedBox(height: 16),
                  TapScale(
                    onTap: () => Navigator.pushNamed(context, AppRoutes.withdrawal),
                    child: OutlinedButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.withdrawal), style: OutlinedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppTheme.accent), child: const Text('Withdraw money')),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.35,
                children: [
                  AppMetricTile(label: 'Today', value: '₹${provider.todayEarnings.toStringAsFixed(0)}', color: AppTheme.accent, icon: Icons.today_outlined),
                  AppMetricTile(label: 'Weekly', value: '₹${provider.weeklyEarnings.toStringAsFixed(0)}', color: AppTheme.warning, icon: Icons.show_chart_rounded),
                  AppMetricTile(label: 'Monthly', value: '₹${(earnings?.totalEarnings ?? 0).toStringAsFixed(0)}', color: AppTheme.success, icon: Icons.calendar_month_outlined),
                  AppMetricTile(label: 'Jobs', value: '${earnings?.totalJobs ?? 0}', color: AppTheme.primary, icon: Icons.work_outline_rounded),
                ],
              ),
              const SizedBox(height: 20),
              Text('Recent transactions', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (provider.transactions.isEmpty) const EmptyStateView(icon: Icons.receipt_long_outlined, title: 'No transactions yet', subtitle: 'Completed jobs and withdrawals will show up here once your earnings begin to move.')
              else ...provider.transactions.take(10).map((txn) {
                final incoming = txn.type == 'earning';
                final tone = incoming ? AppTheme.success : AppTheme.warning;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FrostCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      DecoratedBox(
                        decoration: BoxDecoration(color: tone.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                        child: SizedBox(width: 40, height: 40, child: Icon(incoming ? Icons.south_west_rounded : Icons.north_east_rounded, color: tone, size: 18)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(txn.description ?? txn.type.toUpperCase(), style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: 4),
                        Text('${txn.timestamp.day}/${txn.timestamp.month}/${txn.timestamp.year}', style: Theme.of(context).textTheme.labelSmall),
                      ])),
                      AppAmountText('${incoming ? '+' : '-'}₹${txn.amount.toStringAsFixed(0)}', color: tone, size: 15),
                    ]),
                  ),
                );
              }),
            ]);
          },
        ),
      ),
    );
  }

  Widget _profileTab() {
    return HealthcareBackground(
      child: Consumer2<AuthProvider, NurseProvider>(
        builder: (context, authProvider, nurseProvider, _) {
          final user = authProvider.user;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FrostCard(
                padding: const EdgeInsets.all(24),
                borderRadius: BorderRadius.circular(24),
                gradient: AppTheme.primaryGradient,
                boxShadow: AppTheme.elevatedShadow,
                child: Row(children: [
                  CircleAvatar(radius: 34, backgroundColor: Colors.white.withValues(alpha: 0.12), child: Text(user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'N', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white))),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user?.name ?? 'Nurse', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(user?.email ?? '', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.76))),
                    const SizedBox(height: 10),
                    Row(children: [
                      StatusPill(label: user?.verified == true ? 'Verified' : 'Pending verification', color: user?.verified == true ? AppTheme.success : AppTheme.warning),
                      const SizedBox(width: 8),
                      StatusPill(label: nurseProvider.isOnline ? 'Online' : 'Offline', color: nurseProvider.isOnline ? AppTheme.success : AppTheme.error),
                    ]),
                  ])),
                ]),
              ),
              const SizedBox(height: 20),
              _ProfileTile(icon: Icons.person_outline_rounded, title: 'Edit profile', subtitle: 'Update your professional details', onTap: () {}),
              const SizedBox(height: 12),
              _ProfileTile(icon: Icons.account_balance_outlined, title: 'Bank details', subtitle: 'Manage payout destination details', onTap: () => Navigator.pushNamed(context, AppRoutes.withdrawal)),
              const SizedBox(height: 12),
              _ProfileTile(icon: Icons.history_rounded, title: 'Job history', subtitle: 'Review completed assignments', onTap: () => Navigator.pushNamed(context, AppRoutes.nurseHistory)),
              const SizedBox(height: 12),
              _ProfileTile(icon: Icons.support_agent_outlined, title: 'Help & support', subtitle: 'Reach the operations team', onTap: () {}),
              const SizedBox(height: 20),
              FrostCard(
                onTap: () async {
                  if (user != null) await nurseProvider.toggleOnlineStatus(user.uid, false);
                  await authProvider.logout();
                  if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
                },
                padding: const EdgeInsets.all(18),
                color: const Color(0xFFFFF3F6),
                borderColor: AppTheme.error.withValues(alpha: 0.16),
                child: Row(children: [
                  const Icon(Icons.logout_rounded, color: AppTheme.error),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Log out', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppTheme.error))),
                  const Icon(Icons.chevron_right_rounded, color: AppTheme.error),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.title, required this.accent, required this.onTap});
  final IconData icon;
  final String title;
  final Color accent;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return FrostCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        DecoratedBox(
          decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: SizedBox(width: 40, height: 40, child: Icon(icon, color: accent, size: 18)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
      ]),
    );
  }
}

class _ActiveBookingCard extends StatelessWidget {
  const _ActiveBookingCard({required this.booking});
  final BookingModel booking;
  @override
  Widget build(BuildContext context) {
    return FrostCard(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(20),
      gradient: AppTheme.primaryGradient,
      boxShadow: AppTheme.elevatedShadow,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Active booking', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
          const Spacer(),
          const StatusPill(label: 'Live', color: Colors.white),
        ]),
        const SizedBox(height: 14),
        Text(booking.serviceName, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
        const SizedBox(height: 4),
        Text('Patient: ${booking.patientName}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.76))),
        const SizedBox(height: 12),
        AppAmountText('₹${booking.nurseEarning.toStringAsFixed(0)} expected earning', color: Colors.white, size: 18),
        const SizedBox(height: 14),
        TapScale(
          onTap: () => Navigator.pushNamed(context, AppRoutes.activeBooking, arguments: booking.id),
          child: OutlinedButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.activeBooking, arguments: booking.id),
            style: OutlinedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppTheme.accent),
            child: const Text('View details'),
          ),
        ),
      ]),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.booking, required this.onAccept, required this.onReject});
  final BookingModel booking;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  @override
  Widget build(BuildContext context) {
    return FrostCard(
      padding: const EdgeInsets.all(18),
      borderColor: AppTheme.accent.withValues(alpha: 0.18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          DecoratedBox(
            decoration: BoxDecoration(color: AppTheme.accentLight, borderRadius: BorderRadius.circular(12)),
            child: const SizedBox(width: 40, height: 40, child: Icon(Icons.notifications_active_outlined, color: AppTheme.accent, size: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(booking.serviceName, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Patient: ${booking.patientName}', style: Theme.of(context).textTheme.bodyMedium),
          ])),
          AppAmountText('₹${booking.nurseEarning.toStringAsFixed(0)}', color: AppTheme.success, size: 20),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          InfoChip(icon: Icons.location_on_outlined, label: booking.patientAddress),
          InfoChip(icon: Icons.schedule_rounded, label: booking.duration),
          InfoChip(icon: Icons.flash_on_rounded, label: booking.isInstant ? 'Instant' : 'Scheduled'),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: FrostCard(onTap: onReject, padding: const EdgeInsets.symmetric(vertical: 14), color: const Color(0xFFFFF3F6), borderColor: AppTheme.error.withValues(alpha: 0.18), child: Center(child: Text('Reject', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppTheme.error))))),
          const SizedBox(width: 12),
          Expanded(child: TapScale(onTap: onAccept, child: ElevatedButton(onPressed: onAccept, child: const Text('Accept')))),
        ]),
      ]),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return FrostCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(children: [
        DecoratedBox(
          decoration: BoxDecoration(color: AppTheme.accentLight, borderRadius: BorderRadius.circular(14)),
          child: SizedBox(width: 44, height: 44, child: Icon(icon, color: AppTheme.accent, size: 20)),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ])),
        const Icon(Icons.chevron_right_rounded, color: AppTheme.textDisabled),
      ]),
    );
  }
}
