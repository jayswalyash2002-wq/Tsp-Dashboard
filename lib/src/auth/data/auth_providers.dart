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

final staffRepositoryProvider = Provider<StaffRepository>((ref) {
  return StaffRepository(ref.watch(firestoreProvider));
});

final staffListProvider = StreamProvider<List<AppUser>>((ref) {
  final user = ref.watch(userProfileProvider).value;
  if (user == null || user.businessId == null) return Stream.value([]);
  
  return ref.watch(staffRepositoryProvider).watchStaff(user.businessId!);
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
