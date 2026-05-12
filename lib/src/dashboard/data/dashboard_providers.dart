import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_providers.dart';
import '../../core/firebase/firebase_providers.dart';
import '../domain/menu_item.dart';
import 'menu_repository.dart';
import 'order_repository.dart';

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
