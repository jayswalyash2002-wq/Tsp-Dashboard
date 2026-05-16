import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/menu_item.dart';

class MenuRepository {
  MenuRepository(this._db);

  final FirebaseFirestore _db;

  Stream<List<MenuItem>> watchMenu() {
    return _db
        .collection('menu')
        .orderBy('name') // Simplified to one order field to avoid requiring an index
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => MenuItem.fromDoc(d.id, d.data()))
            .toList(growable: false));
  }

  Future<void> addMenuItem(MenuItem item) async {
    await _db.collection('menu').add({
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

