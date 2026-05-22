import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../activity_log/domain/entities/activity_log_enums.dart';
import '../../activity_log/presentation/providers/activity_log_providers.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../dashboard/domain/order_models.dart';
import '../data/inventory_providers.dart';
import '../data/inventory_repository.dart';
import '../domain/inventory_item.dart';

class InventoryService {
  final Ref _ref;
  final InventoryRepository? _inventoryRepo;
  final FirebaseFirestore _db;

  InventoryService(this._ref, this._inventoryRepo, this._db);

  Future<void> addItem(InventoryItem item) async {
    if (_inventoryRepo == null) return;
    await _inventoryRepo.addInventoryItem(item);
    
    await _ref.read(logActivityUseCaseProvider).execute(
      action: ActivityAction.inventoryItemAdded,
      category: ActivityCategory.operational,
      targetType: 'inventory',
      targetName: item.name,
      metadata: {
        'initialStock': item.stock,
        'unit': item.unit,
      },
    );
  }

  Future<void> updateItem(InventoryItem oldItem, InventoryItem newItem) async {
    if (_inventoryRepo == null) return;
    await _inventoryRepo.updateInventoryItem(newItem);

    if (oldItem.stock != newItem.stock) {
      await _ref.read(logActivityUseCaseProvider).execute(
        action: ActivityAction.inventoryStockAdjusted,
        category: ActivityCategory.operational,
        targetType: 'inventory',
        targetId: newItem.id,
        targetName: newItem.name,
        metadata: {
          'previousStock': oldItem.stock,
          'newStock': newItem.stock,
        },
      );
    } else {
      await _ref.read(logActivityUseCaseProvider).execute(
        action: ActivityAction.inventoryItemModified,
        category: ActivityCategory.operational,
        targetType: 'inventory',
        targetId: newItem.id,
        targetName: newItem.name,
      );
    }
  }

  Future<void> deleteItem(InventoryItem item) async {
    if (_inventoryRepo == null) return;
    await _inventoryRepo.deleteInventoryItem(item.id);

    await _ref.read(logActivityUseCaseProvider).execute(
      action: ActivityAction.inventoryItemDeleted,
      category: ActivityCategory.operational,
      targetType: 'inventory',
      targetId: item.id,
      targetName: item.name,
    );
  }

  Future<void> deductForOrder(List<OrderLine> lines, String orderId) async {
    if (_inventoryRepo == null) return;

    final Map<String, int> totalDeductions = {};
    for (final line in lines) {
      final mappings = line.item.consumableMappings;
      if (mappings.isEmpty) continue;

      mappings.forEach((itemId, qty) {
        final totalQty = qty * line.qty;
        totalDeductions[itemId] = (totalDeductions[itemId] ?? 0) + totalQty;
      });
    }

    if (totalDeductions.isNotEmpty) {
      await _inventoryRepo.deductInventory(totalDeductions);
      
      // Update order flag
      await _db.collection('orders').doc(orderId).update({
        'inventoryDeducted': true,
      });

      final orderItems = lines.map((l) => l.item.name).join(', ');

      await _ref.read(logActivityUseCaseProvider).execute(
        action: ActivityAction.inventoryDeducted,
        category: ActivityCategory.operational,
        targetType: 'order',
        targetId: orderId,
        targetName: 'Order #${orderId.substring(0, 4)}',
        metadata: {
          'summary': totalDeductions,
          'orderItems': orderItems,
        },
      );
    }
  }

  Future<void> restoreForOrder(SavedOrder order) async {
    if (_inventoryRepo == null) return;
    if (!order.inventoryDeducted) return;

    final Map<String, int> totalRestorations = {};
    for (final line in order.lines) {
      final mappings = line.item.consumableMappings;
      if (mappings.isEmpty) continue;

      mappings.forEach((itemId, qty) {
        final totalQty = qty * line.qty;
        totalRestorations[itemId] = (totalRestorations[itemId] ?? 0) + totalQty;
      });
    }

    if (totalRestorations.isNotEmpty) {
      await _inventoryRepo.restoreInventory(totalRestorations);

      // Update order flag
      await _db.collection('orders').doc(order.id).update({
        'inventoryDeducted': false,
        'inventoryRestored': true,
      });

      await _ref.read(logActivityUseCaseProvider).execute(
        action: ActivityAction.inventoryStockAdjusted,
        category: ActivityCategory.operational,
        targetType: 'order',
        targetId: order.id,
        targetName: 'Order #${order.id.substring(0, 4)}',
        metadata: {
          'summary': totalRestorations,
          'reason': 'Order Cancelled',
          'orderItems': order.lines.map((l) => l.item.name).join(', '),
        },
      );
    }
  }
}

final inventoryServiceProvider = Provider<InventoryService>((ref) {
  return InventoryService(
    ref,
    ref.watch(inventoryRepositoryProvider),
    ref.watch(firestoreProvider),
  );
});
