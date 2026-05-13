import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/firebase/firebase_providers.dart';
import '../domain/expense.dart';
import '../domain/fund_movement.dart';
import 'expense_repository.dart';
import 'fund_repository.dart';

final expenseRepositoryProvider = FutureProvider<ExpenseRepository>((ref) async {
  final db = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);
  return ExpenseRepository(db: db, auth: auth);
});

final fundRepositoryProvider = Provider<FundRepository>((ref) {
  final db = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);
  return FundRepository(db: db, auth: auth);
});

final expensesProvider = StreamProvider<List<Expense>>((ref) async* {
  final repo = await ref.watch(expenseRepositoryProvider.future);
  yield* repo.watchExpenses();
});

final fundMovementsProvider = StreamProvider<List<FundMovement>>((ref) {
  return ref.watch(fundRepositoryProvider).watchFundMovements();
});

final balancesProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final db = ref.watch(firestoreProvider);
  return db.collection('balances').doc('current').snapshots().map((s) => s.data() ?? {});
});
