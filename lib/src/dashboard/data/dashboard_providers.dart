import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_providers.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/utils/business_date_utils.dart';
import '../domain/menu_item.dart';
import '../domain/order_models.dart';
import 'menu_repository.dart';
import 'order_repository.dart';
import 'session_repository.dart';
import '../domain/business_session.dart';

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  return MenuRepository(ref.watch(firestoreProvider));
});

final menuItemsProvider = StreamProvider<List<MenuItem>>((ref) {
  return ref.watch(menuRepositoryProvider).watchMenu();
});

final orderRepositoryProvider = FutureProvider<OrderRepository>((ref) async {
  final db = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);
  final authRepo = await ref.watch(authRepositoryProvider.future);
  return OrderRepository(db: db, auth: auth, authRepo: authRepo);
});

final ordersProvider = StreamProvider<List<SavedOrder>>((ref) async* {
  final repo = await ref.watch(orderRepositoryProvider.future);
  yield* repo.watchOrders();
});

final activeKitchenOrdersProvider = StreamProvider<List<SavedOrder>>((ref) async* {
  final repo = await ref.watch(orderRepositoryProvider.future);
  yield* repo.watchActiveKitchenOrders();
});

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(ref.watch(firestoreProvider));
});

final currentSessionProvider = StreamProvider<BusinessSession?>((ref) {
  return ref.watch(sessionRepositoryProvider).watchCurrentSession();
});

final effectiveBusinessDateProvider = Provider<DateTime>((ref) {
  final session = ref.watch(currentSessionProvider).value;
  if (session != null && session.isOpen) {
    return session.parsedBusinessDate;
  }
  return BusinessDateUtils.getBusinessDate(DateTime.now());
});
