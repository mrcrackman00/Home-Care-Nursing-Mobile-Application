import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../config/theme.dart';
import '../../models/nurse_qr_payload.dart';
import '../../widgets/healthcare_ui.dart';

class ScanNurseScreen extends StatefulWidget {
  const ScanNurseScreen({super.key});

  @override
  State<ScanNurseScreen> createState() => _ScanNurseScreenState();
}

class _ScanNurseScreenState extends State<ScanNurseScreen> {
  final _controller = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  final _manualController = TextEditingController();
  bool _isHandling = false;
  bool _flashOn = false;

  @override
  void dispose() {
    _manualController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleRawValue(String rawValue) async {
    if (_isHandling) {
      return;
    }

    setState(() => _isHandling = true);
    try {
      final payload = NurseQrPayload.fromEncodedString(rawValue);
      if (!payload.isValid) {
        throw const FormatException('Invalid QR payload');
      }
      if (!mounted) {
        return;
      }
      Navigator.pop(context, payload);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This QR is not a valid nurse booking code.'),
        ),
      );
      setState(() => _isHandling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final barcode =
                  capture.barcodes.isEmpty ? null : capture.barcodes.first;
              final rawValue = barcode?.rawValue;
              if (rawValue == null || rawValue.isEmpty) {
                return;
              }
              _handleRawValue(rawValue);
            },
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.38),
            ),
            child: const SizedBox.expand(),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
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
                          title: 'Scan Nurse',
                          subtitle:
                              'Scan the nurse QR to instantly select them on the live map and fast-track the booking.',
                        ),
                      ),
                      const SizedBox(width: 12),
                      TopGlassButton(
                        icon: _flashOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        onPressed: () async {
                          await _controller.toggleTorch();
                          if (mounted) {
                            setState(() => _flashOn = !_flashOn);
                          }
                        },
                      ),
                    ],
                  ),
                  const Spacer(),
                  Center(
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        boxShadow: AppTheme.elevatedShadow,
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: AppTheme.accent,
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                          const Positioned(
                            top: 14,
                            left: 14,
                            child: _ScanCorner(),
                          ),
                          const Positioned(
                            top: 14,
                            right: 14,
                            child: RotatedBox(
                              quarterTurns: 1,
                              child: _ScanCorner(),
                            ),
                          ),
                          const Positioned(
                            bottom: 14,
                            right: 14,
                            child: RotatedBox(
                              quarterTurns: 2,
                              child: _ScanCorner(),
                            ),
                          ),
                          const Positioned(
                            bottom: 14,
                            left: 14,
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: _ScanCorner(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'Place the nurse QR inside the frame',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      kIsWeb
                          ? 'Camera access on web may vary. You can also paste the QR payload below for testing.'
                          : 'As soon as the QR is detected, the nurse will be highlighted on the map.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white.withValues(alpha: 0.8)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FrostCard(
                    padding: const EdgeInsets.all(16),
                    borderRadius: BorderRadius.circular(20),
                    color: AppTheme.surface.withValues(alpha: 0.96),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manual test input',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Useful for web preview or testing. Paste the QR JSON and continue.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _manualController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText:
                                '{"nurseId":"...","nurseName":"...","nurseServiceType":"basic_visit"}',
                            prefixIcon: Icon(Icons.qr_code_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TapScale(
                          onTap: () => _handleRawValue(_manualController.text.trim()),
                          child: ElevatedButton(
                            onPressed: () => _handleRawValue(_manualController.text.trim()),
                            child: const Text('Use scanned nurse'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanCorner extends StatelessWidget {
  const _ScanCorner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.92), width: 4),
            left: BorderSide(color: Colors.white.withValues(alpha: 0.92), width: 4),
          ),
        ),
      ),
    );
  }
}
