import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/healthcare_ui.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _photoController = TextEditingController();

  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _photoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HealthcareBackground(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            final user = authProvider.user;
            if (user == null) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!_initialized) {
              _nameController.text = user.name;
              _phoneController.text = user.phone;
              _emailController.text = user.email;
              _addressController.text = user.address ?? '';
              _photoController.text = user.profileImage;
              _initialized = true;
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
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
                          const SizedBox(width: 12),
                          const Expanded(
                            child: SectionHeading(
                              title: 'Your profile',
                              subtitle:
                                  'Update your personal details, address, and photo so nurses can recognise and reach you with confidence.',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      AppSectionCard(
                        title: 'Profile photo',
                        subtitle:
                            'Paste a public image link to show your photo across the patient and nurse app.',
                        child: Column(
                          children: [
                            Center(
                              child: AppUserAvatar(
                                name: _nameController.text.trim().isEmpty
                                    ? user.name
                                    : _nameController.text.trim(),
                                imageUrl: _photoController.text.trim(),
                                radius: 38,
                                backgroundColor: AppTheme.accentLight,
                                foregroundColor: AppTheme.accent,
                                borderColor: AppTheme.accent,
                                borderWidth: 2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _photoController,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Profile photo URL',
                                hintText: 'https://example.com/your-photo.jpg',
                                prefixIcon: Icon(Icons.image_outlined),
                              ),
                              validator: (value) {
                                final text = value?.trim() ?? '';
                                if (text.isNotEmpty &&
                                    !text.startsWith('http://') &&
                                    !text.startsWith('https://')) {
                                  return 'Please enter a valid image URL';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppSectionCard(
                        title: 'Personal details',
                        subtitle:
                            'Keep your contact details correct so nurses and support can coordinate smoothly.',
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameController,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Full name',
                                hintText: 'Enter your full name',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Full name is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Phone number',
                                hintText: '10-digit phone number',
                                prefixIcon: Icon(Icons.call_outlined),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Phone number is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _emailController,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Account email',
                                prefixIcon: Icon(Icons.mail_outline_rounded),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppSectionCard(
                        title: 'Address',
                        subtitle:
                            'This helps nearby nurses understand where the care visit is likely to happen.',
                        child: TextFormField(
                          controller: _addressController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Primary address',
                            hintText:
                                'House number, locality, landmark, city',
                            prefixIcon: Icon(Icons.home_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      TapScale(
                        onTap: authProvider.isLoading ? null : _saveProfile,
                        child: ElevatedButton(
                          onPressed: authProvider.isLoading ? null : _saveProfile,
                          child: authProvider.isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save profile'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final saved = await authProvider.updateProfile({
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'address': _addressController.text.trim(),
      'profileImage': _photoController.text.trim(),
    });

    if (!mounted) {
      return;
    }

    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? 'Unable to save profile right now'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully')),
    );
    Navigator.pop(context);
  }
}
