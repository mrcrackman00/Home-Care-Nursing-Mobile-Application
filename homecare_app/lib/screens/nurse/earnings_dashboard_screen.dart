import 'package:flutter/material.dart';

import '../../widgets/healthcare_ui.dart';

class EarningsDashboardScreen extends StatelessWidget {
  const EarningsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HealthcareBackground(
        child: const EmptyStateView(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Earnings live on the nurse home tab',
          subtitle:
              'The new nurse dashboard already includes the redesigned earnings experience with balance, stats, and transactions.',
        ),
      ),
    );
  }
}
