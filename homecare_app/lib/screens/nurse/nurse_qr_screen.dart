import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/nurse_qr_payload.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/healthcare_ui.dart';

class NurseQrScreen extends StatefulWidget {
  const NurseQrScreen({super.key});

  @override
  State<NurseQrScreen> createState() => _NurseQrScreenState();
}

class _NurseQrScreenState extends State<NurseQrScreen> {
  String? _selectedServiceType;

  @override
  Widget build(BuildContext context) {
    final nurse = context.watch<AuthProvider>().user;
    if (nurse == null) {
      return const Scaffold(
        body: HealthcareBackground(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final defaultService = AppConstants.fallbackServiceForNurse(
      nurse.specializations,
    );
    _selectedServiceType ??= defaultService['id'] as String;
    final selectedService = AppConstants.serviceById(_selectedServiceType) ??
        defaultService;
    final payload = NurseQrPayload(
      nurseId: nurse.uid,
      nurseName: nurse.name,
      nurseServiceType: selectedService['id'] as String,
      nurseServiceName: selectedService['name'] as String,
    );

    return Scaffold(
      body: HealthcareBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
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
                      title: 'Scan Booking QR',
                      subtitle:
                          'Show this QR to the patient so they can instantly select you on the map and request care directly.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FrostCard(
                padding: const EdgeInsets.all(24),
                borderRadius: BorderRadius.circular(24),
                gradient: AppTheme.primaryGradient,
                boxShadow: AppTheme.elevatedShadow,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      child: Text(
                        nurse.name.isNotEmpty ? nurse.name[0].toUpperCase() : 'N',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nurse.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Patient scan shortcut',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.white.withValues(alpha: 0.76)),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              StatusPill(
                                label: nurse.verified == true ? 'Verified' : 'Live booking enabled',
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FrostCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select service for QR bookings',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The chosen service will be pre-filled when the patient scans your QR.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AppConstants.serviceTypes.map((service) {
                        final selected =
                            service['id'] == _selectedServiceType;
                        return FrostCard(
                          onTap: () => setState(() {
                            _selectedServiceType = service['id'] as String;
                          }),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          color:
                              selected ? AppTheme.accentLight : AppTheme.surface,
                          borderColor:
                              selected ? AppTheme.accent : AppTheme.divider,
                          borderRadius: BorderRadius.circular(14),
                          child: Text(
                            service['name'] as String,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color:
                                      selected ? AppTheme.accent : AppTheme.textPrimary,
                                ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FrostCard(
                padding: const EdgeInsets.all(24),
                borderRadius: BorderRadius.circular(28),
                boxShadow: AppTheme.elevatedShadow,
                child: Column(
                  children: [
                    Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Center(
                        child: QrImageView(
                          data: payload.toEncodedString(),
                          version: QrVersions.auto,
                          size: 220,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: AppTheme.primary,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      selectedService['name'] as String,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Starts at ₹${selectedService['basePrice']}',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FrostCard(
                padding: const EdgeInsets.all(18),
                color: AppTheme.accentLight,
                borderColor: AppTheme.accent.withValues(alpha: 0.18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What happens after scan?',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Patient scan karega → aap map par highlight honge → service prefill hogi → patient booking bhejega → aapko live request popup milega.',
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
