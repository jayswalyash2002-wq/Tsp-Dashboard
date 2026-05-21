import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/auth_providers.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.phone,
    required this.name,
    required this.password,
    required this.verificationId,
  });

  final String email;
  final String phone;
  final String name;
  final String password;
  final String verificationId;

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _busy = false;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _verifyOtp() async {
    if (_busy) return;
    final otp = _controllers.map((e) => e.text).join();
    if (otp.length < 6) return;

    if (widget.verificationId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid verification session.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final repo = await ref.read(authRepositoryProvider.future);
      final isValid = await repo.verifyOtp(
        verificationId: widget.verificationId,
        smsCode: otp,
      );

      if (!isValid) throw Exception('Invalid code.');

      await repo.signUpWithEmailPassword(
        email: widget.email,
        password: widget.password,
        name: widget.name,
        phoneNumber: widget.phone,
      );

      // Sync local state for AuthGate to bypass DeviceNameScreen
      ref.read(deviceNameProvider.notifier).state = widget.name;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully!')),
      );
      context.pushReplacement('/business-setup');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onChanged(String value, int index) {
    // Handle digit entry
    if (value.isNotEmpty) {
      if (value.length > 1) {
        // Handle Paste/Autofill
        final digits = value.replaceAll(RegExp(r'\D'), '');
        for (var i = 0; i < digits.length && (index + i) < 6; i++) {
          _controllers[index + i].text = digits[i];
        }
        final lastFocusIndex = (index + digits.length - 1).clamp(0, 5);
        _focusNodes[lastFocusIndex].requestFocus();
        
        if (index + digits.length >= 6) {
          _verifyOtp();
        }
      } else {
        // Single digit entry
        if (index < 5) {
          _focusNodes[index + 1].requestFocus();
        } else {
          _focusNodes[index].unfocus();
          _verifyOtp();
        }
      }
    } else {
      // Deleting a digit - move back
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Verify Code'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Step 2: Enter 6-digit code',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Code sent to ${widget.phone}',
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 48),
                Row(
                  children: List.generate(6, (index) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _buildOtpBox(index),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 60),
                FilledButton(
                  onPressed: _busy ? null : _verifyOtp,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: _busy
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Verify & Continue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    final cs = Theme.of(context).colorScheme;
    return KeyboardListener(
      focusNode: FocusNode(skipTraversal: true), // Skip traversal so the listener itself isn't a tab stop
      onKeyEvent: (event) {
        // Detect backspace on an already empty field to move focus backward
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
          if (_controllers[index].text.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        }
      },
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        inputFormatters: [
          LengthLimitingTextInputFormatter(6), // Allow paste of full code
          FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.primary, width: 2),
          ),
        ),
        onChanged: (v) => _onChanged(v, index),
      ),
    );
  }
}
