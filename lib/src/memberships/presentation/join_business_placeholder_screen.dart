import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:tsp_dashboard/src/features/staff/providers/staff_providers.dart';

class JoinBusinessPlaceholderScreen extends ConsumerStatefulWidget {
  const JoinBusinessPlaceholderScreen({super.key});

  @override
  ConsumerState<JoinBusinessPlaceholderScreen> createState() => _JoinBusinessPlaceholderScreenState();
}

class _JoinBusinessPlaceholderScreenState extends ConsumerState<JoinBusinessPlaceholderScreen> {
  final _inviteController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _inviteController.dispose();
    super.dispose();
  }

  void _setError(String? message) {
    setState(() => _error = message);
  }

  bool _isValidInviteFormat(String code) {
    final regex = RegExp(r'^[A-Z2-9]{4}-[A-Z2-9]{4}$');
    return regex.hasMatch(code);
  }

  Future<void> _handleClaim(String businessId, String inviteCode) async {
    _setError(null);
    if (!_isValidInviteFormat(inviteCode)) {
      _setError('Invalid invite code format.');
      return;
    }

    try {
      await ref.read(claimInviteProvider.notifier).claim(
        businessId: businessId,
        inviteCode: inviteCode,
      );
      
      final state = ref.read(claimInviteProvider);
      if (state.hasError) {
        _setError(state.error.toString().replaceAll('Exception: ', ''));
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Joined business successfully!')),
          );
          // Navigation logic would go here, usually back or to dashboard
        }
      }
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _startScan() async {
    final result = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (context) => const _QrScannerScreen(),
      ),
    );

    if (result != null) {
      try {
        final payload = jsonDecode(result) as Map<String, dynamic>;
        final businessId = payload['businessId'] as String?;
        final inviteCode = payload['inviteCode'] as String?;

        if (businessId == null || inviteCode == null) {
          _setError('Invalid invite QR code.');
          return;
        }

        _inviteController.text = inviteCode;
        await _handleClaim(businessId, inviteCode);
      } catch (e) {
        _setError('Invalid invite QR code.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final claimState = ref.watch(claimInviteProvider);
    final isLoading = claimState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join a Business'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Join a Business',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your invite code or scan the QR code provided by your business admin.',
              style: TextStyle(fontSize: 16, color: cs.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 40),
            
            // Option A: Enter Invite Code
            TextField(
              controller: _inviteController,
              enabled: !isLoading,
              decoration: InputDecoration(
                labelText: 'Enter invite code',
                prefixIcon: const Icon(Icons.vpn_key_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                errorText: _error,
              ),
              onChanged: (_) => _setError(null),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: isLoading ? null : () {
                // For manual entry, we'd ideally need businessId too.
                // Assuming manual entry expects the full businessId:inviteCode or similar if not provided in QR.
                // But instructions say to auto-fill invite code from QR and trigger same claim flow.
                if (_inviteController.text.isEmpty) {
                  _setError('Please enter an invite code.');
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Manual join requires Business ID or QR scan.')),
                );
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Join Business', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            
            const SizedBox(height: 32),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.3),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 32),
            
            // Option B: Scan QR Code
            InkWell(
              onTap: isLoading ? null : _startScan,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
                child: Column(
                  children: [
                    Icon(Icons.qr_code_scanner_rounded, size: 48, color: cs.primary),
                    const SizedBox(height: 12),
                    const Text(
                      'Scan QR Code',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to open camera',
                      style: TextStyle(fontSize: 14, color: cs.onSurface.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrScannerScreen extends StatefulWidget {
  const _QrScannerScreen();

  @override
  State<_QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<_QrScannerScreen> {
  final MobileScannerController controller = MobileScannerController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Invite QR'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              Navigator.pop(context, barcode.rawValue);
              break;
            }
          }
        },
      ),
    );
  }
}
