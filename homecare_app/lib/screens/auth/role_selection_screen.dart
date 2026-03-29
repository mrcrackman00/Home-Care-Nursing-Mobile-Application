import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.medical_services_rounded, size: 40, color: Colors.white),
                ),
                const SizedBox(height: 24),
                Text('HomeCare', style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 8),
                const Text('Choose your role', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                const SizedBox(height: 48),
                _RoleCard(
                  icon: Icons.person_rounded,
                  title: 'Patient',
                  subtitle: 'Book nurses for home care',
                  gradient: AppTheme.primaryGradient,
                  onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.patientHome),
                ),
                const SizedBox(height: 16),
                _RoleCard(
                  icon: Icons.medical_services_rounded,
                  title: 'Nurse',
                  subtitle: 'Accept care requests & earn',
                  gradient: AppTheme.goldGradient,
                  onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.nurseHome),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.bgCardLight),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: AppTheme.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}
