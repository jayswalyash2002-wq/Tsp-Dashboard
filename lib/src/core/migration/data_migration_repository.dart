import 'package:cloud_firestore/cloud_firestore.dart';

class DataMigrationRepository {
  DataMigrationRepository(this._db);
  final FirebaseFirestore _db;

  Future<int> migrateLegacyData(String businessId) async {
    int count = 0;
    
    // 1. Migrate Orders
    count += await _migrateCollection('orders', businessId);
    
    // 2. Migrate Expenses
    count += await _migrateCollection('expenses', businessId);
    
    // 3. Migrate Menu
    count += await _migrateCollection('menu', businessId);

    // 4. Migrate Fund Movements
    count += await _migrateCollection('fund_movements', businessId);

    // 5. Migrate Balances
    await _migrateBalances(businessId);

    // 6. Migrate Session
    await _migrateSession(businessId);

    return count;
  }

  Future<int> _migrateCollection(String collectionPath, String businessId) async {
    final snap = await _db.collection(collectionPath)
        .where('businessId', isNull: true)
        .get();
    
    final batch = _db.batch();
    int batchCount = 0;
    
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'businessId': businessId});
      batchCount++;
      if (batchCount >= 500) break; // Firestore batch limit
    }
    
    if (batchCount > 0) {
      await batch.commit();
    }
    
    return batchCount;
  }

  Future<void> _migrateBalances(String businessId) async {
    final legacyRef = _db.collection('balances').doc('current');
    final newRef = _db.collection('balances').doc(businessId);
    
    final legacySnap = await legacyRef.get();
    if (legacySnap.exists) {
      final newSnap = await newRef.get();
      if (!newSnap.exists) {
        await newRef.set({
          ...legacySnap.data()!,
          'businessId': businessId,
          'migratedFromLegacy': true,
        });
      }
    }
  }

  Future<void> _migrateSession(String businessId) async {
    final legacyRef = _db.collection('sessions').doc('current');
    final newRef = _db.collection('sessions').doc(businessId);
    
    final legacySnap = await legacyRef.get();
    if (legacySnap.exists) {
      final newSnap = await newRef.get();
      if (!newSnap.exists) {
        await newRef.set({
          ...legacySnap.data()!,
          'businessId': businessId,
          'migratedFromLegacy': true,
        });
      }
    }
  }
}
