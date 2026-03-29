import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../widgets/healthcare_ui.dart';

class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HealthcareBackground(
        child: Padding(
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
                  Text('Payment', style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
              const Spacer(),
              FrostCard(
                padding: const EdgeInsets.all(28),
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  children: [
                    DecoratedBox(
                      decoration: const BoxDecoration(
                        color: Color(0xFFE6F9F3),
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox(
                        width: 88,
                        height: 88,
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.success,
                          size: 46,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Payment successful',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your payment has been recorded and the visit is now secured inside the booking flow.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: const [
                        InfoChip(
                          icon: Icons.account_balance_outlined,
                          label: 'UPI',
                          foregroundColor: AppTheme.accent,
                          backgroundColor: AppTheme.accentLight,
                        ),
                        InfoChip(
                          icon: Icons.credit_card_outlined,
                          label: 'Card',
                          foregroundColor: AppTheme.accent,
                          backgroundColor: AppTheme.accentLight,
                        ),
                        InfoChip(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Wallet',
                          foregroundColor: AppTheme.accent,
                          backgroundColor: AppTheme.accentLight,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              TapScale(
                onTap: () => Navigator.pop(context),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
