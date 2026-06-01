import 'package:firebase_auth/firebase_auth.dart';
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

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _verifyOtp() async {
    if (_busy) return;
    final otp = _controllers.map((e) => e.text).join();
    
    if (otp.isEmpty) {
      _showError('Please enter the verification code.');
      return;
    }

    if (otp.length < 6) {
      _showError('Please enter all 6 digits of the code.');
      return;
    }

    if (widget.verificationId.isEmpty) {
      _showError('Invalid verification session. Please go back and try again.');
      return;
    }

    setState(() => _busy = true);
    try {
      final repo = await ref.read(authRepositoryProvider.future);
      
      // 1. Verify OTP Code
      final isValid = await repo.verifyOtp(
        verificationId: widget.verificationId,
        smsCode: otp,
      );

      if (!isValid) {
        _showError('The verification code you entered is incorrect.');
        setState(() => _busy = false);
        return;
      }

      // 2. Complete Sign Up
      await repo.signUpWithEmailPassword(
        email: widget.email,
        password: widget.password,
        name: widget.name,
        phoneNumber: widget.phone,
      );

      // Dismiss keyboard on success
      FocusManager.instance.primaryFocus?.unfocus();

      // Sync local state for AuthGate to bypass DeviceNameScreen
      ref.read(deviceNameProvider.notifier).state = widget.name;

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pushReplacement('/business-setup');
    } on FirebaseAuthException catch (e) {
      String message = 'Verification failed. Please try again.';
      switch (e.code) {
        case 'invalid-verification-code':
          message = 'The verification code you entered is incorrect.';
          break;
        case 'session-expired':
          message = 'This verification code has expired. Please request a new code.';
          break;
        case 'network-request-failed':
          message = 'Network error. Please check your internet connection.';
          break;
        case 'too-many-requests':
          message = 'Too many failed attempts. Please try again later.';
          break;
        case 'email-already-in-use':
          message = 'This email is already in use. Please use a different email.';
          break;
        default:
          message = e.message ?? message;
      }
      _showError(message);
    } catch (e) {
      _showError('Verification failed. Please try again.');
      debugPrint('OTP_VERIFY_ERROR: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onChanged(String value, int index) {
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
      focusNode: FocusNode(skipTraversal: true),
      onKeyEvent: (event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
          if (_controllers[index].text.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        }
      },
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        autofocus: index == 0,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        inputFormatters: [
          LengthLimitingTextInputFormatter(6),
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
