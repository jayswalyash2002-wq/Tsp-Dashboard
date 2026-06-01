import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/sync/local_database_service.dart';
import '../domain/expense.dart';
import '../domain/fund_movement.dart';
import 'expense_repository.dart';
import 'fund_repository.dart';

import '../../auth/data/auth_providers.dart';

final expenseRepositoryProvider = FutureProvider<ExpenseRepository?>((ref) async {
  final businessId = ref.watch(userBusinessIdProvider);
  if (businessId == null) return null;

  final db = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);
  final localDb = ref.watch(localDatabaseServiceProvider);
  return ExpenseRepository(
    db: db, 
    auth: auth, 
    localDb: localDb,
    businessId: businessId, 
  );
});

final fundRepositoryProvider = Provider<FundRepository?>((ref) {
  final businessId = ref.watch(userBusinessIdProvider);
  if (businessId == null) return null;

  final db = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);
  return FundRepository(
    db: db, 
    auth: auth, 
    businessId: businessId, 
  );
});

final expensesProvider = StreamProvider<List<Expense>>((ref) async* {
  final repo = await ref.watch(expenseRepositoryProvider.future);
  if (repo == null) {
    yield [];
  } else {
    yield* repo.watchExpenses();
  }
});

enum ExpenseFilter { all, settled, unsettled }
final expenseFilterProvider = StateProvider<ExpenseFilter>((ref) => ExpenseFilter.all);

final filteredExpensesProvider = Provider<AsyncValue<List<Expense>>>((ref) {
  final expensesAsync = ref.watch(expensesProvider);
  final filter = ref.watch(expenseFilterProvider);

  return expensesAsync.whenData((expenses) {
    if (filter == ExpenseFilter.all) return expenses;
    return expenses.where((e) => e.expenseStatus == filter.name).toList();
  });
});

final fundMovementsProvider = StreamProvider<List<FundMovement>>((ref) {
  final repo = ref.watch(fundRepositoryProvider);
  if (repo == null) return Stream.value([]);
  return repo.watchFundMovements();
});

final balancesProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final businessId = ref.watch(userBusinessIdProvider);
  if (businessId == null) return Stream.value({});

  final db = ref.watch(firestoreProvider);
  return db.collection('balances').doc(businessId).snapshots().map((s) => s.data() ?? {});
});
