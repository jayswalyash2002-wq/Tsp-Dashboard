import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/analytics_providers.dart';
import '../domain/analytics_models.dart';
import 'widgets/categorical_bar_chart.dart';
import 'widgets/chart_container.dart';
import 'widgets/date_filter_bar.dart';
import 'widgets/expense_pie_chart.dart';
import 'widgets/health_score_card.dart';
import 'widgets/hourly_heatmap.dart';
import 'widgets/kpi_card.dart';
import 'widgets/orders_chart.dart';
import 'widgets/revenue_chart.dart';
import 'widgets/staff_performance_table.dart';
import 'widgets/top_selling_chart.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('ANALYTICS_SCREEN: Building...');
    final summaryAsync = ref.watch(analyticsSummaryProvider);
    final range = ref.watch(analyticsDateRangeProvider);
    final dataAsync = ref.watch(analyticsDataProvider);
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Business Analytics'),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (dataAsync.isRefreshing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                debugPrint('ANALYTICS_SCREEN: Manual refresh triggered');
                ref.invalidate(analyticsDataProvider);
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          debugPrint('ANALYTICS_SCREEN: Pull-to-refresh triggered');
          ref.invalidate(analyticsDataProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DateFilterBar(),
              const SizedBox(height: 24),
              _buildOperationalInsights(summaryAsync, context),
              const SizedBox(height: 16),
              summaryAsync.when(
                data: (summary) => HealthScoreCard(score: summary.healthScore),
                loading: () => const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
                error: (e, st) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),
              _buildKpiGrid(summaryAsync, range),
              const SizedBox(height: 40),
              _buildAnalyticsSections(ref, summaryAsync),
              const SizedBox(height: 32),
              const _SectionHeader(title: 'Staff Intelligence', icon: Icons.badge_rounded),
              const SizedBox(height: 16),
              summaryAsync.when(
                data: (summary) => ChartContainer(
                  title: 'Performance Matrix',
                  subtitle: 'Activity and efficiency by staff member',
                  height: 300,
                  chart: StaffPerformanceTable(metrics: summary.staffPerformance),
                ),
                loading: () => const SizedBox(height: 300, child: Center(child: CircularProgressIndicator())),
                error: (e, st) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 32),
              const _SectionHeader(title: 'Predictive Forecasting', icon: Icons.auto_graph_rounded),
              const SizedBox(height: 16),
              ChartContainer(
                title: 'AI Revenue Forecast',
                subtitle: 'Predicted growth for the next period',
                height: 250,
                chart: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.model_training_rounded, size: 48, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
                      const SizedBox(height: 16),
                      const Text(
                        'AI Model Training in Progress',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Future revenue predictions will appear here',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              
              if (kDebugMode) ...[
                const SizedBox(height: 40),
                _buildDebugInfo(ref),
              ],
              
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOperationalInsights(AsyncValue<AnalyticsSummary> summaryAsync, BuildContext context) {
    final theme = Theme.of(context);
    
    return summaryAsync.when(
      data: (summary) {
        if (summary.operationalAlerts.isEmpty) return const SizedBox.shrink();
        
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Operational Intelligence',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...summary.operationalAlerts.map((alert) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        alert,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.4,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildKpiGrid(AsyncValue<AnalyticsSummary> summaryAsync, AnalyticsDateRange range) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 1200;
        
        final crossAxisCount = isMobile ? 2 : (isTablet ? 3 : 6);
        final aspectRatio = isMobile ? 1.1 : (isTablet ? 1.3 : 1.5);
        
        String revenueLabel = 'Revenue';
        String ordersLabel = 'Orders';
        if (range == AnalyticsDateRange.today) {
          revenueLabel = 'Revenue Today';
          ordersLabel = 'Orders Today';
        } else if (range == AnalyticsDateRange.thisWeek) {
          revenueLabel = 'Revenue This Week';
          ordersLabel = 'Orders This Week';
        } else if (range == AnalyticsDateRange.thisMonth) {
          revenueLabel = 'Revenue This Month';
          ordersLabel = 'Orders This Month';
        }

        return summaryAsync.when(
          data: (summary) => GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: aspectRatio,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            children: [
              KpiCard(
                title: revenueLabel,
                value: '₹${(summary.revenuePaise / 100).toStringAsFixed(0)}',
                icon: Icons.currency_rupee_rounded,
                color: Colors.green,
                growth: summary.revenueGrowth,
              ),
              KpiCard(
                title: ordersLabel,
                value: summary.ordersCount.toString(),
                icon: Icons.shopping_bag_rounded,
                color: Colors.blue,
                growth: summary.ordersGrowth,
              ),
              KpiCard(
                title: 'Net Profit',
                value: '₹${(summary.netProfitPaise / 100).toStringAsFixed(0)}',
                icon: Icons.account_balance_wallet_rounded,
                color: summary.netProfitPaise >= 0 ? Colors.teal : Colors.red,
                growth: summary.netProfitGrowth,
              ),
              KpiCard(
                title: 'Monthly Sales',
                value: '₹${(summary.monthlyRevenuePaise / 100).toStringAsFixed(0)}',
                icon: Icons.calendar_today_rounded,
                color: Colors.purple,
              ),
              KpiCard(
                title: 'Avg Order',
                value: '₹${(summary.averageOrderValuePaise / 100).toStringAsFixed(0)}',
                icon: Icons.analytics_rounded,
                color: Colors.orange,
              ),
              KpiCard(
                title: 'Total Staff',
                value: summary.totalStaffCount.toString(),
                icon: Icons.people_alt_rounded,
                color: Colors.indigo,
              ),
            ],
          ),
          loading: () => _buildKpiSkeleton(crossAxisCount, aspectRatio),
          error: (e, st) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error loading KPIs: $e', textAlign: TextAlign.center),
            ),
          ),
        );
      },
    );
  }

  Widget _buildKpiSkeleton(int count, double aspectRatio) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: count,
      childAspectRatio: aspectRatio,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: List.generate(count, (index) => const KpiCard(
        title: '...',
        value: '---',
        icon: Icons.hourglass_empty,
        color: Colors.grey,
        isLoading: true,
      )),
    );
  }

  Widget _buildAnalyticsSections(WidgetRef ref, AsyncValue<AnalyticsSummary> summaryAsync) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        
        return Column(
          children: [
            const _SectionHeader(title: 'Revenue Analytics', icon: Icons.auto_graph_rounded),
            const SizedBox(height: 16),
            ChartContainer(
              title: 'Revenue Trend',
              subtitle: 'Daily sales performance',
              height: 380,
              chart: ref.watch(revenueChartDataProvider).when(
                data: (data) => RevenueChart(data: data),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error: $e')),
              ),
            ),
            const SizedBox(height: 32),
            const _SectionHeader(title: 'Order Analytics', icon: Icons.shopping_cart_rounded),
            const SizedBox(height: 16),
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ChartContainer(
                      title: 'Orders by Hour',
                      subtitle: 'Hourly traffic distribution',
                      height: 350,
                      chart: ref.watch(ordersByHourDataProvider).when(
                        data: (data) => OrdersChart(data: data),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, st) => Center(child: Text('Error: $e')),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: summaryAsync.when(
                      data: (summary) => ChartContainer(
                        title: 'Hourly Heatmap',
                        subtitle: 'Operational activity intensity',
                        height: 350,
                        chart: HourlyHeatmap(
                          heatmap: summary.hourlyHeatmap,
                          startHour: summary.businessDayStartHour,
                        ),
                      ),
                      loading: () => const ChartContainer(title: 'Hourly Heatmap', height: 350, chart: Center(child: CircularProgressIndicator())),
                      error: (e, st) => ChartContainer(title: 'Hourly Heatmap', height: 350, chart: Center(child: Text('Error: $e'))),
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  ChartContainer(
                    title: 'Orders by Hour',
                    subtitle: 'Hourly traffic distribution',
                    height: 350,
                    chart: ref.watch(ordersByHourDataProvider).when(
                      data: (data) => OrdersChart(data: data),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, st) => Center(child: Text('Error: $e')),
                    ),
                  ),
                  const SizedBox(height: 24),
                  summaryAsync.when(
                    data: (summary) => ChartContainer(
                      title: 'Hourly Heatmap',
                      subtitle: 'Operational activity intensity',
                      height: 400,
                      chart: HourlyHeatmap(
                        heatmap: summary.hourlyHeatmap,
                        startHour: summary.businessDayStartHour,
                      ),
                    ),
                    loading: () => const ChartContainer(title: 'Hourly Heatmap', height: 350, chart: Center(child: CircularProgressIndicator())),
                    error: (e, st) => ChartContainer(title: 'Hourly Heatmap', height: 350, chart: Center(child: Text('Error: $e'))),
                  ),
                ],
              ),
            const SizedBox(height: 32),
            const _SectionHeader(title: 'Business Insights', icon: Icons.insights_rounded),
            const SizedBox(height: 16),
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _buildExpenseSection(ref),
                        const SizedBox(height: 24),
                        _buildCancellationSection(summaryAsync),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: [
                        _buildProductPerformanceSection(ref),
                        const SizedBox(height: 24),
                        _buildIngredientUsageSection(summaryAsync),
                      ],
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  _buildExpenseSection(ref),
                  const SizedBox(height: 24),
                  _buildProductPerformanceSection(ref),
                  const SizedBox(height: 24),
                  _buildCancellationSection(summaryAsync),
                  const SizedBox(height: 24),
                  _buildIngredientUsageSection(summaryAsync),
                ],
              ),
            const SizedBox(height: 32),
            const _SectionHeader(title: 'System Health', icon: Icons.health_and_safety_rounded),
            const SizedBox(height: 16),
            summaryAsync.when(
              data: (summary) => Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: summary.lowStockCount > 0 
                    ? Colors.red.withValues(alpha: 0.05) 
                    : Colors.green.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: summary.lowStockCount > 0 
                      ? Colors.red.withValues(alpha: 0.1) 
                      : Colors.green.withValues(alpha: 0.1)
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: summary.lowStockCount > 0 ? Colors.red : Colors.green,
                    child: Icon(
                      summary.lowStockCount > 0 ? Icons.warning_rounded : Icons.check_circle_rounded,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    summary.lowStockCount > 0 
                      ? '${summary.lowStockCount} Items Low on Stock' 
                      : 'Inventory is healthy',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    summary.lowStockCount > 0 
                      ? 'Immediate action required for replenishment' 
                      : 'All items are above threshold levels'
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () => context.push('/inventory'),
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: LinearProgressIndicator(),
              ),
              error: (e, st) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.orange),
                    const SizedBox(width: 12),
                    Text('Health status unavailable: $e'),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProductPerformanceSection(WidgetRef ref) {
    return ChartContainer(
      title: 'Top Selling Products',
      subtitle: 'Most popular items by quantity',
      height: 400,
      chart: ref.watch(topSellingProductsProvider).when(
        data: (data) => TopSellingChart(data: data),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildCancellationSection(AsyncValue<AnalyticsSummary> summaryAsync) {
    return summaryAsync.when(
      data: (summary) {
        final data = summary.cancellationReasonDistribution.entries
            .map((e) => CategoryData(
                  category: e.key,
                  value: summary.cancelledOrdersCount > 0 ? (e.value / summary.cancelledOrdersCount) * 100 : 0,
                  count: e.value,
                ))
            .toList();

        return ChartContainer(
          title: 'Cancellations',
          subtitle: '${summary.cancelledOrdersCount} total cancelled orders',
          height: 300,
          chart: data.isEmpty 
            ? const Center(child: Text('No cancellations in this period'))
            : CategoricalBarChart(data: data),
        );
      },
      loading: () => const ChartContainer(title: 'Cancellations', height: 300, chart: Center(child: CircularProgressIndicator())),
      error: (e, st) => ChartContainer(title: 'Cancellations', height: 300, chart: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildIngredientUsageSection(AsyncValue<AnalyticsSummary> summaryAsync) {
    return summaryAsync.when(
      data: (summary) {
        final data = summary.inventoryIngredientUsage.entries
            .map((e) => CategoryData(
                  category: e.key,
                  value: 0, // Not used in this specific view
                  count: e.value.toInt(),
                ))
            .toList()
          ..sort((a, b) => b.count!.compareTo(a.count!));

        return ChartContainer(
          title: 'Ingredient Consumption',
          subtitle: 'Estimated usage based on orders',
          height: 400,
          chart: data.isEmpty 
            ? const Center(child: Text('No ingredient data available'))
            : SingleChildScrollView(
                child: CategoricalBarChart(data: data.take(15).toList(), suffix: ' units'),
              ),
        );
      },
      loading: () => const ChartContainer(title: 'Ingredient Consumption', height: 400, chart: Center(child: CircularProgressIndicator())),
      error: (e, st) => ChartContainer(title: 'Ingredient Consumption', height: 400, chart: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildDebugInfo(WidgetRef ref) {
    final dataAsync = ref.watch(analyticsDataProvider);
    return dataAsync.when(
      data: (data) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Debug Information', style: TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            Text('Orders Count: ${(data['orders'] as List).length}'),
            Text('Expenses Count: ${(data['expenses'] as List).length}'),
            Text('Monthly Orders: ${(data['monthlyOrders'] as List).length}'),
            Text('Inventory Items: ${(data['inventory'] as List).length}'),
            Text('Timezone: ${data['timezone']}'),
            Text('Range: ${data['start']} to ${data['end']}'),
          ],
        ),
      ),
      loading: () => const Center(child: Text('Loading debug info...')),
      error: (e, st) => Text('Debug Error: $e', style: const TextStyle(color: Colors.red)),
    );
  }

  Widget _buildExpenseSection(WidgetRef ref) {
    final expenseData = ref.watch(expenseCategoryDataProvider);
    
    return expenseData.when(
      data: (data) {
        debugPrint('ANALYTICS_SCREEN: Rendered expenses with ${data.length} categories');
        if (data.isEmpty) {
          return const ChartContainer(
            title: 'Expenses by Category',
            height: 350,
            chart: Center(child: Text('No expense data for this period')),
          );
        }
        if (data.length > 5) {
          return ChartContainer(
            title: 'Expenses by Category',
            subtitle: 'Distribution of costs',
            height: 350,
            chart: SingleChildScrollView(
              child: CategoricalBarChart(data: data, isCurrency: true),
            ),
          );
        } else {
          return ChartContainer(
            title: 'Expenses by Category',
            subtitle: 'Distribution of costs',
            height: 350,
            chart: ExpensePieChart(data: data),
          );
        }
      },
      loading: () => const ChartContainer(title: 'Expenses by Category', height: 350, chart: Center(child: CircularProgressIndicator())),
      error: (e, st) => ChartContainer(title: 'Expenses by Category', height: 350, chart: Center(child: Text('Error: $e'))),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Divider(
            color: theme.dividerColor.withValues(alpha: 0.05),
            thickness: 1,
          ),
        ),
      ],
    );
  }
}
