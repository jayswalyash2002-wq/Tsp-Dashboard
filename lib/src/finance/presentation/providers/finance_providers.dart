import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../auth/data/auth_providers.dart';
import '../../data/repositories/finance_repository.dart';
import '../../domain/models/finance_transaction.dart';
import '../../domain/models/finance_balance.dart';
import '../../domain/models/finance_enums.dart';

final financeRepositoryProvider = Provider<FinanceRepository?>((ref) {
  final businessId = ref.watch(userBusinessIdProvider);
  if (businessId == null) return null;

  final db = ref.watch(firestoreProvider);
  return FinanceRepository(db, businessId: businessId);
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
