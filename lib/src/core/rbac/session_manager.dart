import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_providers.dart';
import '../../auth/domain/app_user.dart';
import 'role.dart';

class SessionState {
  final AppUser? user;
  final Role? role;

  const SessionState({this.user, this.role});

  bool get isAuthenticated => user != null;
  String? get userId => user?.uid;
}

/// Manages the current active session, syncing with the authenticated user profile.
final sessionProvider = Provider<SessionState>((ref) {
  final userProfile = ref.watch(userProfileProvider).value;
  
  if (userProfile == null) {
    return const SessionState();
  }

  return SessionState(
    user: userProfile,
    role: userProfile.role,
  );
});
