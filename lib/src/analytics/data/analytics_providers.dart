import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_providers.dart';
import '../../business/data/business_providers.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/utils/datetime_utils.dart';
import '../../dashboard/domain/order_models.dart';
import '../../expenses/domain/expense.dart';
import '../../inventory/domain/inventory_item.dart';
import '../domain/analytics_models.dart';
import 'analytics_repository.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  final db = ref.watch(firestoreProvider);
  final businessId = ref.watch(userBusinessIdProvider);
  return AnalyticsRepository(db, businessId ?? '');
});

final analyticsDateRangeProvider = StateProvider<AnalyticsDateRange>((ref) => AnalyticsDateRange.today);

final analyticsCustomDateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

double _calculateGrowth(num current, num previous) {
  if (previous == 0) return current > 0 ? 100.0 : 0.0;
  return ((current - previous) / previous) * 100;
}

final analyticsDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  debugPrint('ANALYTICS_PROVIDER: Starting data fetch...');
  final repo = ref.watch(analyticsRepositoryProvider);
  final range = ref.watch(analyticsDateRangeProvider);
  final customRange = ref.watch(analyticsCustomDateRangeProvider);
  
  // Wait for business data to ensure correct startHour and timezone
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) {
    debugPrint('ANALYTICS_PROVIDER: Business not loaded. Aborting fetch.');
    throw Exception('Business data required for analytics');
  }
  
  final startHour = business.businessDayStartHour;
  final timezone = business.timezone;

  debugPrint('ANALYTICS_PROVIDER: Config Resolved -> Timezone: $timezone, StartHour: $startHour');

  try {
    final now = DateTime.now();
    final bTime = DateTimeUtils.toBusinessTime(now, timezone);
    final currentOpDayRange = DateTimeUtils.getOperationalDayRange(bTime, startHour, timezone: timezone);
    final opDayDate = DateTimeUtils.getBusinessAdjustedDate(bTime, startHour);

    DateTime start;
    DateTime end;
    DateTime prevStart;
    DateTime prevEnd;

    switch (range) {
      case AnalyticsDateRange.today:
        start = currentOpDayRange.start;
        end = currentOpDayRange.end;
        prevStart = start.subtract(const Duration(days: 1));
        prevEnd = end.subtract(const Duration(days: 1));
        break;
      case AnalyticsDateRange.thisWeek:
        // Operational week starts on Monday
        final weekStartDay = opDayDate.subtract(Duration(days: opDayDate.weekday - 1));
        start = DateTimeUtils.getStartOfBusinessDay(weekStartDay, startHour, timezone: timezone);
        end = currentOpDayRange.end;
        prevStart = start.subtract(const Duration(days: 7));
        prevEnd = start.subtract(const Duration(seconds: 1));
        break;
      case AnalyticsDateRange.thisMonth:
        final monthStartDay = DateTime(opDayDate.year, opDayDate.month, 1);
        start = DateTimeUtils.getStartOfBusinessDay(monthStartDay, startHour, timezone: timezone);
        end = currentOpDayRange.end;
        prevStart = DateTimeUtils.getStartOfBusinessDay(
          DateTime(monthStartDay.year, monthStartDay.month - 1, 1), 
          startHour, 
          timezone: timezone
        );
        prevEnd = start.subtract(const Duration(seconds: 1));
        break;
      case AnalyticsDateRange.custom:
        if (customRange != null) {
          start = DateTimeUtils.getStartOfBusinessDay(customRange.start, startHour, timezone: timezone);
          end = DateTimeUtils.getEndOfBusinessDay(customRange.end, startHour, timezone: timezone);
          final duration = end.difference(start);
          prevStart = start.subtract(duration);
          prevEnd = start.subtract(const Duration(seconds: 1));
        } else {
          start = currentOpDayRange.start;
          end = currentOpDayRange.end;
          prevStart = start.subtract(const Duration(days: 1));
          prevEnd = end.subtract(const Duration(days: 1));
        }
        break;
    }

    debugPrint('ANALYTICS_PROVIDER: Query Range -> Start: $start, End: $end');
    
    final orders = await repo.getOrders(start, end);
    final expenses = await repo.getExpenses(start, end);
    final allInventory = await repo.getAllInventoryItems();
    
    final prevOrders = await repo.getOrders(prevStart, prevEnd);
    final prevExpenses = await repo.getExpenses(prevStart, prevEnd);

    // Monthly revenue for KPI card (Operational Month to Date)
    final monthStartDay = DateTime(opDayDate.year, opDayDate.month, 1);
    final opMonthStart = DateTimeUtils.getStartOfBusinessDay(monthStartDay, startHour, timezone: timezone);
    final monthlyOrders = await repo.getOrders(opMonthStart, end);

    debugPrint('ANALYTICS_PROVIDER: Successfully fetched data:');
    debugPrint(' - Orders: ${orders.length}');
    debugPrint(' - Prev Orders: ${prevOrders.length}');
    debugPrint(' - Monthly Orders: ${monthlyOrders.length}');
    debugPrint(' - Expenses: ${expenses.length}');
    debugPrint(' - Inventory Items: ${allInventory.length}');

    return {
      'orders': orders,
      'expenses': expenses,
      'inventory': allInventory,
      'prevOrders': prevOrders,
      'prevExpenses': prevExpenses,
      'monthlyOrders': monthlyOrders,
      'start': start,
      'end': end,
      'startHour': startHour,
      'timezone': timezone,
    };
  } catch (e, st) {
    debugPrint('ANALYTICS_PROVIDER ERROR: $e\n$st');
    rethrow;
  }
});

