import 'package:flutter/material.dart';
import '../../config/theme.dart';

class NurseProfileScreen extends StatelessWidget {
  const NurseProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nurse Profile')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: const Center(child: Text('Profile shown on home screen', style: TextStyle(color: AppTheme.textSecondary))),
      ),
    );
  }
}
