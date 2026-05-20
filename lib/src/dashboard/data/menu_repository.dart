import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../domain/menu_item.dart';

class MenuRepository {
  MenuRepository(this._db, this._auth, this._businessId);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final String _businessId;

  Stream<List<MenuItem>> watchMenu() {
    if (kDebugMode) {
      debugPrint('MENU_REPO: Watching menu for businessId: $_businessId');
    }
    return _db
        .collection('menu')
        .where('businessId', isEqualTo: _businessId)
        .where('isDeleted', isNotEqualTo: true)
        .snapshots()
        .map((snap) {
      final items = snap.docs
          .map((d) => MenuItem.fromDoc(d.id, d.data()))
          .toList(growable: false);
      
      // Filter out any items that might have leaked if Firestore rules are weak
      // or if where() was bypassed somehow (client-side safety)
      return items.where((item) => item.businessId == _businessId).toList();
    });
  }

  Future<void> addMenuItem(MenuItem item) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');

    if (kDebugMode) {
      debugPrint('MENU_REPO: Adding menu item for businessId: $_businessId');
    }
    await _db.collection('menu').add({
      'businessId': _businessId,
      'name': item.name,
      'pricePaise': item.pricePaise,
      'category': item.category,
      'available': item.available,
      'sortOrder': item.sortOrder,
      'categorySortOrder': item.categorySortOrder,
      'isDeleted': false,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateMenuItem(MenuItem item) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');

    if (kDebugMode) {
      debugPrint('MENU_REPO: Updating menu item ${item.id} for businessId: $_businessId');
    }
    
    final docRef = _db.collection('menu').doc(item.id);
    
    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) {
        throw Exception('Menu item not found');
      }
      
      final data = snap.data()!;
      final existingBusinessId = data['businessId']?.toString();
      
      if (existingBusinessId != _businessId) {
        if (kDebugMode) {
          debugPrint('CRITICAL: Blocked unauthorized update attempt on menu item ${item.id}. '
              'Expected: $_businessId, Found: $existingBusinessId');
        }
        throw Exception('Access Denied: Business ownership mismatch');
      }

      tx.set(docRef, {
        'businessId': _businessId,
        'name': item.name,
        'pricePaise': item.pricePaise,
        'category': item.category,
        'available': item.available,
        'sortOrder': item.sortOrder,
        'categorySortOrder': item.categorySortOrder,
        'isDeleted': item.isDeleted,
        'updatedBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> deleteMenuItem(String id) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');

    if (kDebugMode) {
      debugPrint('MENU_REPO: Soft-deleting menu item $id for businessId: $_businessId');
    }
    
    final docRef = _db.collection('menu').doc(id);
    
    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return;
      
      final data = snap.data()!;
      if (data['businessId'] != _businessId) {
        throw Exception('Access Denied');
      }

      tx.update(docRef, {
        'isDeleted': true,
        'updatedBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
