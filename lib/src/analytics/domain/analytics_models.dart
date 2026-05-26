import 'package:flutter/material.dart';

class AnalyticsSummary {
  final int revenuePaise;
  final double revenueGrowth;
  final int ordersCount;
  final double ordersGrowth;
  final int netProfitPaise;
  final double netProfitGrowth;
  final int monthlyRevenuePaise;
  final double averageOrderValuePaise;
  final int lowStockCount;
  final int totalStaffCount;
  
  // Operational Intelligence
  final int cancelledOrdersCount;
  final int totalRefundsPaise;
  final Map<String, int> cancellationReasonDistribution;
  final Map<int, double> hourlyHeatmap;
  final List<CategoryData> topSellingItems;
  final Map<String, double> inventoryIngredientUsage;
  final List<String> operationalAlerts;
  
  // Config used
  final int businessDayStartHour;
  final String timezone;

  // Enterprise Intelligence
  final BusinessHealthScore healthScore;
  final List<StaffPerformanceMetric> staffPerformance;
  final PredictiveInsights? predictions;

  AnalyticsSummary({
    required this.revenuePaise,
    required this.revenueGrowth,
    required this.ordersCount,
    required this.ordersGrowth,
    required this.netProfitPaise,
    required this.netProfitGrowth,
    required this.monthlyRevenuePaise,
    required this.averageOrderValuePaise,
    required this.lowStockCount,
    required this.totalStaffCount,
    required this.cancelledOrdersCount,
    required this.totalRefundsPaise,
    required this.cancellationReasonDistribution,
    required this.hourlyHeatmap,
    required this.topSellingItems,
    required this.inventoryIngredientUsage,
    required this.operationalAlerts,
    required this.healthScore,
    this.businessDayStartHour = 0,
    this.timezone = 'UTC',
    this.staffPerformance = const [],
    this.predictions,
  });

  factory AnalyticsSummary.empty() => AnalyticsSummary(
        revenuePaise: 0,
        revenueGrowth: 0,
        ordersCount: 0,
        ordersGrowth: 0,
        netProfitPaise: 0,
        netProfitGrowth: 0,
        monthlyRevenuePaise: 0,
        averageOrderValuePaise: 0,
        lowStockCount: 0,
        totalStaffCount: 0,
        cancelledOrdersCount: 0,
        totalRefundsPaise: 0,
        cancellationReasonDistribution: {},
        hourlyHeatmap: {},
        topSellingItems: [],
        inventoryIngredientUsage: {},
        operationalAlerts: [],
        healthScore: BusinessHealthScore.initial(),
      );
}

class BusinessHealthScore {
  final double totalScore; // 0-100
  final double revenueScore;
  final double efficiencyScore;
  final double inventoryScore;
  final double staffScore;

  BusinessHealthScore({
    required this.totalScore,
    required this.revenueScore,
    required this.efficiencyScore,
    required this.inventoryScore,
    required this.staffScore,
  });

  factory BusinessHealthScore.initial() => BusinessHealthScore(
    totalScore: 0,
    revenueScore: 0,
    efficiencyScore: 0,
    inventoryScore: 0,
    staffScore: 0,
  );
}

class StaffPerformanceMetric {
  final String staffName;
  final String staffEmail;
  final int ordersHandled;
  final int revenueGeneratedPaise;
  final int cancellations;
  final double efficiencyRating; // 0-5.0

  StaffPerformanceMetric({
    required this.staffName,
    required this.staffEmail,
    required this.ordersHandled,
    required this.revenueGeneratedPaise,
    required this.cancellations,
    required this.efficiencyRating,
  });
}

class PredictiveInsights {
  final double predictedNextPeriodRevenueGrowth;
  final Map<int, double> predictedHourlyDemand;
  final List<String> inventoryDepletionForecast;

  PredictiveInsights({
    required this.predictedNextPeriodRevenueGrowth,
    required this.predictedHourlyDemand,
    required this.inventoryDepletionForecast,
  });
}

class ChartDataPoint {
  final DateTime date;
  final double value;
  final String? label;

  ChartDataPoint({required this.date, required this.value, this.label});
}

class CategoryData {
  final String category;
  final double value;
  final int? count;
  final Color? color;

  CategoryData({required this.category, required this.value, this.count, this.color});
}

enum AnalyticsDateRange {
  today,
  thisWeek,
  thisMonth,
  custom;

  String get displayName {
    switch (this) {
      case AnalyticsDateRange.today:
        return 'Today';
      case AnalyticsDateRange.thisWeek:
        return 'This Week';
      case AnalyticsDateRange.thisMonth:
        return 'This Month';
      case AnalyticsDateRange.custom:
        return 'Custom Range';
    }
  }
}
