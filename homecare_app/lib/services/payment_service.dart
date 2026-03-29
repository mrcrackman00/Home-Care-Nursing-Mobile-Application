import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter/material.dart';

import 'package:flutter/foundation.dart';

class PaymentService {
  Razorpay? _razorpay;
  final Function(dynamic) onSuccess;
  final Function(dynamic) onFailure;
  final Function(dynamic) onExternalWallet;

  PaymentService({
    required this.onSuccess,
    required this.onFailure,
    required this.onExternalWallet,
  }) {
    if (!kIsWeb) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, onSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, onFailure);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, onExternalWallet);
    }
  }

  void openCheckout({
    required double amount,
    required String name,
    required String description,
    required String contact,
    required String email,
  }) {
    var options = {
      'key': 'rzp_test_1DP5mmOlF5G5ag', // Use a test key for development
      'amount': (amount * 100).toInt(), // Amount in paisa
      'name': 'HomeCare Nursing',
      'description': description,
      'prefill': {
        'contact': contact,
        'email': email,
      },
      'theme': {
        'color': '#178C92', // AppTheme.primaryTeal
      }
    };

    try {
      if (!kIsWeb && _razorpay != null) {
        _razorpay!.open(options);
      } else {
        // Mock payment on web
        debugPrint('Web Payment Mock: Razorpay not supported on web natively');
        onSuccess({'paymentId': 'pay_mock12345', 'orderId': 'order_mock123', 'signature': 'sig_mock123'});
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void dispose() {
    _razorpay?.clear();
  }
}
