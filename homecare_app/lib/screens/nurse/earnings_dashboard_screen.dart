import 'package:flutter/material.dart';
import '../../config/theme.dart';

class EarningsDashboardScreen extends StatelessWidget {
  const EarningsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Earnings dashboard is shown inline on nurse home tab 2
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings Dashboard')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: const Center(child: Text('Earnings shown on home screen', style: TextStyle(color: AppTheme.textSecondary))),
      ),
    );
  }
}
