import 'package:flutter/material.dart';

import '../../widgets/healthcare_ui.dart';

class PatientProfileScreen extends StatelessWidget {
  const PatientProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HealthcareBackground(
        child: const EmptyStateView(
          icon: Icons.person_outline_rounded,
          title: 'Profile lives on the home tab',
          subtitle:
              'The redesigned patient profile is available directly inside the bottom navigation experience.',
        ),
      ),
    );
  }
}
