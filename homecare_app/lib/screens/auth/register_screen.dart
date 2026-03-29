import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/healthcare_ui.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String _selectedRole = 'patient';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    String email = _emailController.text.trim();

    if (email.isEmpty && _phoneController.text.isNotEmpty) {
      final phone = _phoneController.text
          .trim()
          .replaceAll(RegExp(r'[^0-9]'), '');
      email = 'phone_$phone@homecare.com';
    }

    final success = await authProvider.register(
      email: email,
      password: _passwordController.text,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      role: _selectedRole,
    );

    if (!success || !mounted) {
      return;
    }

    Navigator.pushReplacementNamed(
      context,
      _selectedRole == 'nurse' ? AppRoutes.nurseHome : AppRoutes.patientHome,
    );
  }

  Future<void> _previewExperience() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.loginAsGuest(_selectedRole);
    if (mounted) {
      Navigator.pushReplacementNamed(
        context,
        _selectedRole == 'nurse' ? AppRoutes.nurseHome : AppRoutes.patientHome,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HealthcareBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TopGlassButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    const StatusPill(
                      label: 'Premium Onboarding',
                      color: AppTheme.accent,
                      icon: Icons.verified_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Create a care account that feels built for trust',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 10),
                Text(
                  'Join as a patient or nurse, keep your bookings organized, and move through the product with a polished hospital-grade experience.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
                const SizedBox(height: 22),
                FrostCard(
                  padding: const EdgeInsets.all(24),
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose your role',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _RoleTile(
                              icon: Icons.favorite_border_rounded,
                              title: 'Patient',
                              subtitle: 'Book home nursing',
                              selected: _selectedRole == 'patient',
                              onTap: () {
                                setState(() => _selectedRole = 'patient');
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _RoleTile(
                              icon: Icons.local_hospital_outlined,
                              title: 'Nurse',
                              subtitle: 'Accept visits & earn',
                              selected: _selectedRole == 'nurse',
                              accent: AppTheme.success,
                              onTap: () {
                                setState(() => _selectedRole = 'nurse');
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      _buildLabel(context, 'Full name'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          hintText: 'Enter your full name',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildLabel(context, 'Email'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'Email (optional if using phone)',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildLabel(context, 'Phone number'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          hintText: '+91 98765 43210',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Phone number is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildLabel(context, 'Password'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: 'Create a secure password',
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
                            return 'Password is required';
                          }
                          if (value.length < 6) {
                            return 'Use at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          if (auth.error == null) {
                            return const SizedBox.shrink();
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
                                          ?.copyWith(color: AppTheme.error),
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
                            onTap: auth.isLoading ? null : _register,
                            child: ElevatedButton(
                              onPressed: auth.isLoading ? null : _register,
                              child: auth.isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _selectedRole == 'nurse'
                                          ? 'Create Nurse Account'
                                          : 'Create Patient Account',
                                    ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      TapScale(
                        onTap: _previewExperience,
                        child: OutlinedButton.icon(
                          onPressed: _previewExperience,
                          icon: const Icon(Icons.bolt_rounded),
                          label: const Text('Preview The Experience'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 4,
                    children: [
                      Text(
                        'Already have an account?',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text(
                          'Sign in',
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
    );
  }

  Widget _buildLabel(BuildContext context, String label) {
    return Text(label, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.accent = AppTheme.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FrostCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      color: selected ? accent.withValues(alpha: 0.08) : AppTheme.surface,
      borderColor: selected ? accent.withValues(alpha: 0.26) : AppTheme.divider,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(icon, color: accent, size: 20),
            ),
          ),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
