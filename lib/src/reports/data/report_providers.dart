import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../dashboard/data/dashboard_providers.dart';
import '../../dashboard/domain/order_models.dart';
import '../../expenses/data/expense_providers.dart';
import '../../expenses/domain/fund_movement.dart';
import '../domain/report_models.dart';

final selectedDailyReportDateProvider = StateProvider<DateTime>((ref) {
  return ref.watch(effectiveBusinessDateProvider);
});

final salesReportProvider = Provider.family<SalesReportData, ReportDateRange>((ref, range) {
  final ordersAsync = ref.watch(ordersProvider);
  
  return ordersAsync.maybeWhen(
    data: (orders) {
      final filtered = orders.where((o) => 
        (o.timestamp.isAfter(range.start) || o.timestamp.isAtSameMomentAs(range.start)) &&
        (o.timestamp.isBefore(range.end) || o.timestamp.isAtSameMomentAs(range.end))
      ).toList();

      int totalSalesPaise = 0;
      int cashSalesPaise = 0;
      int bankSalesPaise = 0;
      int splitSalesPaise = 0;
      int pendingSalesPaise = 0;
      int totalDiscountsPaise = 0;
      final itemMap = <String, int>{};

      for (final o in filtered) {
        if (o.paymentStatus == PaymentStatus.paid) {
          totalSalesPaise += o.totalPaise;
          totalDiscountsPaise += o.discountPaise;
          
          switch (o.paymentMethod) {
            case PaymentMethod.cash:
              cashSalesPaise += o.totalPaise;
              break;
            case PaymentMethod.upi:
            case PaymentMethod.card:
              bankSalesPaise += o.totalPaise;
              break;
            case PaymentMethod.split:
              splitSalesPaise += o.totalPaise;
              break;
          }
        } else {
          pendingSalesPaise += o.totalPaise;
        }

        for (final line in o.lines) {
          itemMap[line.item.name] = (itemMap[line.item.name] ?? 0) + line.qty;
        }
      }

      final topItems = itemMap.entries
          .map((e) => TopItem(name: e.key, qty: e.value))
          .toList()
        ..sort((a, b) => b.qty.compareTo(a.qty));

      return SalesReportData(
        totalSalesPaise: totalSalesPaise,
        totalOrders: filtered.length,
        cashSalesPaise: cashSalesPaise,
        bankSalesPaise: bankSalesPaise,
        splitSalesPaise: splitSalesPaise,
        pendingSalesPaise: pendingSalesPaise,
        totalDiscountsPaise: totalDiscountsPaise,
        topSellingItems: topItems.take(5).toList(),
      );
    },
    orElse: () => SalesReportData(
      totalSalesPaise: 0,
      totalOrders: 0,
      cashSalesPaise: 0,
      bankSalesPaise: 0,
      splitSalesPaise: 0,
      pendingSalesPaise: 0,
      totalDiscountsPaise: 0,
      topSellingItems: [],
    ),
  );
});

final expenseReportProvider = Provider.family<ExpenseReportData, ReportDateRange>((ref, range) {
  final expensesAsync = ref.watch(expensesProvider);
  final fundsAsync = ref.watch(fundMovementsProvider);
  final balancesAsync = ref.watch(balancesProvider);

  return expensesAsync.maybeWhen(
    data: (expenses) {
      final filteredExpenses = expenses.where((e) => 
        e.timestamp.isAfter(range.start) && e.timestamp.isBefore(range.end)
      ).toList();

      final List<FundMovement> filteredFunds = fundsAsync.maybeWhen(
        data: (funds) => funds.where((f) => 
          f.timestamp.isAfter(range.start) && f.timestamp.isBefore(range.end)
        ).toList(),
        orElse: () => <FundMovement>[],
      );

      final Map<String, dynamic> balances = balancesAsync.maybeWhen(
        data: (b) => b,
        orElse: () => <String, dynamic>{},
      );

      int totalExpensesPaise = 0;
      int cashExpensesPaise = 0;
      int bankExpensesPaise = 0;
      final catMap = <String, int>{};

      for (final e in filteredExpenses) {
        totalExpensesPaise += e.amountPaise;
        catMap[e.category] = (catMap[e.category] ?? 0) + e.amountPaise;
        
        if (e.paymentMethod == PaymentMethod.cash) {
          cashExpensesPaise += e.amountPaise;
        } else {
          bankExpensesPaise += e.amountPaise;
        }
      }

      final int totalFundAdditionsPaise = filteredFunds.fold<int>(0, (sum, f) => sum + f.amountPaise);

      return ExpenseReportData(
        totalExpensesPaise: totalExpensesPaise,
        categoryBreakdown: catMap,
        cashExpensesPaise: cashExpensesPaise,
        bankExpensesPaise: bankExpensesPaise,
        totalFundAdditionsPaise: totalFundAdditionsPaise,
        cashBalancePaise: (balances['cashBalancePaise'] ?? 0) as int,
        bankBalancePaise: (balances['bankBalancePaise'] ?? 0) as int,
      );
    },
    orElse: () => ExpenseReportData(
      totalExpensesPaise: 0,
      categoryBreakdown: {},
      cashExpensesPaise: 0,
      bankExpensesPaise: 0,
      totalFundAdditionsPaise: 0,
      cashBalancePaise: 0,
      bankBalancePaise: 0,
    ),
  );
});

class ReportDateRange {
  ReportDateRange(this.start, this.end);
  final DateTime start;
  final DateTime end;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportDateRange &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => start.hashCode ^ end.hashCode;
}
