import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/nurse_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/earning_provider.dart';
import '../../models/booking_model.dart';

class NurseHomeScreen extends StatefulWidget {
  const NurseHomeScreen({super.key});

  @override
  State<NurseHomeScreen> createState() => _NurseHomeScreenState();
}

class _NurseHomeScreenState extends State<NurseHomeScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _toggleController;

  @override
  void initState() {
    super.initState();
    _toggleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final nurseId = authProvider.user?.uid;
      if (nurseId != null) {
        final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
        bookingProvider.listenToPendingBookings();
        bookingProvider.listenToActiveNurseBooking(nurseId);
        
        final earningProvider = Provider.of<EarningProvider>(context, listen: false);
        earningProvider.listenToEarnings(nurseId);

        final locationProvider = Provider.of<LocationProvider>(context, listen: false);
        locationProvider.initialize();
      }
    });
  }

  @override
  void dispose() {
    _toggleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(),
          _buildRequestsTab(),
          _buildEarningsTab(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, -5))],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.notifications_rounded), label: 'Requests'),
            BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: 'Earnings'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }

  // ========== HOME TAB ==========
  Widget _buildHomeTab() {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Consumer3<AuthProvider, NurseProvider, EarningProvider>(
            builder: (context, authProvider, nurseProvider, earningProvider, _) {
              final user = authProvider.user;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppTheme.primaryTeal,
                        child: Text(
                          user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'N',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hello, ${user?.name ?? 'Nurse'} 👋', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                            Text(
                              nurseProvider.isOnline ? '🟢 Online' : '🔴 Offline',
                              style: TextStyle(
                                color: nurseProvider.isOnline ? AppTheme.success : AppTheme.error,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Notification bell
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.bgCard,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                          onPressed: () => setState(() => _currentIndex = 1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Online/Offline Toggle
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: nurseProvider.isOnline ? AppTheme.primaryGradient : null,
                      color: nurseProvider.isOnline ? null : AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: nurseProvider.isOnline ? AppTheme.elevatedShadow : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          nurseProvider.isOnline ? Icons.wifi : Icons.wifi_off,
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nurseProvider.isOnline ? 'You are Online' : 'You are Offline',
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                nurseProvider.isOnline
                                    ? 'Accepting booking requests'
                                    : 'Go online to receive bookings',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Transform.scale(
                          scale: 1.3,
                          child: Switch(
                            value: nurseProvider.isOnline,
                            onChanged: (value) {
                              if (user != null) {
                                nurseProvider.toggleOnlineStatus(user.uid, value);
                                final locationProvider = Provider.of<LocationProvider>(context, listen: false);
                                if (value) {
                                  locationProvider.startTracking(user.uid);
                                } else {
                                  locationProvider.stopTracking();
                                }
                              }
                            },
                            activeColor: Colors.white,
                            activeTrackColor: Colors.white.withValues(alpha: 0.3),
                            inactiveThumbColor: AppTheme.textMuted,
                            inactiveTrackColor: AppTheme.bgCardLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Quick Stats
                  Row(
                    children: [
                      Expanded(child: _buildQuickStat('Today', '₹${earningProvider.todayEarnings.toStringAsFixed(0)}', Icons.today, AppTheme.primaryTeal)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildQuickStat('Balance', '₹${(earningProvider.earnings?.withdrawableBalance ?? 0).toStringAsFixed(0)}', Icons.account_balance_wallet, AppTheme.success)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildQuickStat('Jobs', '${earningProvider.earnings?.totalJobs ?? 0}', Icons.work, AppTheme.accentGold)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Active Booking
                  Consumer<BookingProvider>(
                    builder: (context, bookingProvider, _) {
                      if (bookingProvider.activeBooking != null) {
                        return _buildActiveBookingCard(bookingProvider.activeBooking!, user?.uid ?? '');
                      }
                      return const SizedBox();
                    },
                  ),

                  // Quick Actions
                  const Text('Quick Actions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildActionCard('Earnings', Icons.bar_chart, AppTheme.primaryTeal, () => setState(() => _currentIndex = 2))),
                      const SizedBox(width: 12),
                      Expanded(child: _buildActionCard('Withdraw', Icons.payments, AppTheme.success, () => Navigator.pushNamed(context, AppRoutes.withdrawal))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildActionCard('History', Icons.history, AppTheme.info, () => Navigator.pushNamed(context, AppRoutes.nurseHistory))),
                      const SizedBox(width: 12),
                      Expanded(child: _buildActionCard('Profile', Icons.person, AppTheme.accentGold, () => setState(() => _currentIndex = 3))),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildActionCard(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveBookingCard(BookingModel booking, String nurseId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.medical_services, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Active Booking', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(booking.status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(booking.serviceName, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14)),
          Text('Patient: ${booking.patientName}', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
          Text('₹${booking.nurseEarning.toStringAsFixed(0)} earning', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.activeBooking, arguments: booking.id);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryTeal,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('View Details', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              if (booking.status == 'accepted') ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
                      bookingProvider.startService(booking.id);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Start Service', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ========== REQUESTS TAB ==========
  Widget _buildRequestsTab() {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Booking Requests', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: Consumer<BookingProvider>(
                builder: (context, bookingProvider, _) {
                  final pendingBookings = bookingProvider.bookings
                      .where((b) => b.status == 'pending' && b.nurseId == null)
                      .toList();

                  if (pendingBookings.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_rounded, size: 64, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          const Text('No pending requests', style: TextStyle(color: AppTheme.textMuted, fontSize: 16)),
                          const SizedBox(height: 8),
                          const Text('New requests will appear here', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: pendingBookings.length,
                    itemBuilder: (context, index) {
                      final booking = pendingBookings[index];
                      return _buildRequestCard(booking);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(BookingModel booking) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.notifications_active, color: AppTheme.primaryTeal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('New Request!', style: const TextStyle(color: AppTheme.primaryTeal, fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(booking.serviceName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Text(
                '₹${booking.nurseEarning.toStringAsFixed(0)}',
                style: const TextStyle(color: AppTheme.success, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Details
          _buildDetailRow(Icons.person, 'Patient', booking.patientName),
          _buildDetailRow(Icons.location_on, 'Location', booking.patientAddress),
          _buildDetailRow(Icons.timer, 'Duration', booking.duration),
          _buildDetailRow(Icons.schedule, 'Type', booking.isInstant ? 'Instant' : 'Scheduled'),
          const SizedBox(height: 16),
          // Earning breakdown
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Your Earning:', style: TextStyle(color: AppTheme.textSecondary)),
                Text('₹${booking.nurseEarning.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.success, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Accept / Reject
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    // Request goes to next nurse (just ignore)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Request declined')),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    final user = authProvider.user;
                    if (user != null) {
                      final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
                      bookingProvider.acceptBooking(booking.id, user.uid, user.name);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Accept ✓', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13))),
        ],
      ),
    );
  }

  // ========== EARNINGS TAB ==========
  Widget _buildEarningsTab() {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Consumer<EarningProvider>(
            builder: (context, earningProvider, _) {
              final earnings = earningProvider.earnings;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Earnings', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  // Total Earning Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: AppTheme.elevatedShadow,
                    ),
                    child: Column(
                      children: [
                        const Text('Total Earnings', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 8),
                        Text(
                          '₹${(earnings?.totalEarnings ?? 0).toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildEarningMini('Today', '₹${earningProvider.todayEarnings.toStringAsFixed(0)}'),
                            Container(width: 1, height: 30, color: Colors.white24),
                            _buildEarningMini('Weekly', '₹${earningProvider.weeklyEarnings.toStringAsFixed(0)}'),
                            Container(width: 1, height: 30, color: Colors.white24),
                            _buildEarningMini('Jobs', '${earnings?.totalJobs ?? 0}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Withdrawable Balance
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.account_balance_wallet, color: AppTheme.success),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Withdrawable Balance', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                              Text(
                                '₹${(earnings?.withdrawableBalance ?? 0).toStringAsFixed(0)}',
                                style: const TextStyle(color: AppTheme.success, fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pushNamed(context, AppRoutes.withdrawal),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Withdraw'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Recent Transactions
                  const Text('Recent Transactions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  ...earningProvider.transactions.take(10).map((txn) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: txn.type == 'earning'
                                ? AppTheme.success.withValues(alpha: 0.15)
                                : AppTheme.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            txn.type == 'earning' ? Icons.arrow_downward : Icons.arrow_upward,
                            color: txn.type == 'earning' ? AppTheme.success : AppTheme.warning,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(txn.description ?? txn.type.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 14)),
                              Text(
                                '${txn.timestamp.day}/${txn.timestamp.month}/${txn.timestamp.year}',
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${txn.type == 'earning' ? '+' : '-'}₹${txn.amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: txn.type == 'earning' ? AppTheme.success : AppTheme.warning,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )),
                  if (earningProvider.transactions.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No transactions yet', style: TextStyle(color: AppTheme.textMuted)),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEarningMini(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
      ],
    );
  }

  // ========== PROFILE TAB ==========
  Widget _buildProfileTab() {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
      child: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            final user = authProvider.user;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppTheme.primaryTeal,
                    child: Text(
                      user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'N',
                      style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(user?.name ?? 'Nurse', style: Theme.of(context).textTheme.headlineMedium),
                  Text(user?.email ?? '', style: const TextStyle(color: AppTheme.textSecondary)),
                  if (user?.verified == true) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, color: AppTheme.success, size: 16),
                          SizedBox(width: 4),
                          Text('Verified', style: TextStyle(color: AppTheme.success, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, color: AppTheme.accentGold, size: 18),
                      const SizedBox(width: 4),
                      Text('${(user?.rating ?? 0).toStringAsFixed(1)} (${user?.totalRatings ?? 0} ratings)',
                        style: const TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildProfileMenuItem(Icons.person_outline, 'Edit Profile', () {}),
                  _buildProfileMenuItem(Icons.history, 'Job History', () => Navigator.pushNamed(context, AppRoutes.nurseHistory)),
                  _buildProfileMenuItem(Icons.account_balance, 'Bank Details', () => Navigator.pushNamed(context, AppRoutes.withdrawal)),
                  _buildProfileMenuItem(Icons.help_outline, 'Help & Support', () {}),
                  _buildProfileMenuItem(Icons.info_outline, 'About', () {}),
                  const SizedBox(height: 16),
                  _buildProfileMenuItem(
                    Icons.logout,
                    'Logout',
                    () async {
                      // Go offline first
                      final nurseProvider = Provider.of<NurseProvider>(context, listen: false);
                      if (user != null) {
                        await nurseProvider.toggleOnlineStatus(user.uid, false);
                      }
                      await authProvider.logout();
                      if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
                    },
                    isDestructive: true,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileMenuItem(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: isDestructive ? AppTheme.error : AppTheme.primaryTeal),
        title: Text(title, style: TextStyle(color: isDestructive ? AppTheme.error : Colors.white)),
        trailing: Icon(Icons.chevron_right, color: isDestructive ? AppTheme.error : AppTheme.textMuted),
        tileColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
