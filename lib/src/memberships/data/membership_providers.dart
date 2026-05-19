import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/firebase/firebase_providers.dart';
import '../domain/membership.dart';
import 'membership_repository.dart';

final membershipRepositoryProvider = Provider<MembershipRepository>((ref) {
  return MembershipRepository(ref.watch(firestoreProvider));
});

final userMembershipsProvider = StreamProvider<List<Membership>>((ref) {
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

  factory SessionState.empty() => SessionState(isLoaded: true);
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
    debugPrint('SESSION: Setting active session. Business: $businessId, Role: ${role.name}');
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
    state = SessionState(isLoaded: true);
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier();
});
