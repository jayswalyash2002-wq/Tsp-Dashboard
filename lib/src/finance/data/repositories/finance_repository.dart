import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/finance_transaction.dart';
import '../../domain/models/finance_balance.dart';
import '../../domain/models/finance_audit_log.dart';
import '../../domain/models/finance_enums.dart';

class FinanceOperationResult {
  final bool warning;
  final String? message;
  final FinanceBalance newBalances;

  FinanceOperationResult({
    this.warning = false,
    this.message,
    required this.newBalances,
  });
}

class FinanceRepository {
  final FirebaseFirestore _db;
  final String _businessId; // If multi-tenant, otherwise can be fixed

  FinanceRepository(this._db, {String businessId = 'main'}) : _businessId = businessId;

  // Collection references
  CollectionReference<Map<String, dynamic>> get _transactionsRef => _db.collection('transactions');
  DocumentReference<Map<String, dynamic>> get _balancesRef => _db.collection('balances').doc(_businessId);
  CollectionReference<Map<String, dynamic>> get _auditLogRef => _db.collection('audit_log');
  CollectionReference<Map<String, dynamic>> get _pendingOpsRef => _db.collection('pending_operations');

  /// Core logic: Reverse the impact of a transaction on balances
  FinanceBalance reverseImpact(FinanceTransaction tx, FinanceBalance balances) {
    int cash = balances.cash;
    int bank = balances.bank;

    if (tx.isDeleted) return balances; // Already reversed or never applied

    switch (tx.type) {
      case FinanceTransactionType.expense:
        if (tx.account == FinanceAccount.cash) {
          cash += tx.amount;
        } else {
          bank += tx.amount;
        }
        break;
      case FinanceTransactionType.fund:
        if (tx.account == FinanceAccount.cash) {
          cash -= tx.amount;
        } else {
          bank -= tx.amount;
        }
        break;
      case FinanceTransactionType.transfer:
        // Add back to fromAccount, subtract from toAccount
        if (tx.fromAccount == FinanceAccount.cash) cash += tx.amount;
        if (tx.fromAccount == FinanceAccount.bank) bank += tx.amount;
        if (tx.toAccount == FinanceAccount.cash) cash -= tx.amount;
        if (tx.toAccount == FinanceAccount.bank) bank -= tx.amount;
        break;
    }

    return balances.copyWith(cash: cash, bank: bank, lastUpdatedAt: DateTime.now());
  }

  /// Core logic: Apply the impact of a transaction on balances
  FinanceOperationResult applyImpact(FinanceTransaction tx, FinanceBalance balances) {
    int cash = balances.cash;
    int bank = balances.bank;

    if (tx.isDeleted) return FinanceOperationResult(newBalances: balances);

    switch (tx.type) {
      case FinanceTransactionType.expense:
        if (tx.account == FinanceAccount.cash) {
          cash -= tx.amount;
        } else {
          bank -= tx.amount;
        }
        break;
      case FinanceTransactionType.fund:
        if (tx.account == FinanceAccount.cash) {
          cash += tx.amount;
        } else {
          bank += tx.amount;
        }
        break;
      case FinanceTransactionType.transfer:
        // Subtract from fromAccount, add to toAccount
        if (tx.fromAccount == FinanceAccount.cash) cash -= tx.amount;
        if (tx.fromAccount == FinanceAccount.bank) bank -= tx.amount;
        if (tx.toAccount == FinanceAccount.cash) cash += tx.amount;
        if (tx.toAccount == FinanceAccount.bank) bank += tx.amount;
        break;
    }

    final newBalances = balances.copyWith(cash: cash, bank: bank, lastUpdatedAt: DateTime.now());
    final hasWarning = newBalances.cash < 0 || newBalances.bank < 0;

    return FinanceOperationResult(
      newBalances: newBalances,
      warning: hasWarning,
      message: hasWarning ? 'Balance is now negative. Please review.' : null,
    );
  }

  /// Execute a finance operation with idempotency protection
  Future<T> executeWithIdempotency<T>({
    required String requestId,
    required Future<T> Function(Transaction transaction) operation,
  }) async {
    return await _db.runTransaction((transaction) async {
      final opRef = _pendingOpsRef.doc(requestId);
      final opSnap = await transaction.get(opRef);

      if (opSnap.exists) {
        final data = opSnap.data()!;
        if (data['status'] == 'completed') {
          debugPrint('Idempotency: Operation $requestId already completed.');
          // In a real scenario, you'd return the stored result if applicable
          return data['result'] as T;
        }
      }

      // DO NOT write 'pending' here, as it violates Firestore's "all reads before all writes" rule
      // if the operation contains reads.
      
      final result = await operation(transaction);

      // WRITE PHASE
      transaction.set(opRef, {
        'status': 'completed',
        'completed_at': FieldValue.serverTimestamp(),
        if (result is FinanceOperationResult) 'warning': result.warning,
      });

      return result;
    });
  }

