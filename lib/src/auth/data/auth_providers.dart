import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/device/device_providers.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/storage/prefs.dart';
import '../domain/app_user.dart';
import 'auth_repository.dart';
import 'staff_repository.dart';

final authRepositoryProvider = FutureProvider<AuthRepository>((ref) async {
  final auth = ref.watch(firebaseAuthProvider);
  final db = ref.watch(firestoreProvider);
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  final identity = await ref.watch(deviceIdentityProvider.future);
  return AuthRepository(auth: auth, db: db, prefs: prefs, identity: identity);
});

/// Central provider for the current active business ID.
/// All multi-tenant data providers should depend on this.
final userBusinessIdProvider = Provider<String?>((ref) {
  final profile = ref.watch(userProfileProvider).value;
  return profile?.businessId;
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

final userProfileProvider = StreamProvider<AppUser?>((ref) async* {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) {
    yield null;
  } else {
    final repo = await ref.watch(authRepositoryProvider.future);
    yield* repo.watchUserProfile(user.uid).map((map) => map != null ? AppUser.fromMap(map) : null);
  }
});
