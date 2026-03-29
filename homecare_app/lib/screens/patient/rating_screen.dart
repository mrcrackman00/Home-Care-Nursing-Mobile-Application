import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/booking_provider.dart';

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
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: AppTheme.success, size: 48),
                ),
                const SizedBox(height: 24),
                const Text('Service Completed!', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('How was your experience?', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                const SizedBox(height: 32),
                // Star Rating
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () => setState(() => _rating = index + 1.0),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          index < _rating ? Icons.star_rounded : Icons.star_border_rounded,
                          color: AppTheme.accentGold,
                          size: 48,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Text(
                  _getRatingText(_rating),
                  style: const TextStyle(color: AppTheme.accentGold, fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 24),
                // Feedback
                TextFormField(
                  controller: _feedbackController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Share your feedback (optional)',
                    filled: true,
                    fillColor: AppTheme.bgCard,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
                      await bookingProvider.rateBooking(
                        bookingId,
                        nurseId,
                        _rating,
                        _feedbackController.text,
                      );
                      if (mounted) {
                        Navigator.pushReplacementNamed(context, AppRoutes.patientHome);
                      }
                    },
                    child: const Text('Submit Rating', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.patientHome),
                  child: const Text('Skip', style: TextStyle(color: AppTheme.textMuted)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getRatingText(double rating) {
    if (rating >= 5) return 'Excellent! ⭐';
    if (rating >= 4) return 'Very Good 😊';
    if (rating >= 3) return 'Good 🙂';
    if (rating >= 2) return 'Fair 😐';
    return 'Poor 😞';
  }
}
