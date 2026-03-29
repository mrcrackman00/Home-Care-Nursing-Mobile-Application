import 'package:flutter/material.dart';

import '../../widgets/healthcare_ui.dart';

class NurseProfileScreen extends StatelessWidget {
  const NurseProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HealthcareBackground(
        child: const EmptyStateView(
          icon: Icons.badge_outlined,
          title: 'Profile lives on the nurse dashboard',
          subtitle:
              'The redesigned nurse profile and verification controls are now embedded on the main home experience.',
        ),
      ),
    );
  }
}
