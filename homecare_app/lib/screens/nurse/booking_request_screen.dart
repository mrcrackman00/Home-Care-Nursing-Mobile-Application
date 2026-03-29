import 'package:flutter/material.dart';

import '../../widgets/healthcare_ui.dart';

class BookingRequestScreen extends StatelessWidget {
  const BookingRequestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HealthcareBackground(
        child: const EmptyStateView(
          icon: Icons.notifications_active_outlined,
          title: 'Requests live on the nurse home tab',
          subtitle:
              'Incoming patient requests are now presented directly inside the redesigned nurse dashboard for faster decisions.',
        ),
      ),
    );
  }
}
