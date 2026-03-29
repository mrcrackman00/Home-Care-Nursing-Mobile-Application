import 'package:flutter/material.dart';

import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../widgets/healthcare_ui.dart';

class ServiceSelectionScreen extends StatefulWidget {
  const ServiceSelectionScreen({super.key});

  @override
  State<ServiceSelectionScreen> createState() => _ServiceSelectionScreenState();
}

class _ServiceSelectionScreenState extends State<ServiceSelectionScreen> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HealthcareBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(
                children: [
                  TopGlassButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: SectionHeading(
                      title: 'Select care service',
                      subtitle:
                          'Choose the type of nursing support you need and we will route the booking to nearby professionals.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: const [
                  Expanded(
                    child: AppMetricTile(
                      label: 'Live booking',
                      value: '24/7',
                      color: AppTheme.accent,
                      icon: Icons.flash_on_rounded,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: AppMetricTile(
                      label: 'Verified nurses',
                      value: 'Only',
                      color: AppTheme.success,
                      icon: Icons.verified_user_outlined,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                itemCount: AppConstants.serviceTypes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final service = AppConstants.serviceTypes[index];
                  final selected = _selectedIndex == index;
                  return FrostCard(
                    onTap: () => setState(() => _selectedIndex = index),
                    padding: const EdgeInsets.all(18),
                    color: selected ? AppTheme.accentLight : AppTheme.surface,
                    borderColor: selected ? AppTheme.accent : AppTheme.divider,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.white
                                    : AppTheme.background,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: SizedBox(
                                width: 58,
                                height: 58,
                                child: Center(
                                  child: Text(
                                    service['emoji'] ?? '🏥',
                                    style: const TextStyle(fontSize: 26),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          service['name'],
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge,
                                        ),
                                      ),
                                      if (selected)
                                        const StatusPill(
                                          label: 'Selected',
                                          color: AppTheme.accent,
                                          icon: Icons.check_circle_outline_rounded,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    service['description'],
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            InfoChip(
                              icon: Icons.schedule_outlined,
                              label: '${service['duration']}',
                            ),
                            InfoChip(
                              icon: Icons.currency_rupee_rounded,
                              label:
                                  '₹${service['basePrice']} - ₹${service['maxPrice']}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomSheet: _selectedIndex == null
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(top: BorderSide(color: AppTheme.divider)),
              ),
              child: SafeArea(
                top: false,
                child: TapScale(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.booking,
                      arguments: AppConstants.serviceTypes[_selectedIndex!],
                    );
                  },
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.booking,
                        arguments: AppConstants.serviceTypes[_selectedIndex!],
                      );
                    },
                    child: Text(
                      'Continue with ${AppConstants.serviceTypes[_selectedIndex!]['name']}',
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
