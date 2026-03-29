import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/earning_provider.dart';
import '../../widgets/healthcare_ui.dart';

class WithdrawalScreen extends StatefulWidget {
  const WithdrawalScreen({super.key});
  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final _amountController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _upiIdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _amountController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _accountHolderController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HealthcareBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
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
                      title: 'Withdraw earnings',
                      subtitle:
                          'Move your available balance to your bank account or UPI destination securely.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: Consumer<EarningProvider>(
                    builder: (context, provider, _) {
                      final balance = provider.earnings?.withdrawableBalance ?? 0;
                      return Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FrostCard(
                              padding: const EdgeInsets.all(24),
                              borderRadius: BorderRadius.circular(20),
                              gradient: AppTheme.primaryGradient,
                              boxShadow: AppTheme.elevatedShadow,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const StatusPill(
                                    label: 'Withdrawable Balance',
                                    color: Colors.white,
                                  ),
                                  const SizedBox(height: 18),
                                  AnimatedAmountText(
                                    amount: balance,
                                    size: 38,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Completed jobs settle here automatically once the backend marks them available for payout.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Colors.white.withValues(alpha: 0.72),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            AppSectionCard(
                              title: 'Withdrawal amount',
                              subtitle:
                                  'Pick a quick amount or enter a custom value.',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextFormField(
                                    controller: _amountController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      prefixText: '₹ ',
                                      hintText: '0',
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Enter amount';
                                      }
                                      final amount = double.tryParse(value);
                                      if (amount == null || amount <= 0) {
                                        return 'Invalid amount';
                                      }
                                      if (amount > balance) {
                                        return 'Insufficient balance';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [500.0, 1000.0, 2000.0, 5000.0]
                                        .map(
                                          (amount) => _AmountChip(
                                            label: '₹${amount.toStringAsFixed(0)}',
                                            enabled: amount <= balance,
                                            onTap: () {
                                              if (amount <= balance) {
                                                _amountController.text =
                                                    amount.toStringAsFixed(0);
                                              }
                                            },
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            AppSectionCard(
                              title: 'Bank account details',
                              subtitle:
                                  'Add bank details or use a UPI destination for payout.',
                              child: Column(
                                children: [
                                  _field(
                                    _accountHolderController,
                                    'Account holder name',
                                    Icons.person_outline_rounded,
                                  ),
                                  const SizedBox(height: 12),
                                  _field(
                                    _accountNumberController,
                                    'Account number',
                                    Icons.account_balance_outlined,
                                  ),
                                  const SizedBox(height: 12),
                                  _field(
                                    _ifscController,
                                    'IFSC code',
                                    Icons.qr_code_scanner_outlined,
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      const Expanded(child: Divider()),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        child: Text(
                                          'or withdraw via UPI',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall,
                                        ),
                                      ),
                                      const Expanded(child: Divider()),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  _field(
                                    _upiIdController,
                                    'UPI ID (example@upi)',
                                    Icons.account_balance_wallet_outlined,
                                  ),
                                ],
                              ),
                            ),
                            if (provider.error != null) ...[
                              const SizedBox(height: 14),
                              FrostCard(
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
                                        provider.error!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(color: AppTheme.error),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            TapScale(
                              onTap: provider.isLoading ? null : _withdraw,
                              child: ElevatedButton(
                                onPressed: provider.isLoading ? null : _withdraw,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.success,
                                ),
                                child: provider.isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Withdraw money'),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint,
    IconData icon,
  ) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
    );
  }

  Future<void> _withdraw() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_accountNumberController.text.isEmpty && _upiIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter bank details or a UPI ID'),
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final earningProvider = Provider.of<EarningProvider>(context, listen: false);
    final success = await earningProvider.requestWithdrawal(
      nurseId: authProvider.user!.uid,
      amount: double.parse(_amountController.text),
      bankDetails: {
        'accountNumber': _accountNumberController.text,
        'ifsc': _ifscController.text,
        'accountHolder': _accountHolderController.text,
        'upiId': _upiIdController.text,
      },
    );

    if (success && mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Withdrawal Requested'),
          content: Text(
            'Your withdrawal of ₹${_amountController.text} has been initiated. We will process it when the payout workflow runs.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }
  }
}

class _AmountChip extends StatelessWidget {
  const _AmountChip({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FrostCard(
      onTap: enabled ? onTap : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: enabled ? AppTheme.background : AppTheme.divider.withValues(alpha: 0.4),
      borderColor: enabled ? AppTheme.divider : Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: enabled ? AppTheme.textPrimary : AppTheme.textDisabled,
            ),
      ),
    );
  }
}
