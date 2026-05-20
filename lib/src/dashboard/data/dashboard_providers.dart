import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../activity_log/presentation/providers/activity_log_providers.dart';
import '../../auth/data/auth_providers.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/utils/business_date_utils.dart';
import '../domain/menu_item.dart';
import '../domain/order_models.dart';
import 'menu_repository.dart';
import 'order_repository.dart';
import 'session_repository.dart';
import '../domain/business_session.dart';

final menuRepositoryProvider = Provider<MenuRepository?>((ref) {
  final businessId = ref.watch(userBusinessIdProvider);
  if (businessId == null) return null;
  return MenuRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
    businessId,
  );
});

final menuItemsProvider = StreamProvider<List<MenuItem>>((ref) {
  final repo = ref.watch(menuRepositoryProvider);
  if (repo == null) return Stream.value([]);
  return repo.watchMenu();
});

final orderRepositoryProvider = FutureProvider<OrderRepository?>((ref) async {
  final businessId = ref.watch(userBusinessIdProvider);
  if (businessId == null) return null;

  final db = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);
  final authRepo = await ref.watch(authRepositoryProvider.future);
  final activityLogRepo = ref.watch(activityLogRepositoryProvider);

  return OrderRepository(
    db: db,
    auth: auth,
    authRepo: authRepo,
    activityLogRepo: activityLogRepo,
    businessId: businessId,
  );
});

final ordersProvider = StreamProvider<List<SavedOrder>>((ref) async* {
  final repo = await ref.watch(orderRepositoryProvider.future);
  if (repo == null) {
    yield [];
  } else {
    yield* repo.watchOrders();
  }
});

final activeKitchenOrdersProvider = StreamProvider<List<SavedOrder>>((ref) async* {
  final repo = await ref.watch(orderRepositoryProvider.future);
  if (repo == null) {
    yield [];
  } else {
    yield* repo.watchActiveKitchenOrders();
  }
});

final sessionRepositoryProvider = Provider<SessionRepository?>((ref) {
  final businessId = ref.watch(userBusinessIdProvider);
  if (businessId == null) return null;
  return SessionRepository(ref.watch(firestoreProvider), businessId);
});

final currentSessionProvider = StreamProvider<BusinessSession?>((ref) {
  final repo = ref.watch(sessionRepositoryProvider);
  if (repo == null) return Stream.value(null);
  return repo.watchCurrentSession();
});

final effectiveBusinessDateProvider = Provider<DateTime>((ref) {
  final session = ref.watch(currentSessionProvider).value;
  if (session != null && session.isOpen) {
    return session.parsedBusinessDate;
  }
  return BusinessDateUtils.getBusinessDate(DateTime.now());
});
