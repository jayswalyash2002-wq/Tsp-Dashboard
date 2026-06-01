import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/sync/local_database_service.dart';
import '../../core/sync/sync_models.dart';
import '../../dashboard/domain/order_models.dart';
import '../domain/expense.dart';

class ExpenseRepository {
  ExpenseRepository({
    required FirebaseFirestore db,
    required FirebaseAuth auth,
    required LocalDatabaseService localDb,
    required String businessId,
  })  : _db = db,
        _auth = auth,
        _localDb = localDb,
        _businessId = businessId;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final LocalDatabaseService _localDb;
  final String _businessId;

  Stream<List<Expense>> watchExpenses() {
    if (kDebugMode) {
      debugPrint('EXPENSE_REPO: Watching expenses for businessId: $_businessId');
    }
    final firestoreStream = _db
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

    return firestoreStream.map((remoteExpenses) {
      final localUnsynced = _localDb.getUnsyncedExpenses();
      final localIds = localUnsynced.map((e) => e.id).toSet();
      final filteredRemote = remoteExpenses.where((e) => !localIds.contains(e.id)).toList();
      
      final merged = [...localUnsynced, ...filteredRemote];
      merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return merged;
    });
  }

  Future<void> saveExpense(
    Expense expense,
  ) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');

    final isNew = expense.id.isEmpty;
    final expenseId = isNew ? const Uuid().v4() : expense.id;
    
    final updatedExpense = expense.copyWith(
      id: expenseId,
      syncMetadata: SyncMetadata(
        localId: expenseId,
        createdAt: expense.timestamp,
        updatedAt: DateTime.now(),
        synced: false,
      ),
    );

    // 1. Save locally (Optimistic)
    await _localDb.saveExpense(updatedExpense);

    // 2. Trigger background sync
    syncExpense(updatedExpense, isNew);
  }

  Future<void> syncExpense(Expense expense, bool isNew) async {
    if (expense.isSynced) return;

    final expenseRef = _db.collection('expenses').doc(expense.id);
    final balancesRef = _db.collection('balances').doc(_businessId);
    final uid = _auth.currentUser?.uid;

    try {
      await _db.runTransaction((tx) async {
        // 1. READS
        final balancesSnap = await tx.get(balancesRef);
        Expense? oldExpense;
        if (!isNew) {
          final expenseSnap = await tx.get(expenseRef);
          if (expenseSnap.exists) {
            final data = expenseSnap.data()!;
            oldExpense = Expense.fromMap(expenseSnap.id, data);
          }
        }

        // 2. CALCULATE BALANCES
        final data = balancesSnap.data() ?? {};
        int cash = data['cashBalancePaise'] ?? 0;
        int bank = data['bankBalancePaise'] ?? 0;

        if (oldExpense != null && oldExpense.expenseStatus == 'settled') {
          if (oldExpense.paymentMethod == PaymentMethod.cash) {
            cash += oldExpense.amountPaise;
          } else {
            bank += oldExpense.amountPaise;
          }
        }

        if (expense.expenseStatus == 'settled') {
          if (expense.paymentMethod == PaymentMethod.cash) {
            cash -= expense.amountPaise;
          } else {
            bank -= expense.amountPaise;
          }
        }

        // 3. WRITES
        tx.set(expenseRef, {
          ...expense.toFirestoreMap(),
          'id': expense.id,
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

      // Mark as synced locally
      final syncedExpense = expense.copyWith(
        syncMetadata: expense.syncMetadata?.copyWith(synced: true, updatedAt: DateTime.now()),
      );
      await _localDb.saveExpense(syncedExpense);
    } catch (e) {
      debugPrint('EXPENSE_REPO: Sync failed for ${expense.id}: $e');
    }
  }

  Future<void> deleteExpense(
    Expense expense,
  ) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');
    final expenseRef = _db.collection('expenses').doc(expense.id);
    final balancesRef = _db.collection('balances').doc(_businessId);

    if (kDebugMode) {
      debugPrint('EXPENSE_REPO: Deleting expense ${expense.id} for businessId: $_businessId');
    }

    await _db.runTransaction((tx) async {
      // 1. READS & VALIDATION
      final expenseSnap = await tx.get(expenseRef);
      if (!expenseSnap.exists) return; // Already gone
      
      final expenseData = expenseSnap.data()!;
      final existingBusinessId = expenseData['businessId']?.toString();
      
      if (existingBusinessId != _businessId) {
        if (kDebugMode) {
          debugPrint('CRITICAL: Blocked unauthorized expense delete attempt. '
              'Expected: $_businessId, Found: $existingBusinessId');
        }
        throw Exception('Access Denied: Business ownership mismatch');
      }

      final balancesSnap = await tx.get(balancesRef);
      
      // 2. CALCULATE BALANCES
      final data = balancesSnap.data() ?? {};
      int cash = data['cashBalancePaise'] ?? 0;
      int bank = data['bankBalancePaise'] ?? 0;

      final actualExpense = Expense.fromMap(expenseSnap.id, expenseData);

      // Restore balance if it was settled
      if (actualExpense.expenseStatus == 'settled') {
        if (actualExpense.paymentMethod == PaymentMethod.cash) {
          cash += actualExpense.amountPaise;
        } else {
          bank += actualExpense.amountPaise;
        }
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
