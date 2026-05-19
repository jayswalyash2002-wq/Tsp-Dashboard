import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../dashboard/domain/order_models.dart';
import '../domain/expense.dart';

class ExpenseRepository {
  ExpenseRepository({
    required FirebaseFirestore db,
    required FirebaseAuth auth,
    required String businessId,
  })  : _db = db,
        _auth = auth,
        _businessId = businessId;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final String _businessId;

  Stream<List<Expense>> watchExpenses() {
    debugPrint('EXPENSE_REPO: Watching expenses for businessId: $_businessId');
    return _db
        .collection('expenses')
        .where('businessId', isEqualTo: _businessId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) {
      final items = snap.docs
          .map((doc) => Expense.fromMap(doc.id, doc.data()))
          .toList();
      
      // Strict client-side isolation filter
      return items.where((e) => e.businessId == _businessId).toList();
    });
  }

  Future<void> saveExpense(Expense expense) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');

    final isNew = expense.id.isEmpty;
    final expenseId = isNew ? const Uuid().v4() : expense.id;
    final expenseRef = _db.collection('expenses').doc(expenseId);
    final balancesRef = _db.collection('balances').doc(_businessId);

    debugPrint('EXPENSE_REPO: Saving expense $expenseId (new: $isNew) for businessId: $_businessId');

    await _db.runTransaction((tx) async {
      // 1. READS
      final balancesSnap = await tx.get(balancesRef);
      Expense? oldExpense;
      if (!isNew) {
        final expenseSnap = await tx.get(expenseRef);
        if (expenseSnap.exists) {
          final data = expenseSnap.data()!;
          final existingBusinessId = data['businessId']?.toString();
          
          if (existingBusinessId != _businessId) {
            debugPrint('CRITICAL: Blocked unauthorized expense update attempt. '
                'Expected: $_businessId, Found: $existingBusinessId');
            throw Exception('Access Denied: Business ownership mismatch');
          }
          
          oldExpense = Expense.fromMap(expenseSnap.id, data);
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
      tx.set(expenseRef, {
        ...expense.toMap(),
        'id': expenseId, // Ensure ID consistency
        'businessId': _businessId,
        'updatedBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
        if (isNew) 'createdAt': FieldValue.serverTimestamp(),
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

  Future<void> deleteExpense(Expense expense) async {
    final expenseRef = _db.collection('expenses').doc(expense.id);
    final balancesRef = _db.collection('balances').doc(_businessId);

    debugPrint('EXPENSE_REPO: Deleting expense ${expense.id} for businessId: $_businessId');

    await _db.runTransaction((tx) async {
      // 1. READS & VALIDATION
      final expenseSnap = await tx.get(expenseRef);
      if (!expenseSnap.exists) return; // Already gone
      
      final expenseData = expenseSnap.data()!;
      final existingBusinessId = expenseData['businessId']?.toString();
      
      if (existingBusinessId != _businessId) {
        debugPrint('CRITICAL: Blocked unauthorized expense delete attempt. '
            'Expected: $_businessId, Found: $existingBusinessId');
        throw Exception('Access Denied: Business ownership mismatch');
      }

      final balancesSnap = await tx.get(balancesRef);
      
      // 2. CALCULATE BALANCES
      final data = balancesSnap.data() ?? {};
      int cash = data['cashBalancePaise'] ?? 0;
      int bank = data['bankBalancePaise'] ?? 0;

      final actualExpense = Expense.fromMap(expenseSnap.id, expenseData);

      // Restore balance
      if (actualExpense.paymentMethod == PaymentMethod.cash) {
        cash += actualExpense.amountPaise;
      } else {
        bank += actualExpense.amountPaise;
      }

      // 3. WRITES
      tx.delete(expenseRef);
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
