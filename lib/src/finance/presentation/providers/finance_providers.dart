import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../auth/data/auth_providers.dart';
import '../../data/repositories/finance_repository.dart';
import '../../data/repositories/monthly_closing_repository.dart';
import '../../domain/models/finance_transaction.dart';
import '../../domain/models/monthly_closing.dart';
import '../../domain/models/finance_balance.dart';
import '../../domain/models/finance_enums.dart';

final financeRepositoryProvider = Provider<FinanceRepository?>((ref) {
  final businessId = ref.watch(userBusinessIdProvider);
  if (businessId == null) return null;

  final db = ref.watch(firestoreProvider);
  return FinanceRepository(db, businessId: businessId);
});

final monthlyClosingRepositoryProvider = Provider<MonthlyClosingRepository?>((ref) {
  final businessId = ref.watch(userBusinessIdProvider);
  if (businessId == null) return null;

  final db = ref.watch(firestoreProvider);
  return MonthlyClosingRepository(db, businessId);
});

final monthlyClosingsProvider = StreamProvider<List<MonthlyClosing>>((ref) {
  final repo = ref.watch(monthlyClosingRepositoryProvider);
  if (repo == null) return Stream.value([]);
  return repo.watchClosings();
});

final financeBalancesProvider = StreamProvider<FinanceBalance?>((ref) {
  final businessId = ref.watch(userBusinessIdProvider);
  if (businessId == null) return Stream.value(null);

  final db = ref.watch(firestoreProvider);
  return db
      .collection('balances')
      .doc(businessId)
      .snapshots()
      .map((snap) => snap.exists ? FinanceBalance.fromMap(snap.data()!) : null);
});

final financeTransactionsProvider = StreamProvider<List<FinanceTransaction>>((ref) {
  final businessId = ref.watch(userBusinessIdProvider);
  if (businessId == null) return Stream.value([]);

  final db = ref.watch(firestoreProvider);
  return db
      .collection('transactions')
      .where('businessId', isEqualTo: businessId)
      .orderBy('date', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => FinanceTransaction.fromMap(doc.data(), doc.id))
          .toList());
});

final fundTransactionsProvider = Provider<AsyncValue<List<FinanceTransaction>>>((ref) {
  return ref.watch(financeTransactionsProvider).whenData(
    (txs) => txs.where((tx) => tx.type == FinanceTransactionType.fund && !tx.isDeleted).toList()
  );
});

final closableMonthProvider = Provider<AsyncValue<DateTime?>>((ref) {
  final closingsAsync = ref.watch(monthlyClosingsProvider);

  return closingsAsync.whenData((closings) {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    
    if (closings.isEmpty) {
      // Initialization Mode: Target most recent completed month
      final lastMonth = DateTime(now.year, now.month - 1);
      return lastMonth;
    }

    // Sort by year and month descending to get the latest closing
    final sorted = List<MonthlyClosing>.from(closings)
      ..sort((a, b) {
        if (a.year != b.year) return b.year.compareTo(a.year);
        return b.month.compareTo(a.month);
      });

    final latest = sorted.first;
    // The next closable month is the one after the latest closed month
    final nextClosable = DateTime(latest.year, latest.month + 1);

    // If nextClosable is the current month or later, nothing to close yet
    if (nextClosable.isAtSameMomentAs(currentMonth) || nextClosable.isAfter(currentMonth)) {
      return null;
    }

    return nextClosable;
  });
});

