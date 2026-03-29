import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/routes.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/healthcare_ui.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _floatAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    Future.delayed(const Duration(seconds: 3), _navigateToNextScreen);
  }

  Future<void> _navigateToNextScreen() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.initialize();

    if (!mounted) {
      return;
    }

    if (authProvider.isLoggedIn && authProvider.user != null) {
      if (authProvider.user!.role == 'nurse') {
        Navigator.pushReplacementNamed(context, AppRoutes.nurseHome);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.patientHome);
      }
      return;
    }

    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HealthcareBackground(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const StatusPill(
                label: 'Premium Home Nursing',
                color: AppTheme.accent,
                icon: Icons.favorite_border_rounded,
              ),
              const Spacer(),
              FadeTransition(
                opacity: _fadeAnimation,
                child: AnimatedBuilder(
                  animation: _floatAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _floatAnimation.value),
                      child: child,
                    );
                  },
                  child: FrostCard(
                    padding: const EdgeInsets.all(28),
                    borderRadius: BorderRadius.circular(28),
                    gradient: AppTheme.primaryGradient,
                    boxShadow: AppTheme.elevatedShadow,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const SizedBox(
                            width: 88,
                            height: 88,
                            child: Icon(
                              Icons.local_hospital_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'NurseCare',
                          style:
                              Theme.of(context).textTheme.displayMedium?.copyWith(
                                    color: Colors.white,
                                  ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Book nearby nurses in real time, track visits live, and manage premium home care from one trusted platform.',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.white.withValues(alpha: 0.76),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: const [
                  Expanded(
                    child: _SplashTrustTile(
                      icon: Icons.location_searching_rounded,
                      title: 'Live tracking',
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _SplashTrustTile(
                      icon: Icons.verified_user_outlined,
                      title: 'Verified care',
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _SplashTrustTile(
                      icon: Icons.payments_outlined,
                      title: 'Transparent pay',
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Center(
                child: Column(
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.8),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Preparing your care network',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashTrustTile extends StatelessWidget {
  const _SplashTrustTile({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return FrostCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.accentLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(icon, color: AppTheme.accent, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}
