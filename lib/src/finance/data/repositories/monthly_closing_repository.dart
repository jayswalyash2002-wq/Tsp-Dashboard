import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/monthly_closing.dart';
import '../../domain/models/finance_transaction.dart';
import '../../domain/models/finance_enums.dart';
import '../../domain/models/finance_balance.dart';
import '../../domain/models/finance_audit_log.dart';
import 'finance_repository.dart';

class MonthlyClosingRepository {
  final FirebaseFirestore _db;
  final String _businessId;

  MonthlyClosingRepository(this._db, this._businessId);

  CollectionReference<Map<String, dynamic>> get _closingsRef => 
      _db.collection('monthly_closings');
  CollectionReference<Map<String, dynamic>> get _transactionsRef => 
      _db.collection('transactions');
  DocumentReference<Map<String, dynamic>> get _balancesRef => 
      _db.collection('balances').doc(_businessId);
  CollectionReference<Map<String, dynamic>> get _auditLogRef => 
      _db.collection('audit_log');

  Stream<List<MonthlyClosing>> watchClosings() {
    return _closingsRef
        .where('businessId', isEqualTo: _businessId)
        .orderBy('year', descending: true)
        .orderBy('month', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => MonthlyClosing.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<MonthlyClosing?> getClosing(int month, int year) async {
    final snap = await _closingsRef
        .where('businessId', isEqualTo: _businessId)
        .where('month', isEqualTo: month)
        .where('year', isEqualTo: year)
        .limit(1)
        .get();
    
    if (snap.docs.isEmpty) return null;
    return MonthlyClosing.fromMap(snap.docs.first.data(), snap.docs.first.id);
  }

  /// Perform the Monthly Closing
  Future<void> closeMonth({
    required int month,
    required int year,
    required int carryForwardCash,
    required int carryForwardBank,
    required String reason,
    required String notes,
    required String userId,
  }) async {
    await _db.runTransaction((transaction) async {
      // 1. Check if already closed
      final existingSnap = await transaction.get(
        _closingsRef.doc('${_businessId}_${year}_$month')
      );
      if (existingSnap.exists) throw Exception('Month already closed');

      // 2. Read current balances
      final balanceSnap = await transaction.get(_balancesRef);
      if (!balanceSnap.exists) throw Exception('Balances not found');
      final currentBalances = FinanceBalance.fromMap(balanceSnap.data()!);

      // 3. Find opening balance (from previous month's closing)
      final prevDate = DateTime(year, month - 1);
      final prevClosingId = '${_businessId}_${prevDate.year}_${prevDate.month}';
      final prevSnap = await transaction.get(_closingsRef.doc(prevClosingId));
      
      int openingCash = 0;
      int openingBank = 0;
      if (prevSnap.exists) {
        openingCash = prevSnap.data()!['carryForwardCash'] ?? 0;
        openingBank = prevSnap.data()!['carryForwardBank'] ?? 0;
      }

      // 4. Create Monthly Closing document
      final closingId = '${_businessId}_${year}_$month';
      final closing = MonthlyClosing(
        id: closingId,
        businessId: _businessId,
        month: month,
        year: year,
        openingCash: openingCash,
        openingBank: openingBank,
        closingCash: currentBalances.cash,
        closingBank: currentBalances.bank,
        carryForwardCash: carryForwardCash,
        carryForwardBank: carryForwardBank,
        adjustmentCash: currentBalances.cash - carryForwardCash,
        adjustmentBank: currentBalances.bank - carryForwardBank,
        reason: reason,
        notes: notes,
        closedBy: userId,
        closedAt: DateTime.now(),
      );

      // 5. Create closing adjustment transactions for the CURRENT month
      // We zero out the month.
      final cashAdjTxId = const Uuid().v4();
      final cashAdjTx = FinanceTransaction(
        id: cashAdjTxId,
        businessId: _businessId,
        type: FinanceTransactionType.closing_adjustment,
        amount: currentBalances.cash,
        account: FinanceAccount.cash,
        notes: 'Monthly Closing Adjustment: $reason',
        date: DateTime(year, month + 1, 0), // Last day of month
        month: month,
        year: year,
        createdBy: userId,
        createdAt: DateTime.now(),
      );

      final bankAdjTxId = const Uuid().v4();
      final bankAdjTx = FinanceTransaction(
        id: bankAdjTxId,
        businessId: _businessId,
        type: FinanceTransactionType.closing_adjustment,
        amount: currentBalances.bank,
        account: FinanceAccount.bank,
        notes: 'Monthly Closing Adjustment: $reason',
        date: DateTime(year, month + 1, 0),
        month: month,
        year: year,
        createdBy: userId,
        createdAt: DateTime.now(),
      );

      // 6. Create opening balance transactions for the NEXT month
      final nextMonthDate = DateTime(year, month + 1, 1);
      final nextMonth = nextMonthDate.month;
      final nextYear = nextMonthDate.year;

      final cashOpTxId = const Uuid().v4();
      final cashOpTx = FinanceTransaction(
        id: cashOpTxId,
        businessId: _businessId,
        type: FinanceTransactionType.opening_balance,
        amount: carryForwardCash,
        account: FinanceAccount.cash,
        notes: 'Opening Balance from $month/$year',
        date: nextMonthDate,
        month: nextMonth,
        year: nextYear,
        createdBy: userId,
        createdAt: DateTime.now(),
      );

      final bankOpTxId = const Uuid().v4();
      final bankOpTx = FinanceTransaction(
        id: bankOpTxId,
        businessId: _businessId,
        type: FinanceTransactionType.opening_balance,
        amount: carryForwardBank,
        account: FinanceAccount.bank,
        notes: 'Opening Balance from $month/$year',
        date: nextMonthDate,
        month: nextMonth,
        year: nextYear,
        createdBy: userId,
        createdAt: DateTime.now(),
      );

      // 7. WRITES
      transaction.set(_closingsRef.doc(closingId), closing.toMap());
      transaction.set(_transactionsRef.doc(cashAdjTxId), cashAdjTx.toMap());
      transaction.set(_transactionsRef.doc(bankAdjTxId), bankAdjTx.toMap());
      transaction.set(_transactionsRef.doc(cashOpTxId), cashOpTx.toMap());
      transaction.set(_transactionsRef.doc(bankOpTxId), bankOpTx.toMap());

      // Update current balance document
      transaction.update(_balancesRef, {
        'cash': carryForwardCash,
        'bank': carryForwardBank,
        'last_updated_at': FieldValue.serverTimestamp(),
        // Support legacy fields
        'cashBalancePaise': carryForwardCash,
        'bankBalancePaise': carryForwardBank,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Audit Log
      final auditRef = _auditLogRef.doc();
      transaction.set(auditRef, {
        'id': auditRef.id,
        'action': FinanceAuditAction.month_locked.name,
        'businessId': _businessId,
        'month': month,
        'year': year,
        'changedBy': userId,
        'changedAt': FieldValue.serverTimestamp(),
        'metadata': {
          'closingId': closingId,
          'carryForwardCash': carryForwardCash,
          'carryForwardBank': carryForwardBank,
        }
      });
    });
  }

  Future<void> unlockMonth({
    required int month,
    required int year,
    required String reason,
    required String userId,
  }) async {
    await _db.runTransaction((transaction) async {
      final closingId = '${_businessId}_${year}_$month';
      final closingRef = _closingsRef.doc(closingId);
      final closingSnap = await transaction.get(closingRef);
      
      if (!closingSnap.exists) throw Exception('Closing record not found');
      
      transaction.update(closingRef, {
        'isLocked': false,
        'unlockedBy': userId,
        'unlockedAt': FieldValue.serverTimestamp(),
        'unlockReason': reason,
      });

      // Audit Log
      final auditRef = _auditLogRef.doc();
      transaction.set(auditRef, {
        'id': auditRef.id,
        'action': FinanceAuditAction.month_unlocked.name,
        'businessId': _businessId,
        'month': month,
        'year': year,
        'changedBy': userId,
        'changedAt': FieldValue.serverTimestamp(),
        'metadata': {
          'reason': reason,
        }
      });
    });
  }
}
