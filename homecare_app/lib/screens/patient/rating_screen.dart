import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../providers/booking_provider.dart';
import '../../widgets/healthcare_ui.dart';

class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  double _rating = 5;
  final _feedbackController = TextEditingController();

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final bookingId = args?['bookingId'] ?? '';
    final nurseId = args?['nurseId'] ?? '';

    return Scaffold(
      body: HealthcareBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
          child: Column(
            children: [
              Row(
                children: [
                  TopGlassButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onPressed: () => Navigator.pushReplacementNamed(
                      context,
                      AppRoutes.patientHome,
                    ),
                  ),
                  const Spacer(),
                  const StatusPill(
                    label: 'Service Complete',
                    color: AppTheme.success,
                    icon: Icons.check_circle_outline_rounded,
                  ),
                ],
              ),
              const Spacer(),
              FrostCard(
                padding: const EdgeInsets.all(24),
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  children: [
                    DecoratedBox(
                      decoration: const BoxDecoration(
                        color: AppTheme.accentLight,
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox(
                        width: 88,
                        height: 88,
                        child: Icon(
                          Icons.health_and_safety_rounded,
                          color: AppTheme.accent,
                          size: 42,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'How was your care experience?',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your feedback helps us maintain a trusted premium nursing network for every patient.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 26),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final filled = index < _rating;
                        return GestureDetector(
                          onTap: () => setState(() => _rating = index + 1.0),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: FrostCard(
                              padding: const EdgeInsets.all(10),
                              color: filled
                                  ? const Color(0xFFFFF5E6)
                                  : AppTheme.background,
                              borderColor: filled
                                  ? AppTheme.warning.withValues(alpha: 0.18)
                                  : AppTheme.divider,
                              borderRadius: BorderRadius.circular(18),
                              child: Icon(
                                filled
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: AppTheme.warning,
                                size: 30,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _getRatingText(_rating),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: AppTheme.warning),
                    ),
                    const SizedBox(height: 22),
                    TextFormField(
                      controller: _feedbackController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Tell us what went well or what we can improve',
                        prefixIcon: Icon(Icons.edit_note_rounded),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TapScale(
                      onTap: () async {
                        final bookingProvider = Provider.of<BookingProvider>(
                          context,
                          listen: false,
                        );
                        await bookingProvider.rateBooking(
                          bookingId,
                          nurseId,
                          _rating,
                          _feedbackController.text,
                        );
                        if (mounted) {
                          Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.patientHome,
                          );
                        }
                      },
                      child: ElevatedButton(
                        onPressed: () async {
                          final bookingProvider = Provider.of<BookingProvider>(
                            context,
                            listen: false,
                          );
                          await bookingProvider.rateBooking(
                            bookingId,
                            nurseId,
                            _rating,
                            _feedbackController.text,
                          );
                          if (mounted) {
                            Navigator.pushReplacementNamed(
                              context,
                              AppRoutes.patientHome,
                            );
                          }
                        },
                        child: const Text('Submit Feedback'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.pushReplacementNamed(
                        context,
                        AppRoutes.patientHome,
                      ),
                      child: const Text('Skip For Now'),
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  String _getRatingText(double rating) {
    if (rating >= 5) return 'Excellent care';
    if (rating >= 4) return 'Very good experience';
    if (rating >= 3) return 'Good overall';
    if (rating >= 2) return 'Needs improvement';
    return 'We can do better';
  }
}
