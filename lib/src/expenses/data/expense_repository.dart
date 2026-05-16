import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../../dashboard/domain/order_models.dart';
import '../domain/expense.dart';

class ExpenseRepository {
  ExpenseRepository({
    required FirebaseFirestore db,
    required FirebaseAuth auth,
  })  : _db = db,
        _auth = auth;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  Stream<List<Expense>> watchExpenses() {
    return _db
        .collection('expenses')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Expense.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<void> saveExpense(Expense expense) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Not signed in');

    final isNew = expense.id.isEmpty;
    final expenseId = isNew ? const Uuid().v4() : expense.id;
    final expenseRef = _db.collection('expenses').doc(expenseId);
    final balancesRef = _db.collection('balances').doc('current');

    await _db.runTransaction((tx) async {
      // 1. READS
      final balancesSnap = await tx.get(balancesRef);
      Expense? oldExpense;
      if (!isNew) {
        final expenseSnap = await tx.get(expenseRef);
        if (expenseSnap.exists) {
          oldExpense = Expense.fromMap(expenseSnap.id, expenseSnap.data()!);
        }
      }

      // 2. CALCULATE BALANCES
      final data = balancesSnap.data() ?? {};
      int cash = data['cashBalancePaise'] ?? 0;
      int bank = data['bankBalancePaise'] ?? 0;

      // Reverse old impact
      if (oldExpense != null) {
        if (oldExpense.paymentMethod == PaymentMethod.cash) {
          cash += oldExpense.amountPaise;
        } else {
          bank += oldExpense.amountPaise;
        }
      }

      // Apply new impact
      if (expense.paymentMethod == PaymentMethod.cash) {
        cash -= expense.amountPaise;
      } else {
        bank -= expense.amountPaise;
      }

      // 3. WRITES
      tx.set(expenseRef, expense.copyWith(id: expenseId).toMap());
      tx.set(
        balancesRef,
        {
          'cashBalancePaise': cash,
          'bankBalancePaise': bank,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> deleteExpense(Expense expense) async {
    final expenseRef = _db.collection('expenses').doc(expense.id);
    final balancesRef = _db.collection('balances').doc('current');

    await _db.runTransaction((tx) async {
      // 1. READS
      final balancesSnap = await tx.get(balancesRef);
      
      // 2. CALCULATE BALANCES
      final data = balancesSnap.data() ?? {};
      int cash = data['cashBalancePaise'] ?? 0;
      int bank = data['bankBalancePaise'] ?? 0;

      // Restore balance
      if (expense.paymentMethod == PaymentMethod.cash) {
        cash += expense.amountPaise;
      } else {
        bank += expense.amountPaise;
      }

      // 3. WRITES
      tx.delete(expenseRef);
      tx.set(
        balancesRef,
        {
          'cashBalancePaise': cash,
          'bankBalancePaise': bank,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }
}
