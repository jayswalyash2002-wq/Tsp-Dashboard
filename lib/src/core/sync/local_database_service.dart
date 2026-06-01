import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../dashboard/domain/order_models.dart';
import '../../expenses/domain/expense.dart';
import 'sync_models.dart';

final localDatabaseServiceProvider = Provider((ref) => LocalDatabaseService());

class LocalDatabaseService {
  static const String ordersBoxName = 'orders_v1';
  static const String expensesBoxName = 'expenses_v1';

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(ordersBoxName);
    await Hive.openBox(expensesBoxName);
  }

  // --- Orders ---

  Future<void> saveOrder(SavedOrder order) async {
    final box = Hive.box(ordersBoxName);
    await box.put(order.id, order.toLocalMap());
  }

  List<SavedOrder> getAllOrders() {
    final box = Hive.box(ordersBoxName);
    return box.values.map((e) => SavedOrder.fromMap(
      (e as Map)['orderId'] ?? '', 
      Map<String, dynamic>.from(e)
    )).toList();
  }

  List<SavedOrder> getUnsyncedOrders() {
    return getAllOrders().where((o) => !o.isSynced).toList();
  }

  // --- Expenses ---

  Future<void> saveExpense(Expense expense) async {
    final box = Hive.box(expensesBoxName);
    await box.put(expense.id, expense.toLocalMap());
  }

  List<Expense> getAllExpenses() {
    final box = Hive.box(expensesBoxName);
    return box.values.map((e) => Expense.fromMap(
      (e as Map)['id'] ?? '', 
      Map<String, dynamic>.from(e)
    )).toList();
  }

  List<Expense> getUnsyncedExpenses() {
    return getAllExpenses().where((e) => !e.isSynced).toList();
  }

  Future<void> clearAll() async {
    await Hive.box(ordersBoxName).clear();
    await Hive.box(expensesBoxName).clear();
  }
}
