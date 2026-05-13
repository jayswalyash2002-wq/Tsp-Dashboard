import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format/money.dart';
import '../data/report_providers.dart';
import '../domain/report_models.dart';

class SalesReportsScreen extends StatelessWidget {
  const SalesReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sales Reports'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Weekly'),
              Tab(text: 'Monthly'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SalesReportView(period: 'weekly'),
            _SalesReportView(period: 'monthly'),
          ],
        ),
      ),
    );
  }
}

class _SalesReportView extends ConsumerWidget {
  const _SalesReportView({required this.period});
  final String period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    late ReportDateRange range;

    if (period == 'weekly') {
      final start = now.subtract(const Duration(days: 7));
      range = ReportDateRange(start, now);
    } else {
      final start = DateTime(now.year, now.month, 1);
      range = ReportDateRange(start, now);
    }

    final data = ref.watch(salesReportProvider(range));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _MainMetricCard(
          label: 'Total sales',
          amount: data.totalSalesPaise,
          count: data.totalOrders,
          countLabel: 'orders',
        ),
        const SizedBox(height: 16),
        _MetricGrid(data: data),
        const SizedBox(height: 24),
        if (data.topSellingItems.isNotEmpty) ...[
          Text('Top selling items', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _TopItemsCard(items: data.topSellingItems),
        ],
      ],
    );
  }
}

class _MainMetricCard extends StatelessWidget {
  const _MainMetricCard({
    required this.label,
    required this.amount,
    required this.count,
    required this.countLabel,
  });
  final String label;
  final int amount;
  final int count;
  final String countLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: cs.onPrimaryContainer.withValues(alpha: 0.8))),
            const SizedBox(height: 8),
            Text(
              '₹${formatRupeesFromPaise(amount)}',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimaryContainer,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '$count $countLabel',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onPrimaryContainer.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.data});
  final SalesReportData data;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _SmallMetricCard(label: 'Cash sales', amount: data.cashSalesPaise),
        _SmallMetricCard(label: 'Bank sales', amount: data.bankSalesPaise),
        _SmallMetricCard(label: 'Split payments', amount: data.splitSalesPaise),
        _SmallMetricCard(label: 'Discounts', amount: data.totalDiscountsPaise, color: Colors.orange),
        _SmallMetricCard(label: 'Pending', amount: data.pendingSalesPaise, color: Colors.redAccent),
      ],
    );
  }
}

class _SmallMetricCard extends StatelessWidget {
  const _SmallMetricCard({required this.label, required this.amount, this.color});
  final String label;
  final int amount;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              '₹${formatRupeesFromPaise(amount)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopItemsCard extends StatelessWidget {
  const _TopItemsCard({required this.items});
  final List<TopItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(child: Text(item.name)),
                Text('${item.qty} units', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          )).toList(),
        ),
      ),
    );
  }
}
