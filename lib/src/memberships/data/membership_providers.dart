import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/firebase/firebase_providers.dart';
import '../domain/membership.dart';
import 'membership_repository.dart';

final membershipRepositoryProvider = Provider<MembershipRepository>((ref) {
  return MembershipRepository(ref.watch(firestoreProvider));
});

/// Internal provider for legacy membership structure
final legacyMembershipsProvider = StreamProvider<List<Membership>>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return Stream.value([]);
  
  final db = ref.watch(firestoreProvider);
  return db
      .collection('memberships')
      .where('uid', isEqualTo: user.uid)
      .where('status', isEqualTo: 'active')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Membership.fromMap(doc.data(), doc.id))
          .toList());
});

/// Internal provider for new multi-tenant membership structure
final newMembershipsProvider = StreamProvider<List<Membership>>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return Stream.value([]);
  
  final db = ref.watch(firestoreProvider);
  return db
      .collectionGroup('members')
      .where('uid', isEqualTo: user.uid)
      .where('status', isEqualTo: 'active')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Membership.fromMap(doc.data(), doc.id))
          .toList());
});

/// Unified provider that combines both legacy and new membership structures.
/// This ensures existing users and new staff members are all correctly restored.
final userMembershipsProvider = Provider<AsyncValue<List<Membership>>>((ref) {
  final legacy = ref.watch(legacyMembershipsProvider);
  final newOnes = ref.watch(newMembershipsProvider);

  if (legacy.isLoading || newOnes.isLoading) return const AsyncLoading();
  
  if (legacy.hasError || newOnes.hasError) {
    debugPrint('MEMBERSHIP_ERROR: Legacy Error: ${legacy.error}');
    debugPrint('MEMBERSHIP_ERROR: NewOnes Error: ${newOnes.error}');
    // If one fails, we still try to show the other if possible, 
    // but if both fail or it's a critical error (like permission denied), 
    // we should ideally report it.
    if (legacy.hasError && newOnes.hasError) {
      return AsyncError(legacy.error!, legacy.stackTrace!);
    }
  }

  final legacyList = legacy.value ?? [];
  final newList = newOnes.value ?? [];
  
  final combined = [...legacyList, ...newList];
  final seenBusinessIds = <String>{};
  final result = <Membership>[];
  
  for (final m in combined) {
    if (m.businessId.isNotEmpty && seenBusinessIds.add(m.businessId)) {
      result.add(m);
    }
  }
  
  debugPrint('MEMBERSHIP_SYNC: Found ${result.length} unique memberships for user');
  return AsyncData(result);
});

class SessionState {
  final String? businessId;
  final String? userUid;
  final MembershipRole? role;
  final String? membershipId;
  final String? branchId;
  final bool isLoaded;

  SessionState({
    this.businessId,
    this.userUid,
    this.role,
    this.membershipId,
    this.branchId,
    this.isLoaded = false,
  });

  factory SessionState.empty() => SessionState(isLoaded: false);
}

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier() : super(SessionState());

  void setSession({
    required String businessId,
    required String userUid,
    required MembershipRole role,
    required String membershipId,
    String? branchId,
  }) {
    if (kDebugMode) {
      debugPrint('SESSION: Setting active session. Business: $businessId, Role: ${role.name}');
    }
    state = SessionState(
      businessId: businessId,
      userUid: userUid,
      role: role,
      membershipId: membershipId,
      branchId: branchId,
      isLoaded: true,
    );
  }

  void clear() {
    state = SessionState(isLoaded: false);
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier();
});
