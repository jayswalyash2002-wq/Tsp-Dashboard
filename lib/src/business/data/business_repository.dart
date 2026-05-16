import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../domain/business.dart';

class BusinessRepository {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  BusinessRepository(this._db, this._storage);

  Future<Business?> getBusiness(String businessId) async {
    final doc = await _db.collection('businesses').doc(businessId).get();
    if (!doc.exists) return null;
    return Business.fromMap(doc.data()!, doc.id);
  }

  Stream<Business?> watchBusiness(String businessId) {
    return _db
        .collection('businesses')
        .doc(businessId)
        .snapshots()
        .map((doc) => doc.exists ? Business.fromMap(doc.data()!, doc.id) : null);
  }

  Future<String> createBusiness({
    required String uid,
    required Business business,
  }) async {
    final batch = _db.batch();

    final businessRef = _db.collection('businesses').doc();
    final userRef = _db.collection('users').doc(uid);

    batch.set(businessRef, business.toMap());
    batch.update(userRef, {
      'businessId': businessRef.id,
      'role': 'owner',
    });

    await batch.commit();
    return businessRef.id;
  }

  Future<String?> uploadLogo(String businessId, File file) async {
    final ref = _storage.ref().child('businesses/$businessId/logo.png');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<void> updateBusiness(Business business) async {
    await _db.collection('businesses').doc(business.id).update(business.toMap());
  }
}