  /// Create a new transaction (Fund, Expense, or Transfer)
  Future<FinanceOperationResult> createTransaction({
    required String requestId,
    required FinanceTransaction tx,
    required String userId,
  }) async {
    return await executeWithIdempotency(
      requestId: requestId,
      operation: (transaction) async {
        // 1. Read current balances
        final balanceSnap = await transaction.get(_balancesRef);
        FinanceBalance currentBalances = balanceSnap.exists 
            ? FinanceBalance.fromMap(balanceSnap.data()!) 
            : FinanceBalance(cash: 0, bank: 0, lastUpdatedAt: DateTime.now());

        // 2. Apply new impact
        final result = applyImpact(tx, currentBalances);

        if (kDebugMode) {
          debugPrint('FINANCE_REPO: Create Transaction');
          debugPrint('  Type: ${tx.type.name}');
          debugPrint('  Account: ${tx.account?.name ?? 'N/A'}');
          debugPrint('  Amount: ${tx.amount}');
          debugPrint('  Balance Before: Cash=${currentBalances.cash}, Bank=${currentBalances.bank}');
          debugPrint('  Balance After: Cash=${result.newBalances.cash}, Bank=${result.newBalances.bank}');
        }

        // 3. Write transaction
        final txRef = _transactionsRef.doc(tx.id);
        transaction.set(txRef, tx.toMap());

        // 4. Update balances
        transaction.set(_balancesRef, result.newBalances.toMap());

        // 5. Audit Log
        final auditRef = _auditLogRef.doc();
        final audit = FinanceAuditLog(
          id: auditRef.id,
          transactionId: tx.id,
          action: FinanceAuditAction.created,
          newValues: tx.toMap(),
          changedBy: userId,
          changedAt: DateTime.now(),
        );
        transaction.set(auditRef, audit.toMap());

        return result;
      },
    );
  }

  /// Edit an existing transaction
  Future<FinanceOperationResult> editTransaction({
    required String requestId,
    required String transactionId,
    required FinanceTransaction newTx,
    required String userId,
  }) async {
    return await executeWithIdempotency(
      requestId: requestId,
      operation: (transaction) async {
        final txRef = _transactionsRef.doc(transactionId);
        final oldTxSnap = await transaction.get(txRef);
        if (!oldTxSnap.exists) throw Exception('Transaction not found');
        
        final oldTx = FinanceTransaction.fromMap(oldTxSnap.data()!, oldTxSnap.id);
        
        // 1. Read current balances
        final balanceSnap = await transaction.get(_balancesRef);
        FinanceBalance currentBalances = FinanceBalance.fromMap(balanceSnap.data()!);

        // 2. Reverse old impact
        FinanceBalance midBalances = reverseImpact(oldTx, currentBalances);

        // 3. Apply new impact
        final result = applyImpact(newTx, midBalances);

        if (kDebugMode) {
          debugPrint('FINANCE_REPO: Edit Transaction ${newTx.id}');
          debugPrint('  Type: ${newTx.type.name}');
          debugPrint('  Amount: ${newTx.amount}');
          debugPrint('  Balance Before: Cash=${currentBalances.cash}, Bank=${currentBalances.bank}');
          debugPrint('  Balance After: Cash=${result.newBalances.cash}, Bank=${result.newBalances.bank}');
        }

        // 4. Update transaction
        transaction.update(txRef, newTx.toMap());

        // 5. Update balances
        transaction.set(_balancesRef, result.newBalances.toMap());

        // 6. Audit Log
        final auditRef = _auditLogRef.doc();
        final audit = FinanceAuditLog(
          id: auditRef.id,
          transactionId: transactionId,
          action: FinanceAuditAction.edited,
          oldValues: oldTx.toMap(),
          newValues: newTx.toMap(),
          changedBy: userId,
          changedAt: DateTime.now(),
        );
        transaction.set(auditRef, audit.toMap());

        return result;
      },
    );
  }

