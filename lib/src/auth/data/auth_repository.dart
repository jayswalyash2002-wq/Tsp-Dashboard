import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/device/device_service.dart';
import '../../core/storage/prefs.dart';
import '../domain/device_session.dart';
import 'otp_service.dart';

class AuthRepository {
  AuthRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore db,
    required SharedPreferences prefs,
    required DeviceIdentity identity,
    required OtpService otpService,
  })  : _auth = auth,
        _db = db,
        _prefs = prefs,
        _identity = identity,
        _otpService = otpService;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final SharedPreferences _prefs;
  final DeviceIdentity _identity;
  final OtpService _otpService;

  User? get currentUser => _auth.currentUser;

  /// Temporary Demo OTP flow (Architecture-compatible)
  Future<void> sendOtp(
    String phoneNumber, {
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(Exception e) onVerificationFailed,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('AUTH: Initiating Mock OTP flow for $phoneNumber');
      }
      final verificationId = await _otpService.sendOtp(phoneNumber);
      onCodeSent(verificationId, null);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AUTH: Mock OTP failed: $e');
      }
      onVerificationFailed(e is Exception ? e : Exception(e.toString()));
    }
  }

  /// Verifies the mock OTP code.
  Future<bool> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    if (kDebugMode) {
      debugPrint('AUTH: Verifying Mock OTP code: $smsCode');
    }
    return await _otpService.verifyOtp(verificationId, smsCode);
  }

  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user;
    if (user == null) return;

    await user.reload(); // Ensure profile is fresh

    // Fetch and auto-set device name from Firestore if it exists
    final doc = await _db.collection('users').doc(user.uid).get();
    final name = doc.data()?['displayName'] as String? ?? user.displayName;
    if (name != null) {
      await setLocalDeviceName(name);
    }

    await _enforceOneDeviceSession(uid: user.uid);
  }

  Future<void> signUpWithEmailPassword({
    required String email,
    required String password,
    required String name,
    required String phoneNumber,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user;
    if (user == null) return;

    // 1. Update Firebase Auth Profile (immediate effect)
    await user.updateDisplayName(name.trim());
    await user.reload(); // Refresh local user state

    // 2. Save user details to Firestore
    await _db.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': email.trim(),
      'displayName': name.trim(),
      'phoneNumber': phoneNumber.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 3. Auto-set device name locally
    await setLocalDeviceName(name.trim());

    // 4. Initial heartbeat to register device
    await registerDeviceSession(deviceName: name.trim());
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data();
  }

  Stream<Map<String, dynamic>?> watchUserProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) => doc.data());
  }

  Future<void> signOut() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc(_identity.deviceId)
          .set({'active': false, 'lastSeenAtMs': DateTime.now().millisecondsSinceEpoch}, SetOptions(merge: true));
    }
    await _auth.signOut();
  }

  String? getLocalDeviceName() => _prefs.getString(PrefKeys.deviceName);

  Future<void> setLocalDeviceName(String name) async {
    await _prefs.setString(PrefKeys.deviceName, name.trim());
  }

  Future<void> registerDeviceSession({required String deviceName}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final session = DeviceSession(
      deviceId: _identity.deviceId,
      deviceName: deviceName.trim(),
      model: _identity.model,
      platform: _identity.platform,
      appVersion: _identity.appVersion,
      active: true,
      createdAtMs: now,
      lastSeenAtMs: now,
    );
    await _db
        .collection('users')
        .doc(user.uid)
        .collection('devices')
        .doc(_identity.deviceId)
        .set(session.toMap(), SetOptions(merge: true));
  }

  Future<void> heartbeat() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db
        .collection('users')
        .doc(user.uid)
        .collection('devices')
        .doc(_identity.deviceId)
        .set({'active': true, 'lastSeenAtMs': DateTime.now().millisecondsSinceEpoch}, SetOptions(merge: true));
  }

  /// "One-time login per device" + operational safety:
  /// - If this account already has another active device, block login.
  /// - This keeps the workflow simple and prevents shared credentials across devices.
  Future<void> _enforceOneDeviceSession({required String uid}) async {
    final devicesRef = _db.collection('users').doc(uid).collection('devices');
    final snap = await devicesRef.where('active', isEqualTo: true).get();
    for (final doc in snap.docs) {
      final deviceId = (doc.data()['deviceId'] ?? doc.id).toString();
      if (deviceId != _identity.deviceId) {
        throw FirebaseAuthException(
          code: 'device-session-exists',
          message:
              'This account is already active on another device. Please log out there first.',
        );
      }
    }
  }
}
