import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/inventory_item.dart';

class InventoryRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final String _businessId;

  InventoryRepository(this._db, this._auth, this._businessId);

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
      for (final entry in deductions.entries) {
        final itemId = entry.key;
        final qtyToDeduct = entry.value;

        final docRef = _inventoryColl.doc(itemId);
        final snap = await transaction.get(docRef);

        if (snap.exists) {
          final data = snap.data() as Map<String, dynamic>;
          final currentStock = data['stock'] ?? 0;
          final itemName = data['name'] ?? 'Unknown';
          
          debugPrint('INVENTORY_REPO: Deducting $qtyToDeduct from $itemName (Current: $currentStock)');
          
          transaction.update(docRef, {
            'stock': currentStock - qtyToDeduct,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          debugPrint('INVENTORY_REPO: WARNING - Inventory item $itemId not found for deduction');
        }
      }
    });
  }

  Future<void> restoreInventory(Map<String, int> restorations) async {
    if (restorations.isEmpty) return;

    await _db.runTransaction((transaction) async {
      for (final entry in restorations.entries) {
        final itemId = entry.key;
        final qtyToRestore = entry.value;

        final docRef = _inventoryColl.doc(itemId);
        final snap = await transaction.get(docRef);

        if (snap.exists) {
          final currentStock = (snap.data() as Map<String, dynamic>)['stock'] ?? 0;
          transaction.update(docRef, {
            'stock': currentStock + qtyToRestore,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    });
  }
}
