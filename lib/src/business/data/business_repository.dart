import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../domain/business.dart';
import '../../core/utils/uin_generator.dart';

class BusinessRepository {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  BusinessRepository(this._db, this._storage);

  Future<int> _getNextSequence(String counterName) async {
    final counterRef = _db.collection('metadata').doc('counters');
    
    return await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);
      
      if (!snapshot.exists) {
        transaction.set(counterRef, {counterName: 1});
        return 1;
      }
      
      final data = snapshot.data()!;
      final int current = data[counterName] ?? 0;
      final int next = current + 1;
      
      transaction.update(counterRef, {counterName: next});
      return next;
    });
  }

  Future<String> _generateDisplayUIN({required String type}) async {
    final sequence = await _getNextSequence(type.toLowerCase());
    return UINGenerator.generateUIN(type: type, sequence: sequence);
  }

  Future<Business?> getBusiness(String businessId) async {
    final doc = await _db.collection('businesses').doc(businessId).get();
    if (!doc.exists) return null;
    
    Business business = Business.fromMap(doc.data()!, doc.id);
    
    // Backfill UIN if missing (Production-safe migration)
    if (business.uin.isEmpty) {
      final newUin = await _generateDisplayUIN(type: 'BIZ');
      business = business.copyWith(uin: newUin);
      await _db.collection('businesses').doc(businessId).update({'uin': newUin});
    }
    
    return business;
  }

  Stream<Business?> watchBusiness(String businessId) {
    return _db
        .collection('businesses')
        .doc(businessId)
        .snapshots()
        .asyncMap((doc) async {
          if (!doc.exists) return null;
          Business business = Business.fromMap(doc.data()!, doc.id);
          
          // Backfill UIN if missing during stream observation
          if (business.uin.isEmpty) {
            final newUin = await _generateDisplayUIN(type: 'BIZ');
            await _db.collection('businesses').doc(businessId).update({'uin': newUin});
            return business.copyWith(uin: newUin);
          }
          
          return business;
        });
  }

  Future<Business> createBusiness({
    required String uid,
    required Business business,
  }) async {
    // 1. Generate permanent Display UIN
    final uin = await _generateDisplayUIN(type: 'BIZ');
    
    // 2. Internal UUID is handled by Firestore auto-ID
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
      city: business.city,
      gstNumber: business.gstNumber,
      isFssaiRegistered: business.isFssaiRegistered,
      fssaiNumber: business.fssaiNumber,
      address: business.address,
      logoUrl: business.logoUrl,
      createdAt: DateTime.now(),
    );

    final batch = _db.batch();
    batch.set(businessRef, finalBusiness.toCreateMap());
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

  Future<Business> updateBusiness(Business business) async {
    // Ensure UIN is never accidentally changed if it already exists
    final doc = await _db.collection('businesses').doc(business.id).get();
    String uin = business.uin;
    
    if (doc.exists) {
      final existingData = doc.data()!;
      final existingUin = existingData['uin'] as String?;
      if (existingUin != null && existingUin.isNotEmpty) {
        uin = existingUin; // Lock to existing UIN
      }
    }

    if (uin.isEmpty) {
      uin = await _generateDisplayUIN(type: 'BIZ');
    }

    final businessToUpdate = business.copyWith(uin: uin);
    await _db.collection('businesses').doc(businessToUpdate.id).update(businessToUpdate.toMap());
    return businessToUpdate;
  }

  // TODO: Implement Firebase Storage uploadLogo
}
