import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/device/device_service.dart';
import '../../core/storage/prefs.dart';
import '../domain/device_session.dart';

class AuthRepository {
  AuthRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore db,
    required SharedPreferences prefs,
    required DeviceIdentity identity,
  })  : _auth = auth,
        _db = db,
        _prefs = prefs,
        _identity = identity;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final SharedPreferences _prefs;
  final DeviceIdentity _identity;
  
  // Simulated OTP storage for demonstration
  static final Map<String, String> _tempOtps = {};

  User? get currentUser => _auth.currentUser;

  Future<void> sendOtp(String email) async {
    // For development, we'll use a fixed code 123456 or generate one
    final code = '123456'; 
    _tempOtps[email.trim()] = code;
    
    debugPrint('DEBUG: OTP for $email is $code');
    
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
  }

  Future<bool> verifyOtp(String email, String otp) async {
    await Future.delayed(const Duration(milliseconds: 500));
    // Always allow 123456 for testing
    if (otp == '123456') return true;
    return _tempOtps[email.trim()] == otp;
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

