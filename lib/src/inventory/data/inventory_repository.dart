import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../domain/inventory_item.dart';

class InventoryRepository {
  final FirebaseFirestore _db;
  final String _businessId;

  InventoryRepository(this._db, this._businessId);

  CollectionReference get _inventoryColl => 
      _db.collection('businesses').doc(_businessId).collection('inventoryItems');

  Stream<List<InventoryItem>> watchInventory() {
    return _inventoryColl.snapshots().map((snap) => 
        snap.docs.map((d) => InventoryItem.fromMap(d.id, d.data() as Map<String, dynamic>)).toList());
  }

  Future<void> addInventoryItem(InventoryItem item) async {
    await _inventoryColl.add(item.toMap());
  }

  Future<void> updateInventoryItem(InventoryItem item) async {
    await _inventoryColl.doc(item.id).update(item.toMap());
  }

  Future<void> deleteInventoryItem(String id) async {
    await _inventoryColl.doc(id).delete();
  }

  Future<void> deductInventory(Map<String, int> deductions) async {
    if (deductions.isEmpty) return;

    await _db.runTransaction((transaction) async {
      final List<_InventoryUpdate> updates = [];

      // 1. READ PHASE
      for (final entry in deductions.entries) {
        final itemId = entry.key;
        final qtyToDeduct = entry.value;

        final docRef = _inventoryColl.doc(itemId);
        final snap = await transaction.get(docRef);

        if (snap.exists) {
          final data = snap.data() as Map<String, dynamic>;
          final currentStock = data['stock'] ?? 0;
          final itemName = data['name'] ?? 'Unknown';
          
          updates.add(_InventoryUpdate(
            ref: docRef,
            newStock: currentStock - qtyToDeduct,
            itemName: itemName,
            qtyDeducted: qtyToDeduct,
          ));
        } else {
          debugPrint('INVENTORY_REPO: WARNING - Inventory item $itemId not found for deduction');
        }
      }

      // 2. WRITE PHASE
      for (final update in updates) {
        debugPrint('INVENTORY_REPO: Deducting ${update.qtyDeducted} from ${update.itemName} (New Stock: ${update.newStock})');
        transaction.update(update.ref, {
          'stock': update.newStock,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> restoreInventory(Map<String, int> restorations) async {
    if (restorations.isEmpty) return;

    await _db.runTransaction((transaction) async {
      final List<_InventoryUpdate> updates = [];

      // 1. READ PHASE
      for (final entry in restorations.entries) {
        final itemId = entry.key;
        final qtyToRestore = entry.value;

        final docRef = _inventoryColl.doc(itemId);
        final snap = await transaction.get(docRef);

        if (snap.exists) {
          final currentStock = (snap.data() as Map<String, dynamic>)['stock'] ?? 0;
          updates.add(_InventoryUpdate(
            ref: docRef,
            newStock: currentStock + qtyToRestore,
          ));
        }
      }

      // 2. WRITE PHASE
      for (final update in updates) {
        transaction.update(update.ref, {
          'stock': update.newStock,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }
}

class _InventoryUpdate {
  final DocumentReference ref;
  final int newStock;
  final String? itemName;
  final int? qtyDeducted;

  _InventoryUpdate({
    required this.ref,
    required this.newStock,
    this.itemName,
    this.qtyDeducted,
  });
}
