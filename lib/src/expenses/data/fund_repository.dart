import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../domain/fund_movement.dart';

class FundRepository {
  FundRepository({
    required FirebaseFirestore db,
    required FirebaseAuth auth,
    required String businessId,
  })  : _db = db,
        _auth = auth,
        _businessId = businessId;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final String _businessId;

  Stream<List<FundMovement>> watchFundMovements() {
    return _db
        .collection('fund_movements')
        .where('businessId', isEqualTo: _businessId)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => FundMovement.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<void> addFunds(FundMovement movement) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Not signed in');

    final id = const Uuid().v4();
    final movementRef = _db.collection('fund_movements').doc(id);
    final balancesRef = _db.collection('balances').doc(_businessId);

    await _db.runTransaction((tx) async {
      // 1. READS
      final balancesSnap = await tx.get(balancesRef);

      // 2. CALCULATE
      final data = balancesSnap.data() ?? {};
      int cash = data['cashBalancePaise'] ?? 0;
      int bank = data['bankBalancePaise'] ?? 0;

      if (movement.type == 'cash') {
        cash += movement.amountPaise;
      } else {
        bank += movement.amountPaise;
      }

      // 3. WRITES
      tx.set(movementRef, {
        ...movement.toMap(),
        'businessId': _businessId,
      });
      tx.set(
        balancesRef,
        {
          'businessId': _businessId,
          'cashBalancePaise': cash,
          'bankBalancePaise': bank,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }
}
