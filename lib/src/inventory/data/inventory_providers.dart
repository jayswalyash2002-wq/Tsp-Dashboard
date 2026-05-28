import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_providers.dart';
import '../../core/firebase/firebase_providers.dart';
import '../domain/inventory_item.dart';
import 'inventory_repository.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository?>((ref) {
  final businessId = ref.watch(userBusinessIdProvider);
  if (businessId == null) return null;
  return InventoryRepository(
    ref.watch(firestoreProvider),
    businessId,
  );
});

final inventoryStreamProvider = StreamProvider<List<InventoryItem>>((ref) {
  final repo = ref.watch(inventoryRepositoryProvider);
  if (repo == null) return Stream.value([]);
  return repo.watchInventory();
});

final hasLowStockProvider = Provider<bool>((ref) {
  final items = ref.watch(inventoryStreamProvider).value ?? [];
  return items.any((item) => item.isLowStock);
});