  /// Soft delete a transaction
  Future<FinanceOperationResult> deleteTransaction({
    required String requestId,
    required String transactionId,
    required String userId,
  }) async {
    return await executeWithIdempotency(
      requestId: requestId,
      operation: (transaction) async {
        final txRef = _transactionsRef.doc(transactionId);
        final oldTxSnap = await transaction.get(txRef);
        if (!oldTxSnap.exists) throw Exception('Transaction not found');
        
        final oldTx = FinanceTransaction.fromMap(oldTxSnap.data()!, oldTxSnap.id);
        if (oldTx.isDeleted) throw Exception('Transaction already deleted');

        // 1. Read current balances
        final balanceSnap = await transaction.get(_balancesRef);
        FinanceBalance currentBalances = FinanceBalance.fromMap(balanceSnap.data()!);

        // 2. Reverse impact
        FinanceBalance newBalances = reverseImpact(oldTx, currentBalances);

        if (kDebugMode) {
          debugPrint('FINANCE_REPO: Delete Transaction $transactionId');
          debugPrint('  Type: ${oldTx.type.name}');
          debugPrint('  Amount: ${oldTx.amount}');
          debugPrint('  Balance Before: Cash=${currentBalances.cash}, Bank=${currentBalances.bank}');
          debugPrint('  Balance After: Cash=${newBalances.cash}, Bank=${newBalances.bank}');
        }

        // 3. Mark as deleted
        transaction.update(txRef, {
          'is_deleted': true,
          'deleted_by': userId,
          'deleted_at': FieldValue.serverTimestamp(),
        });

        // 4. Update balances
        transaction.set(_balancesRef, newBalances.toMap());

        // 5. Audit Log
        final auditRef = _auditLogRef.doc();
        final audit = FinanceAuditLog(
          id: auditRef.id,
          transactionId: transactionId,
          action: FinanceAuditAction.deleted,
          oldValues: oldTx.toMap(),
          changedBy: userId,
          changedAt: DateTime.now(),
        );
        transaction.set(auditRef, audit.toMap());

        return FinanceOperationResult(newBalances: newBalances);
      },
    );
  }

  /// Explicit Transfer methods
  Future<FinanceOperationResult> createTransfer({
    required String requestId,
    required FinanceTransaction transferTx,
    required String userId,
  }) async {
    if (transferTx.type != FinanceTransactionType.transfer) {
      throw Exception('Invalid transaction type for transfer');
    }
    if (transferTx.fromAccount == transferTx.toAccount) {
      throw Exception('Source and destination accounts must be different');
    }
    return await createTransaction(requestId: requestId, tx: transferTx, userId: userId);
  }

  Future<FinanceOperationResult> editTransfer({
    required String requestId,
    required String transactionId,
    required FinanceTransaction newTransferTx,
    required String userId,
  }) async {
    if (newTransferTx.type != FinanceTransactionType.transfer) {
      throw Exception('Invalid transaction type for transfer');
    }
    if (newTransferTx.fromAccount == newTransferTx.toAccount) {
      throw Exception('Source and destination accounts must be different');
    }
    return await editTransaction(
      requestId: requestId,
      transactionId: transactionId,
      newTx: newTransferTx,
      userId: userId,
    );
  }

  Future<FinanceOperationResult> deleteTransfer({
    required String requestId,
    required String transactionId,
    required String userId,
  }) async {
    return await deleteTransaction(
      requestId: requestId,
      transactionId: transactionId,
      userId: userId,
    );
  }


  /// Recalculate balances from scratch for integrity verification
  Future<Map<String, int>> recalculateBalances() async {
    final txsSnap = await _transactionsRef
        .where('businessId', isEqualTo: _businessId)
        .where('is_deleted', isEqualTo: false)
        .get();
    
    int cash = 0;
    int bank = 0;

    for (var doc in txsSnap.docs) {
      final tx = FinanceTransaction.fromMap(doc.data(), doc.id);
      
      switch (tx.type) {
        case FinanceTransactionType.expense:
          if (tx.account == FinanceAccount.cash) {
            cash -= tx.amount;
          } else {
            bank -= tx.amount;
          }
          break;
        case FinanceTransactionType.fund:
          if (tx.account == FinanceAccount.cash) {
            cash += tx.amount;
          } else {
            bank += tx.amount;
          }
          break;
        case FinanceTransactionType.transfer:
          if (tx.fromAccount == FinanceAccount.cash) {
            cash -= tx.amount;
          }
          if (tx.fromAccount == FinanceAccount.bank) {
            bank -= tx.amount;
          }
          if (tx.toAccount == FinanceAccount.cash) {
            cash += tx.amount;
          }
          if (tx.toAccount == FinanceAccount.bank) {
            bank += tx.amount;
          }
          break;
      }
    }

    final currentSnap = await _balancesRef.get();
    final currentData = currentSnap.data() ?? {};
    
    return {
      'calculated_cash': cash,
      'calculated_bank': bank,
      'stored_cash': currentData['cash'] ?? 0,
      'stored_bank': currentData['bank'] ?? 0,
      'diff_cash': cash - (currentData['cash'] as int? ?? 0),
      'diff_bank': bank - (currentData['bank'] as int? ?? 0),
    };
  }
}
