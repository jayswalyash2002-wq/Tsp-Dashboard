class SalesReportData {
  SalesReportData({
    required this.totalSalesPaise,
    required this.totalOrders,
    required this.cashSalesPaise,
    required this.bankSalesPaise,
    required this.splitSalesPaise,
    required this.pendingSalesPaise,
    required this.totalDiscountsPaise,
    required this.topSellingItems,
  });

  final int totalSalesPaise;
  final int totalOrders;
  final int cashSalesPaise;
  final int bankSalesPaise;
  final int splitSalesPaise;
  final int pendingSalesPaise;
  final int totalDiscountsPaise;
  final List<TopItem> topSellingItems;
}

class TopItem {
  TopItem({required this.name, required this.qty});
  final String name;
  final int qty;
}

class ExpenseReportData {
  ExpenseReportData({
    required this.totalExpensesPaise,
    required this.categoryBreakdown,
    required this.cashExpensesPaise,
    required this.bankExpensesPaise,
    required this.totalFundAdditionsPaise,
    required this.cashBalancePaise,
    required this.bankBalancePaise,
  });

  final int totalExpensesPaise;
  final Map<String, int> categoryBreakdown;
  final int cashExpensesPaise;
  final int bankExpensesPaise;
  final int totalFundAdditionsPaise;
  final int cashBalancePaise;
  final int bankBalancePaise;
}
