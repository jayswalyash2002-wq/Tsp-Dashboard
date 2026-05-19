import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/menu_item.dart';

class MenuRepository {
  MenuRepository(this._db, this._businessId);

  final FirebaseFirestore _db;
  final String _businessId;

  Stream<List<MenuItem>> watchMenu() {
    return _db
        .collection('menu')
        .where('businessId', isEqualTo: _businessId)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => MenuItem.fromDoc(d.id, d.data()))
            .toList(growable: false));
  }

  Future<void> addMenuItem(MenuItem item) async {
    await _db.collection('menu').add({
      'businessId': _businessId,
      'name': item.name,
      'pricePaise': item.pricePaise,
      'category': item.category,
      'available': item.available,
      'sortOrder': item.sortOrder,
      'categorySortOrder': item.categorySortOrder,
    });
  }

  Future<void> updateMenuItem(MenuItem item) async {
    await _db.collection('menu').doc(item.id).set({
      'businessId': _businessId,
      'name': item.name,
      'pricePaise': item.pricePaise,
      'category': item.category,
      'available': item.available,
      'sortOrder': item.sortOrder,
      'categorySortOrder': item.categorySortOrder,
    }, SetOptions(merge: true));
  }

  Future<void> deleteMenuItem(String id) async {
    await _db.collection('menu').doc(id).delete();
  }
}

