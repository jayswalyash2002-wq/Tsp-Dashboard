import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/auth_providers.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../memberships/data/membership_providers.dart';

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
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _verifyOtp() async {
    if (_busy) return;
    final otp = _controllers.map((e) => e.text).join();
    if (otp.length < 6) {
      debugPrint('OTP: Code too short: $otp');
      return;
    }

    if (widget.verificationId.isEmpty) {
      debugPrint('OTP: Error - Verification ID is empty');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid verification session. Please go back and try again.')),
      );
      return;
    }

    setState(() => _busy = true);
    debugPrint('OTP: Starting verification for code: $otp with ID: ${widget.verificationId}');
    
    try {
      final repo = await ref.read(authRepositoryProvider.future);
      
      // Step 1: Verify Mock OTP
      debugPrint('OTP: Calling verifyOtp (Mock)...');
      final isValid = await repo.verifyOtp(
        verificationId: widget.verificationId,
        smsCode: otp,
      );
      
      if (!isValid) {
        throw Exception('Invalid verification code. Please try again.');
      }
      
      debugPrint('OTP: Verification Success.');

      // Step 2: Navigate to Register Details to complete account creation
      if (!mounted) return;
      
      debugPrint('OTP: Phone verified. Navigating to Register Details.');
      
      context.go(
        Uri(
          path: '/auth/register-details',
          queryParameters: {
            'email': widget.email,
            'phone': widget.phone,
            'name': widget.name,
            'password': widget.password,
          },
        ).toString(),
      );
    } catch (e) {
      debugPrint('OTP: Error during verification: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Code')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter 6-digit code',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Code sent to ${widget.phone}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: 45,
                  child: TextField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    decoration: const InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty && index < 5) {
                        _focusNodes[index + 1].requestFocus();
                      }
                      if (value.isEmpty && index > 0) {
                        _focusNodes[index - 1].requestFocus();
                      }
                      if (value.isNotEmpty && index == 5) {
                        _verifyOtp();
                      }
                    },
                  ),
                );
              }),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _busy ? null : _verifyOtp,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: _busy
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Verify & Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