final analyticsSummaryProvider = Provider<AsyncValue<AnalyticsSummary>>((ref) {
  final dataAsync = ref.watch(analyticsDataProvider);
  final staffAsync = ref.watch(staffListProvider);

  return dataAsync.when(
    data: (data) {
      try {
        final List<SavedOrder> orders = data['orders'] as List<SavedOrder>;
        final List<Expense> expenses = data['expenses'] as List<Expense>;
        final List<SavedOrder> prevOrders = data['prevOrders'] as List<SavedOrder>;
        final List<Expense> prevExpenses = data['prevExpenses'] as List<Expense>;
        final List<InventoryItem> inventory = data['inventory'] as List<InventoryItem>;
        final List<SavedOrder> monthlyOrders = data['monthlyOrders'] as List<SavedOrder>;
        
        final String timezone = data['timezone'] as String;
        final int startHour = data['startHour'] as int;
        
        final staffCount = staffAsync.value?.length ?? 0;

        // Sales Aggregation
        final int revenue = orders.where((o) => o.shouldIncludeInSales).fold(0, (s, o) => s + o.totalPaise);
        final int prevRevenue = prevOrders.where((o) => o.shouldIncludeInSales).fold(0, (s, o) => s + o.totalPaise);
        final int ordersCount = orders.where((o) => o.shouldIncludeInSales).length;
        final int prevOrdersCount = prevOrders.where((o) => o.shouldIncludeInSales).length;

        // Expense & Profit
        final int totalExpenses = expenses.fold(0, (s, e) => s + e.amountPaise);
        final int prevExpensesTotal = prevExpenses.fold(0, (s, e) => s + e.amountPaise);
        final int profit = revenue - totalExpenses;
        final int prevProfit = prevRevenue - prevExpensesTotal;

        // Cancellations
        final cancelledOrders = orders.where((o) => o.status == OrderStatus.cancelled).toList();
        final Map<String, int> cancellationReasons = {};
        for (var o in cancelledOrders) {
          final reason = o.cancellationReason ?? 'Unknown';
          cancellationReasons[reason] = (cancellationReasons[reason] ?? 0) + 1;
        }

        // Hourly Heatmap
        final Map<int, int> hourlyCounts = {};
        for (var o in orders.where((o) => o.shouldIncludeInSales)) {
          final bTime = DateTimeUtils.toBusinessTime(o.timestamp, timezone);
          hourlyCounts[bTime.hour] = (hourlyCounts[bTime.hour] ?? 0) + 1;
        }
        final maxHourCount = hourlyCounts.values.isEmpty ? 1 : hourlyCounts.values.reduce((a, b) => a > b ? a : b);
        final Map<int, double> heatmap = {};
        for (int h = 0; h < 24; h++) {
          heatmap[h] = (hourlyCounts[h] ?? 0) / maxHourCount;
        }

        // Ingredient Usage
        final Map<String, double> ingredientUsage = {};
        final Map<String, String> idToName = {for (var item in inventory) item.id: item.name};
        for (var o in orders.where((o) => o.shouldIncludeInSales)) {
          for (var line in o.lines) {
            line.item.consumableMappings.forEach((ingredientId, qty) {
              final name = idToName[ingredientId] ?? ingredientId;
              ingredientUsage[name] = (ingredientUsage[name] ?? 0) + (qty * line.qty);
            });
          }
        }

        // Top Products
        final Map<String, int> productSales = {};
        for (var o in orders.where((o) => o.shouldIncludeInSales)) {
          for (var line in o.lines) {
            productSales[line.item.name] = (productSales[line.item.name] ?? 0) + line.qty;
          }
        }
        final sortedProducts = productSales.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final maxProductQty = sortedProducts.isEmpty ? 1 : sortedProducts.first.value;
        final topProducts = sortedProducts.take(10).map((e) => CategoryData(
          category: e.key,
          value: (e.value / maxProductQty) * 100,
          count: e.value,
        )).toList();

        // Inventory metrics
        final lowStock = inventory.where((i) => i.isLowStock).toList();

        // Staff Performance
        final List<StaffPerformanceMetric> staffPerformance = [];
        final staffList = staffAsync.value ?? [];
        for (var staff in staffList) {
          final staffOrders = orders.where((o) => o.userEmail == staff.email).toList();
          final staffRevenue = staffOrders.where((o) => o.shouldIncludeInSales).fold(0, (s, o) => s + o.totalPaise);
          final staffCancellations = staffOrders.where((o) => o.status == OrderStatus.cancelled).length;
          
          staffPerformance.add(StaffPerformanceMetric(
            staffName: staff.displayName,
            staffEmail: staff.email,
            ordersHandled: staffOrders.length,
            revenueGeneratedPaise: staffRevenue,
            cancellations: staffCancellations,
            efficiencyRating: staffOrders.isEmpty ? 0 : (1 - (staffCancellations / staffOrders.length)) * 5.0,
          ));
        }

        // Business Health Score Calculation
        final double revenueScore = (_calculateGrowth(revenue, prevRevenue).clamp(-100, 100) + 100) / 2;
        final double efficiencyScore = ordersCount == 0 ? 0 : (1 - (cancelledOrders.length / (ordersCount + cancelledOrders.length))) * 100;
        final double inventoryScore = inventory.isEmpty ? 100 : (1 - (lowStock.length / inventory.length)) * 100;
        final double staffScore = staffPerformance.isEmpty ? 0 : staffPerformance.map((e) => e.efficiencyRating).reduce((a, b) => a + b) / staffPerformance.length * 20;

        final healthScore = BusinessHealthScore(
          totalScore: (revenueScore + efficiencyScore + inventoryScore + staffScore) / 4,
          revenueScore: revenueScore,
          efficiencyScore: efficiencyScore,
          inventoryScore: inventoryScore,
          staffScore: staffScore,
        );

        // Operational Alerts (Extended)
        final List<String> alerts = [];
        if (lowStock.isNotEmpty) alerts.add('${lowStock.length} items are low on stock.');
        if (cancelledOrders.length > 5) alerts.add('High cancellation rate detected (${cancelledOrders.length} orders).');
        
        final peakHour = heatmap.entries.reduce((a, b) => a.value > b.value ? a : b);
        if (peakHour.value > 0.7) {
          alerts.add('Peak activity typically occurs around ${peakHour.key}:00.');
        }
        
        if (healthScore.totalScore < 40) {
          alerts.add('Critical: Business health score is low (${healthScore.totalScore.toStringAsFixed(0)}%). Review operational efficiency.');
        }

        return AsyncValue.data(AnalyticsSummary(
          revenuePaise: revenue,
          revenueGrowth: _calculateGrowth(revenue, prevRevenue),
          ordersCount: ordersCount,
          ordersGrowth: _calculateGrowth(ordersCount, prevOrdersCount),
          netProfitPaise: profit,
          netProfitGrowth: _calculateGrowth(profit, prevProfit),
          monthlyRevenuePaise: monthlyOrders.where((o) => o.shouldIncludeInSales).fold(0, (s, o) => s + o.totalPaise),
          averageOrderValuePaise: ordersCount > 0 ? (revenue / ordersCount) : 0.0,
          lowStockCount: lowStock.length,
          totalStaffCount: staffCount,
          cancelledOrdersCount: cancelledOrders.length,
          totalRefundsPaise: cancelledOrders.fold(0, (s, o) => s + o.totalPaise),
          cancellationReasonDistribution: cancellationReasons,
          hourlyHeatmap: heatmap,
          topSellingItems: topProducts,
          inventoryIngredientUsage: ingredientUsage,
          operationalAlerts: alerts,
          healthScore: healthScore,
          staffPerformance: staffPerformance,
          businessDayStartHour: startHour,
          timezone: timezone,
        ));
      } catch (e, st) {
        debugPrint('ANALYTICS_SUMMARY_PROVIDER ERROR: $e\n$st');
        return AsyncValue.error(e, st);
      }
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

final revenueChartDataProvider = Provider<AsyncValue<List<ChartDataPoint>>>((ref) {
  final dataAsync = ref.watch(analyticsDataProvider);
  
  return dataAsync.whenData((data) {
    try {
      final List<SavedOrder> orders = data['orders'] as List<SavedOrder>;
      final DateTime start = data['start'] as DateTime;
      final DateTime end = data['end'] as DateTime;
      final int startHour = data['startHour'] as int;
      final String timezone = data['timezone'] as String;

      final Map<DateTime, int> grouped = {};
      for (var o in orders.where((o) => o.shouldIncludeInSales)) {
        final bTime = DateTimeUtils.toBusinessTime(o.timestamp, timezone);
        final opDay = DateTimeUtils.getBusinessAdjustedDate(bTime, startHour);
        final date = DateTime(opDay.year, opDay.month, opDay.day);
        grouped[date] = (grouped[date] ?? 0) + o.totalPaise;
      }

      final List<ChartDataPoint> points = [];
      DateTime opStart = DateTimeUtils.getBusinessAdjustedDate(start, startHour);
      opStart = DateTime(opStart.year, opStart.month, opStart.day);
      DateTime opEnd = DateTimeUtils.getBusinessAdjustedDate(end, startHour);
      opEnd = DateTime(opEnd.year, opEnd.month, opEnd.day);

      for (var d = opStart; d.isBefore(opEnd.add(const Duration(days: 1))); d = d.add(const Duration(days: 1))) {
        points.add(ChartDataPoint(
          date: d,
          value: (grouped[d] ?? 0).toDouble(),
        ));
      }
      debugPrint('REVENUE_CHART_PROVIDER: Generated ${points.length} points');
      return points;
    } catch (e, st) {
      debugPrint('REVENUE_CHART_PROVIDER ERROR: $e\n$st');
      return [];
    }
  });
});

final ordersByHourDataProvider = Provider<AsyncValue<List<ChartDataPoint>>>((ref) {
  final dataAsync = ref.watch(analyticsDataProvider);
  
  return dataAsync.whenData((data) {
    try {
      final List<SavedOrder> orders = data['orders'] as List<SavedOrder>;
      final int startHour = data['startHour'] as int;
      final String timezone = data['timezone'] as String;
      final DateTime start = data['start'] as DateTime;
      
      final Map<int, int> grouped = {};
      for (var o in orders.where((o) => o.shouldIncludeInSales)) {
        final bTime = DateTimeUtils.toBusinessTime(o.timestamp, timezone);
        grouped[bTime.hour] = (grouped[bTime.hour] ?? 0) + 1;
      }

      List<int> sortedHours = List.generate(24, (i) => (i + startHour) % 24);
      final points = sortedHours.map((hour) {
        return ChartDataPoint(
          date: start, // Use period start as reference date
          value: (grouped[hour] ?? 0).toDouble(),
          label: '${hour}h',
        );
      }).toList();
      debugPrint('ORDERS_BY_HOUR_PROVIDER: Generated ${points.length} points');
      return points;
    } catch (e, st) {
      debugPrint('ORDERS_BY_HOUR_PROVIDER ERROR: $e\n$st');
      return [];
    }
  });
});

final expenseCategoryDataProvider = Provider<AsyncValue<List<CategoryData>>>((ref) {
  final dataAsync = ref.watch(analyticsDataProvider);
  
  return dataAsync.whenData((data) {
    try {
      final List<Expense> expenses = data['expenses'] as List<Expense>;
      if (expenses.isEmpty) return [];

      final Map<String, int> grouped = {};
      int total = 0;
      for (var e in expenses) {
        grouped[e.category] = (grouped[e.category] ?? 0) + e.amountPaise;
        total += e.amountPaise;
      }

      final sorted = grouped.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final result = sorted.map((e) => CategoryData(
        category: e.key,
        value: total > 0 ? (e.value / total) * 100 : 0.0,
        count: e.value,
      )).toList();
      debugPrint('EXPENSE_CATEGORY_PROVIDER: Generated ${result.length} categories');
      return result;
    } catch (e, st) {
      debugPrint('EXPENSE_CATEGORY_PROVIDER ERROR: $e\n$st');
      return [];
    }
  });
});

final topSellingProductsProvider = Provider<AsyncValue<List<CategoryData>>>((ref) {
  final dataAsync = ref.watch(analyticsDataProvider);
  
  return dataAsync.whenData((data) {
    try {
      final List<SavedOrder> orders = data['orders'] as List<SavedOrder>;
      final Map<String, int> productSales = {};

      for (var o in orders.where((o) => o.shouldIncludeInSales)) {
        for (var line in o.lines) {
          productSales[line.item.name] = (productSales[line.item.name] ?? 0) + line.qty;
        }
      }

      final sorted = productSales.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final maxQty = sorted.isEmpty ? 1 : sorted.first.value;

      final result = sorted.take(10).map((e) => CategoryData(
        category: e.key,
        value: (e.value / maxQty) * 100,
        count: e.value,
      )).toList();
      debugPrint('TOP_SELLING_PRODUCTS_PROVIDER: Generated ${result.length} items');
      return result;
    } catch (e, st) {
      debugPrint('TOP_SELLING_PRODUCTS_PROVIDER ERROR: $e\n$st');
      return [];
    }
  });
});
