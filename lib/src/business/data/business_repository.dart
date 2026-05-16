import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../domain/business.dart';

class BusinessRepository {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  BusinessRepository(this._db, this._storage);

  String _generateUIN() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Exclude ambiguous chars like O, 0, I, 1
    final rnd = Random();
    final code = String.fromCharCodes(Iterable.generate(
      6,
      (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
    ));
    return 'TSP-$code';
  }

  Future<String> _generateUniqueUIN() async {
    String uin;
    bool exists;
    do {
      uin = _generateUIN();
      final doc = await _db.collection('businesses').doc(uin).get();
      exists = doc.exists;
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

  Future<String> createBusiness({
    required String uid,
    required Business business,
  }) async {
    final uin = await _generateUniqueUIN();
    final batch = _db.batch();

    final businessRef = _db.collection('businesses').doc(uin);
    final userRef = _db.collection('users').doc(uid);

    final finalBusiness = Business(
      id: uin,
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

    batch.set(businessRef, finalBusiness.toMap());
    batch.set(
      userRef,
      {
        'businessId': uin,
        'role': 'admin',
      },
      SetOptions(merge: true),
    );

    await batch.commit();
    return uin;
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
