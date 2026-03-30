import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/healthcare_ui.dart';

class NurseProfileScreen extends StatefulWidget {
  const NurseProfileScreen({super.key});

  @override
  State<NurseProfileScreen> createState() => _NurseProfileScreenState();
}

class _NurseProfileScreenState extends State<NurseProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _photoController = TextEditingController();
  final _qualificationController = TextEditingController();
  final _experienceController = TextEditingController();
  final _languagesController = TextEditingController();
  final _aboutController = TextEditingController();
  final _startingPriceController = TextEditingController();
  final _serviceRadiusController = TextEditingController();

  final Set<String> _selectedSpecializations = {};
  String _shiftPreference = 'Flexible';
  String _gender = 'Prefer not to say';
  bool _initialized = false;

  static const _shiftOptions = [
    'Flexible',
    'Day shift',
    'Night shift',
    '12-hour care',
    '24-hour care',
  ];

  static const _genderOptions = [
    'Prefer not to say',
    'Female',
    'Male',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _photoController.dispose();
    _qualificationController.dispose();
    _experienceController.dispose();
    _languagesController.dispose();
    _aboutController.dispose();
    _startingPriceController.dispose();
    _serviceRadiusController.dispose();
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
              _photoController.text = user.profileImage;
              _qualificationController.text = user.qualification ?? '';
              _experienceController.text = user.experience ?? '';
              _languagesController.text =
                  (user.languages ?? const ['Hindi']).join(', ');
              _aboutController.text = user.about ?? '';
              _startingPriceController.text =
                  (user.startingPrice ?? 500).toStringAsFixed(0);
              _serviceRadiusController.text =
                  (user.serviceRadiusKm ?? 10).toStringAsFixed(0);
              _shiftPreference = user.shiftPreference ?? 'Flexible';
              _gender = user.gender?.isNotEmpty == true
                  ? user.gender!
                  : 'Prefer not to say';
              _selectedSpecializations
                ..clear()
                ..addAll(user.specializations ?? const []);
              _initialized = true;
            }

            final profileComplete = _isProfileComplete();
            final visibleToPatients =
                user.verified == true && profileComplete && user.isOnline == true;

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
                              title: 'Professional profile',
                              subtitle:
                                  'Fill your professional details so patients know exactly what you do, when you work, and how much care starts from.',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      FrostCard(
                        padding: const EdgeInsets.all(20),
                        borderRadius: BorderRadius.circular(22),
                        gradient: AppTheme.primaryGradient,
                        boxShadow: AppTheme.elevatedShadow,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              visibleToPatients
                                  ? 'You are visible to patients'
                                  : 'Your profile needs attention',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _visibilityMessage(user.verified == true, profileComplete, user.isOnline == true),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.78),
                                  ),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                StatusPill(
                                  label: user.verified == true
                                      ? 'Verified'
                                      : 'Pending verification',
                                  color: user.verified == true
                                      ? Colors.white
                                      : AppTheme.warning,
                                ),
                                StatusPill(
                                  label: profileComplete
                                      ? 'Profile complete'
                                      : 'Profile incomplete',
                                  color: profileComplete
                                      ? Colors.white
                                      : AppTheme.warning,
                                ),
                                StatusPill(
                                  label: user.isOnline == true
                                      ? 'Online'
                                      : 'Offline',
                                  color: user.isOnline == true
                                      ? Colors.white
                                      : AppTheme.error,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      AppSectionCard(
                        title: 'Basic identity',
                        subtitle:
                            'Patients trust clear identity and contact details first.',
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
                                hintText:
                                    'https://example.com/nurse-photo.jpg',
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
                            const SizedBox(height: 12),
                            _field(
                              controller: _nameController,
                              label: 'Full name',
                              hint: 'Enter your full name',
                              icon: Icons.person_outline_rounded,
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 12),
                            _field(
                              controller: _phoneController,
                              label: 'Phone number',
                              hint: '10-digit phone number',
                              icon: Icons.call_outlined,
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _gender,
                              decoration: const InputDecoration(
                                labelText: 'Gender',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                              items: _genderOptions
                                  .map(
                                    (item) => DropdownMenuItem(
                                      value: item,
                                      child: Text(item),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _gender = value);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppSectionCard(
                        title: 'Professional details',
                        subtitle:
                            'Explain what care you provide, your qualification, and how much your visits usually start from.',
                        child: Column(
                          children: [
                            _field(
                              controller: _qualificationController,
                              label: 'Qualification',
                              hint: 'GNM / ANM / B.Sc Nursing / ICU trained',
                              icon: Icons.school_outlined,
                            ),
                            const SizedBox(height: 12),
                            _field(
                              controller: _experienceController,
                              label: 'Experience',
                              hint: 'Example: 4 years in elder care and injections',
                              icon: Icons.workspace_premium_outlined,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _field(
                                    controller: _startingPriceController,
                                    label: 'Starting price',
                                    hint: '500',
                                    icon: Icons.currency_rupee_rounded,
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _field(
                                    controller: _serviceRadiusController,
                                    label: 'Service radius (km)',
                                    hint: '10',
                                    icon: Icons.route_outlined,
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _shiftPreference,
                              decoration: const InputDecoration(
                                labelText: 'Availability window',
                                prefixIcon: Icon(Icons.schedule_rounded),
                              ),
                              items: _shiftOptions
                                  .map(
                                    (item) => DropdownMenuItem(
                                      value: item,
                                      child: Text(item),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _shiftPreference = value);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppSectionCard(
                        title: 'Services & languages',
                        subtitle:
                            'Choose the types of care you can do so patients can understand your strengths instantly.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: AppConstants.serviceTypes
                                  .where((service) =>
                                      service['id'] != 'private_hire')
                                  .map((service) {
                                final label = service['name'] as String;
                                final selected =
                                    _selectedSpecializations.contains(label);
                                return FilterChip(
                                  label: Text(label),
                                  selected: selected,
                                  onSelected: (value) {
                                    setState(() {
                                      if (value) {
                                        _selectedSpecializations.add(label);
                                      } else {
                                        _selectedSpecializations.remove(label);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),
                            _field(
                              controller: _languagesController,
                              label: 'Languages',
                              hint: 'Hindi, English, Bengali',
                              icon: Icons.translate_rounded,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppSectionCard(
                        title: 'About you',
                        subtitle:
                            'Tell patients how you work, what kind of care you are best at, and why they can trust you.',
                        child: TextFormField(
                          controller: _aboutController,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            hintText:
                                'Example: Calm, experienced nurse focused on elder care, home visits, vitals monitoring, and compassionate support for families.',
                            prefixIcon: Icon(Icons.notes_rounded),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().length < 20) {
                              return 'Please write at least a short introduction';
                            }
                            return null;
                          },
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
                              : const Text('Save professional profile'),
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
      validator: (value) {
        if (label == 'Full name' || label == 'Phone number') {
          if (value == null || value.trim().isEmpty) {
            return '$label is required';
          }
        }
        return null;
      },
    );
  }

  bool _isProfileComplete() {
    return _qualificationController.text.trim().isNotEmpty &&
        _experienceController.text.trim().isNotEmpty &&
        _selectedSpecializations.isNotEmpty &&
        _aboutController.text.trim().length >= 20 &&
        _startingPriceController.text.trim().isNotEmpty &&
        _serviceRadiusController.text.trim().isNotEmpty;
  }

  String _visibilityMessage(
    bool verified,
    bool profileComplete,
    bool online,
  ) {
    if (verified && profileComplete && online) {
      return 'Patients nearby can now discover your profile, see your professional details, and request you directly.';
    }

    final reasons = <String>[];
    if (!verified) reasons.add('admin verification is pending');
    if (!profileComplete) reasons.add('your profile details are incomplete');
    if (!online) reasons.add('you are offline');

    return 'You will appear properly to patients after ${reasons.join(', ')}.';
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final startingPrice =
        double.tryParse(_startingPriceController.text.trim()) ?? 500;
    final serviceRadius =
        double.tryParse(_serviceRadiusController.text.trim()) ?? 10;
    final languages = _languagesController.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    final saved = await authProvider.updateProfile({
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'profileImage': _photoController.text.trim(),
      'qualification': _qualificationController.text.trim(),
      'experience': _experienceController.text.trim(),
      'specializations': _selectedSpecializations.toList(),
      'languages': languages,
      'startingPrice': startingPrice,
      'serviceRadiusKm': serviceRadius,
      'shiftPreference': _shiftPreference,
      'about': _aboutController.text.trim(),
      'gender': _gender == 'Prefer not to say' ? '' : _gender,
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
      const SnackBar(
        content: Text('Professional profile updated successfully'),
      ),
    );
    Navigator.pop(context);
  }
}
