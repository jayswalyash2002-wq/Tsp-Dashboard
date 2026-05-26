import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/device/device_providers.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/storage/prefs.dart';
import '../domain/app_user.dart';
import 'auth_repository.dart';
import 'staff_repository.dart';
import 'otp_service.dart';

import '../../memberships/data/membership_providers.dart';

final otpServiceProvider = Provider<OtpService>((ref) {
  return MockOtpService();
});

final authRepositoryProvider = FutureProvider<AuthRepository>((ref) async {
  final auth = ref.watch(firebaseAuthProvider);
  final db = ref.watch(firestoreProvider);
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  final identity = await ref.watch(deviceIdentityProvider.future);
  final otpService = ref.watch(otpServiceProvider);
  
  return AuthRepository(
    auth: auth, 
    db: db, 
    prefs: prefs, 
    identity: identity,
    otpService: otpService,
  );
});

/// Central provider for the current active business ID.
/// All multi-tenant data providers should depend on this.
final userBusinessIdProvider = Provider<String?>((ref) {
  final session = ref.watch(sessionProvider);
  return session.businessId;
});

final staffRepositoryProvider = Provider<StaffRepository?>((ref) {
  final businessId = ref.watch(userBusinessIdProvider);
  if (businessId == null) return null;
  return StaffRepository(ref.watch(firestoreProvider), businessId);
});

final staffListProvider = StreamProvider<List<AppUser>>((ref) {
  final repo = ref.watch(staffRepositoryProvider);
  if (repo == null) return Stream.value([]);
  
  return repo.watchStaff();
});

final deviceNameProvider = StateProvider<String?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).maybeWhen(
        data: (p) => p,
        orElse: () => null,
      );
  return prefs?.getString(PrefKeys.deviceName);
});

final userProfileProvider = StreamProvider<AppUser?>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) {
    return Stream.value(null);
  }

  final db = ref.watch(firestoreProvider);
  final businessId = ref.watch(userBusinessIdProvider);

  if (businessId != null) {
    final controller = StreamController<AppUser?>();
    
    Map<String, dynamic>? userData;
    Map<String, dynamic>? memberData;
    bool userLoaded = false;
    bool memberLoaded = false;

    void emit() {
      if (!userLoaded) return;
      
      final effectiveUserData = userData ?? {};
      final effectiveMemberData = memberData ?? {};
      
      // FALLBACK LOGIC: 
      // If member document doesn't have a role, look for it in effectiveUserData or the session state.
      final String? roleFromMember = effectiveMemberData['role'] as String?;
      final String? roleFromUser = effectiveUserData['role'] as String?;
      final String? sessionRole = ref.read(sessionProvider).role?.name;
      
      final effectiveRole = roleFromMember ?? roleFromUser ?? sessionRole;
      
      if (kDebugMode) {
        debugPrint('USER_PROFILE_SYNC: UID: ${user.uid}, RoleSource: ${roleFromMember != null ? 'member' : (roleFromUser != null ? 'user' : 'session')}, Role: $effectiveRole');
      }

      controller.add(AppUser.fromMap({
        ...effectiveUserData,
        'uid': user.uid,
        if (effectiveRole != null) 'role': effectiveRole,
        if (effectiveMemberData.containsKey('permissions')) 'permissions': effectiveMemberData['permissions'],
        'businessId': businessId,
        'isActive': effectiveMemberData['status'] == 'accepted' || 
                   effectiveMemberData['status'] == 'active' ||
                   (!memberLoaded && (effectiveUserData['isActive'] ?? true)) || 
                   (memberLoaded && effectiveMemberData.isEmpty && (effectiveUserData['isActive'] ?? true)),
      }));
    }

    final userSub = db.collection('users').doc(user.uid).snapshots().listen((snap) {
      userData = snap.data();
      userLoaded = true;
      emit();
    }, onError: (e) => controller.addError(e));

    final memberSub = db.collection('businesses').doc(businessId).collection('members').doc(user.uid).snapshots().listen((snap) {
      memberData = snap.data();
      memberLoaded = true;
      emit();
    }, onError: (e) => controller.addError(e));

    ref.onDispose(() {
      userSub.cancel();
      memberSub.cancel();
      controller.close();
    });

    return controller.stream;
  } else {
    return db.collection('users').doc(user.uid).snapshots().map((snap) {
      final data = snap.data();
      return data != null ? AppUser.fromMap(data) : null;
    });
  }
});
