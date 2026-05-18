import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../domain/business.dart';
import '../../core/utils/uin_generator.dart';

class BusinessRepository {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  BusinessRepository(this._db, this._storage);

  Future<String> _generateUniqueUIN({String? city}) async {
    String uin;
    bool exists;
    do {
      uin = UINGenerator.generateBusinessUIN(city: city);
      final snap = await _db.collection('businesses').where('uin', isEqualTo: uin).get();
      exists = snap.docs.isNotEmpty;
    } while (exists);
    return uin;
  }

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

  Future<Business> createBusiness({
    required String uid,
    required Business business,
  }) async {
    // 1. Generate a unique human-readable UIN using the selected city
    final uin = await _generateUniqueUIN(city: business.city);
    
    // 2. Use a standard Firestore ID for the document
    final businessRef = _db.collection('businesses').doc();
    final businessId = businessRef.id;
    
    final userRef = _db.collection('users').doc(uid);

    final finalBusiness = Business(
      id: businessId,
      uin: uin,
      businessName: business.businessName,
      ownerName: business.ownerName,
      officialEmail: business.officialEmail,
      phoneNumber: business.phoneNumber,
      businessType: business.businessType,
      gstNumber: business.gstNumber,
      isFssaiRegistered: business.isFssaiRegistered,
      fssaiNumber: business.fssaiNumber,
      address: business.address,
      logoUrl: business.logoUrl,
      createdAt: DateTime.now(),
    );

    final batch = _db.batch();
    batch.set(businessRef, finalBusiness.toMap());
    batch.set(
      userRef,
      {
        'businessId': businessId,
        'role': 'admin',
      },
      SetOptions(merge: true),
    );

    await batch.commit();
    return finalBusiness;
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
