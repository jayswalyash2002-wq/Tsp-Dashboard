import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_providers.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../activity_log/presentation/providers/activity_log_providers.dart';
import '../domain/business.dart';
import 'business_repository.dart';

final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

final businessRepositoryProvider = Provider<BusinessRepository>((ref) {
  return BusinessRepository(
    ref.watch(firestoreProvider),
    ref.watch(activityLogRepositoryProvider),
  );
});

final currentBusinessProvider = StreamProvider<Business?>((ref) {
  final businessId = ref.watch(userBusinessIdProvider);
  if (businessId == null) return Stream.value(null);
  
  return ref.watch(businessRepositoryProvider).watchBusiness(businessId);
});
