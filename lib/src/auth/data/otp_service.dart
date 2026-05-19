import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Abstract interface for OTP operations to allow swapping providers later.
abstract class OtpService {
  Future<String> sendOtp(String phoneNumber);
  Future<bool> verifyOtp(String verificationId, String code);
}

/// Mock implementation for development and stabilization.
class MockOtpService implements OtpService {
  // Simple in-memory storage for active verification sessions
  final Map<String, String> _sessions = {};
  final String _demoOtp = '123456';

  @override
  Future<String> sendOtp(String phoneNumber) async {
    debugPrint('MOCK_OTP: Sending demo OTP ($_demoOtp) to $phoneNumber');
    
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    
    final verificationId = const Uuid().v4();
    _sessions[verificationId] = _demoOtp;
    
    return verificationId;
  }

  @override
  Future<bool> verifyOtp(String verificationId, String code) async {
    debugPrint('MOCK_OTP: Verifying code $code for session $verificationId');
    
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (!_sessions.containsKey(verificationId)) {
      debugPrint('MOCK_OTP: Session not found');
      return false;
    }

    final isValid = _sessions[verificationId] == code;
    
    if (isValid) {
      _sessions.remove(verificationId);
    }
    
    return isValid;
  }
}
