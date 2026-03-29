import 'package:flutter/material.dart';
import '../../config/theme.dart';

class BookingRequestScreen extends StatelessWidget {
  const BookingRequestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking Request')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: const Center(child: Text('Request details shown inline on home screen', style: TextStyle(color: AppTheme.textSecondary))),
      ),
    );
  }
}
