import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/healthcare_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    String email = _emailController.text.trim();

    if (!email.contains('@')) {
      final cleanPhone = email.replaceAll(RegExp(r'[^0-9]'), '');
      email = 'phone_$cleanPhone@homecare.com';
    }

    final success = await authProvider.login(
      email: email,
      password: _passwordController.text,
    );

    if (!success || !mounted) {
      return;
    }

    final user = authProvider.user;
    if (user != null && user.role == 'nurse') {
      Navigator.pushReplacementNamed(context, AppRoutes.nurseHome);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.patientHome);
    }
  }

  Future<void> _previewGuest() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.loginAsGuest('patient');
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.patientHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HealthcareBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Form(
            key: _formKey,
            child: FadeTransition(
              opacity: _animController,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.08),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: _animController,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const StatusPill(
                          label: 'Secure Sign In',
                          color: AppTheme.accent,
                          icon: Icons.verified_user_outlined,
                        ),
                        const Spacer(),
                        TopGlassButton(
                          icon: Icons.support_agent_rounded,
                          onPressed: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Welcome back to premium home care',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Book trusted nurses, manage visits live, and keep every care interaction organized in one polished workflow.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 24),
                    FrostCard(
                      padding: const EdgeInsets.all(24),
                      borderRadius: BorderRadius.circular(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Expanded(
                                child: _AuthHighlight(
                                  icon: Icons.location_searching_rounded,
                                  title: 'Live ETA',
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: _AuthHighlight(
                                  icon: Icons.medical_services_outlined,
                                  title: 'Trusted nurses',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Phone or email',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: 'Enter phone number or email',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your account ID';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Password',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: 'Enter your password',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {},
                              child: const Text('Forgot Password?'),
                            ),
                          ),
                          Consumer<AuthProvider>(
                            builder: (context, auth, _) {
                              if (auth.error == null) {
                                return const SizedBox(height: 4);
                              }
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: FrostCard(
                                  padding: const EdgeInsets.all(14),
                                  color: const Color(0xFFFFF3F6),
                                  borderColor: AppTheme.error.withValues(alpha: 0.15),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline_rounded,
                                        color: AppTheme.error,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          auth.error!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: AppTheme.error,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          Consumer<AuthProvider>(
                            builder: (context, auth, _) {
                              return TapScale(
                                onTap: auth.isLoading ? null : _login,
                                child: ElevatedButton(
                                  onPressed: auth.isLoading ? null : _login,
                                  child: auth.isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Sign In Securely'),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                          TapScale(
                            onTap: _previewGuest,
                            child: OutlinedButton.icon(
                              onPressed: _previewGuest,
                              icon: const Icon(Icons.bolt_rounded),
                              label: const Text('Preview As Guest'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'New to NurseCare?',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(context, AppRoutes.register);
                            },
                            child: Text(
                              'Create your account',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(color: AppTheme.accent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthHighlight extends StatelessWidget {
  const _AuthHighlight({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return FrostCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      color: AppTheme.background,
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.accentLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(icon, color: AppTheme.accent, size: 18),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}
