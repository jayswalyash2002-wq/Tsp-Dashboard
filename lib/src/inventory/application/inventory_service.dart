import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../activity_log/domain/entities/activity_log_enums.dart';
import '../../activity_log/presentation/providers/activity_log_providers.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../dashboard/domain/order_models.dart';
import '../data/inventory_providers.dart';
import '../data/inventory_repository.dart';
import '../domain/inventory_item.dart';

/// A service class that handles inventory-related business logic and coordinates
/// between the inventory repository, Firestore, and activity logging.
class InventoryService {
  final Ref _ref;
  final InventoryRepository? _inventoryRepo;
  final FirebaseFirestore _db;

  /// Creates an instance of [InventoryService].
  InventoryService(this._ref, this._inventoryRepo, this._db);

  /// Adds a new [InventoryItem] to the repository and logs the activity.
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

  /// Updates an existing [InventoryItem].
  /// 
  /// If the stock level has changed, it logs an [ActivityAction.inventoryStockAdjusted].
  /// Otherwise, it logs an [ActivityAction.inventoryItemModified].
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

  /// Deletes an [InventoryItem] and logs the activity.
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

  /// Deducts inventory stock based on the [OrderLine]s in an order.
  /// 
  /// It iterates through each line, checks for consumable mappings, and
  /// performs a bulk deduction via the repository. It also updates the
  /// order's `inventoryDeducted` flag in Firestore.
  Future<void> deductForOrder(List<OrderLine> lines, String orderId) async {
    if (_inventoryRepo == null) return;

    final Map<String, int> totalDeductions = {};
    for (final line in lines) {
      final mappings = line.item.consumableMappings;
      debugPrint('INVENTORY_SERVICE: Item "${line.item.name}" has mappings: $mappings');
      
      if (mappings.isEmpty) continue;

      mappings.forEach((itemId, qty) {
        final totalQty = qty * line.qty;
        totalDeductions[itemId] = (totalDeductions[itemId] ?? 0) + totalQty;
      });
    }

    if (totalDeductions.isNotEmpty) {
      debugPrint('INVENTORY_SERVICE: Deducting from inventory: $totalDeductions');
      await _inventoryRepo.deductInventory(totalDeductions);
      
      // Update order flag
      await _db.collection('orders').doc(orderId).update({
        'inventoryDeducted': true,
      });
      // ...

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

  /// Restores inventory stock for a [SavedOrder] that was previously deducted.
  /// 
  /// This is typically used when an order is cancelled. It updates the
  /// order's flags in Firestore to reflect the restoration.
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

/// Provider for the [InventoryService] instance.
final inventoryServiceProvider = Provider<InventoryService>((ref) {
  return InventoryService(
    ref,
    ref.watch(inventoryRepositoryProvider),
    ref.watch(firestoreProvider),
  );
});
