import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsp_dashboard/src/core/firebase/firebase_providers.dart';
import 'package:tsp_dashboard/src/constants/roles.dart';
import 'package:tsp_dashboard/src/auth/data/auth_providers.dart';
import '../../../memberships/data/membership_providers.dart';
import '../data/invite_service.dart';
import '../../rbac/domain/models/business_invite.dart';

final inviteServiceProvider = Provider<InviteService>((ref) {
  return InviteService(ref.watch(firestoreProvider));
});

final invitesStreamProvider = StreamProvider.family<List<InviteModel>, String>((ref, businessId) {
  final service = ref.watch(inviteServiceProvider);
  return service.watchInvites(businessId);
});

class CreateInviteNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async => null;

  Future<void> createInvite({
    required String staffName,
    required Role role,
    required String businessId,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final code = _generateInviteCode();
      final now = DateTime.now();
      
      final invite = InviteModel(
        code: code,
        businessId: businessId,
        staffName: staffName,
        role: role,
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 48)),
      );

      await ref.read(inviteServiceProvider).createInvite(invite);
      return code;
    });
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Excludes 0, O, 1, I
    final random = Random.secure();
    String gen() => List.generate(4, (index) => chars[random.nextInt(chars.length)]).join();
    return '${gen()}-${gen()}';
  }
}

final createInviteProvider = AsyncNotifierProvider<CreateInviteNotifier, String?>(() {
  return CreateInviteNotifier();
});

class ClaimInviteNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> claim({
    required String businessId,
    required String inviteCode,
  }) async {
    // Use direct Firebase Auth instance to avoid race conditions with Riverpod streams
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) {
      debugPrint('CLAIM_INVITE_NOTIFIER: Claim failed - No authenticated user found.');
      throw Exception('User not authenticated');
    }

    final displayName = user.displayName ?? 'New Member';
    final email = user.email ?? '';

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      debugPrint('STEP_2_CLAIM_INVITE_START: Business: $businessId, Code: $inviteCode');
      await ref.read(inviteServiceProvider).claimInvite(
            businessId: businessId,
            inviteCode: inviteCode,
            uid: user.uid,
            displayName: displayName,
            email: email,
          );
      
      debugPrint('STEP_3_MEMBER_CREATED: Claim finished in Firestore');
      
      // Invalidate profile and memberships to trigger refresh
      debugPrint('STEP_4_MEMBERSHIP_REFRESH: Invalidating providers');
      ref.invalidate(userProfileProvider);
      ref.invalidate(userMembershipsProvider);
    });
  }

  Future<InviteModel?> findInvite(String code) async {
    try {
      return await ref.read(inviteServiceProvider).findInviteByCode(code);
    } catch (e) {
      print('ClaimInviteNotifier: findInvite failed for code $code: $e');
      rethrow;
    }
  }
}

final claimInviteProvider = AsyncNotifierProvider.autoDispose<ClaimInviteNotifier, void>(() {
  return ClaimInviteNotifier();
});

/// Holds an invite that was validated BEFORE the user signed in.
final pendingInviteProvider = StateProvider<InviteModel?>((ref) => null);
