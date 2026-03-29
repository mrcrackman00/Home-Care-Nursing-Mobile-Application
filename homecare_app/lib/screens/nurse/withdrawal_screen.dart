import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/earning_provider.dart';

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
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios, color: Colors.white)),
                    const Text('Withdraw Money', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Consumer<EarningProvider>(
                    builder: (context, earningProvider, _) {
                      final balance = earningProvider.earnings?.withdrawableBalance ?? 0;
                      return Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Balance Card
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                children: [
                                  const Text('Available Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
                                  const SizedBox(height: 8),
                                  Text('₹${balance.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Amount
                            const Text('Withdrawal Amount', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(
                                prefixText: '₹ ',
                                prefixStyle: TextStyle(color: AppTheme.primaryTeal, fontSize: 24, fontWeight: FontWeight.bold),
                                hintText: '0',
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Enter amount';
                                final amount = double.tryParse(v);
                                if (amount == null || amount <= 0) return 'Invalid amount';
                                if (amount > balance) return 'Insufficient balance';
                                return null;
                              },
                            ),
                            // Quick amounts
                            const SizedBox(height: 12),
                            Row(
                              children: [500.0, 1000.0, 2000.0, 5000.0].map((amount) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: GestureDetector(
                                    onTap: () {
                                      if (amount <= balance) {
                                        _amountController.text = amount.toStringAsFixed(0);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: amount <= balance ? AppTheme.bgCard : AppTheme.bgCardLight.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: AppTheme.bgCardLight),
                                      ),
                                      child: Text(
                                        '₹${amount.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          color: amount <= balance ? Colors.white : AppTheme.textMuted,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 32),

                            // Bank Details
                            const Text('Bank Details', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 12),
                            _buildField(_accountHolderController, 'Account Holder Name', Icons.person),
                            const SizedBox(height: 12),
                            _buildField(_accountNumberController, 'Account Number', Icons.account_balance),
                            const SizedBox(height: 12),
                            _buildField(_ifscController, 'IFSC Code', Icons.code),
                            const SizedBox(height: 24),

                            // Or UPI
                            Row(
                              children: [
                                Expanded(child: Divider(color: AppTheme.textMuted.withValues(alpha: 0.3))),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text('or', style: TextStyle(color: AppTheme.textMuted)),
                                ),
                                Expanded(child: Divider(color: AppTheme.textMuted.withValues(alpha: 0.3))),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildField(_upiIdController, 'UPI ID (e.g. name@upi)', Icons.qr_code),
                            const SizedBox(height: 32),

                            // Withdraw Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: earningProvider.isLoading ? null : _withdraw,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.success,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: earningProvider.isLoading
                                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                    : const Text('Withdraw Money', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Error
                            if (earningProvider.error != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(earningProvider.error!, style: const TextStyle(color: AppTheme.error)),
                              ),
                            const SizedBox(height: 32),
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

  Widget _buildField(TextEditingController controller, String hint, IconData icon) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.primaryTeal),
      ),
    );
  }

  Future<void> _withdraw() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate bank details
    if (_accountNumberController.text.isEmpty && _upiIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter bank details or UPI ID')),
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
          backgroundColor: AppTheme.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: AppTheme.success, size: 40),
              ),
              const SizedBox(height: 16),
              const Text('Withdrawal Requested!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Your withdrawal of ₹${_amountController.text} has been initiated. It will be processed within 24-48 hours.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      );
    }
  }
}
