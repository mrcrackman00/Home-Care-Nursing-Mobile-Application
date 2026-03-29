import 'package:flutter/material.dart';

import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../widgets/healthcare_ui.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HealthcareBackground(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Spacer(),
              FrostCard(
                padding: const EdgeInsets.all(28),
                borderRadius: BorderRadius.circular(28),
                gradient: AppTheme.primaryGradient,
                boxShadow: AppTheme.elevatedShadow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const SizedBox(
                        width: 84,
                        height: 84,
                        child: Icon(
                          Icons.medical_services_rounded,
                          size: 38,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Choose your role',
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Switch between a premium patient experience and a powerful nurse operations dashboard.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.76),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _RoleCard(
                icon: Icons.person_rounded,
                title: 'Patient App',
                subtitle: 'Book nearby nurses and manage live care visits',
                accent: AppTheme.accent,
                onTap: () {
                  Navigator.pushReplacementNamed(context, AppRoutes.patientHome);
                },
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.local_hospital_rounded,
                title: 'Nurse App',
                subtitle: 'Accept requests, navigate live, and track earnings',
                accent: AppTheme.success,
                onTap: () {
                  Navigator.pushReplacementNamed(context, AppRoutes.nurseHome);
                },
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FrostCard(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(20),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: SizedBox(
              width: 56,
              height: 56,
              child: Icon(icon, color: accent, size: 28),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            color: AppTheme.textDisabled,
            size: 18,
          ),
        ],
      ),
    );
  }
}
