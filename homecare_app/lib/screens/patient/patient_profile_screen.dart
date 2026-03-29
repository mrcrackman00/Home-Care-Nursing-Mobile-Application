import 'package:flutter/material.dart';
import '../../config/theme.dart';

class PatientProfileScreen extends StatelessWidget {
  const PatientProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: const Center(child: Text('Profile Screen', style: TextStyle(color: Colors.white))),
      ),
    );
  }
}
