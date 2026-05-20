import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/format/money.dart';
import '../../core/utils/business_date_utils.dart';
import '../../dashboard/data/dashboard_providers.dart';
import '../data/report_providers.dart';
import '../domain/report_models.dart';
import '../services/report_export_service.dart';
import '../../business/data/business_providers.dart';
import '../../business/domain/business.dart';

class SalesReportsScreen extends StatelessWidget {
  const SalesReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sales Reports'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Daily'),
              Tab(text: 'Weekly'),
              Tab(text: 'Monthly'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _SalesReportView(period: 'daily'),
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

    if (period == 'daily') {
      final businessDate = ref.watch(selectedDailyReportDateProvider);
      final brange = BusinessDateUtils.getBusinessDayRange(businessDate);

      // If it's the current business day, end at 'now', otherwise end at 4am of next day
      final currentBusinessDate = ref.watch(effectiveBusinessDateProvider);
      final isCurrentDay = businessDate.year == currentBusinessDate.year &&
          businessDate.month == currentBusinessDate.month &&
          businessDate.day == currentBusinessDate.day;

      range = ReportDateRange(brange.start, isCurrentDay ? now : brange.end);
    } else if (period == 'weekly') {
      range = ReportDateRange(
        BusinessDateUtils.getStartOfBusinessWeek(now),
        BusinessDateUtils.getEndOfBusinessWeek(now),
      );
    } else {
      range = ReportDateRange(
        BusinessDateUtils.getStartOfBusinessMonth(now),
        BusinessDateUtils.getEndOfBusinessMonth(now),
      );
    }

    final data = ref.watch(salesReportProvider(range));
    final business = ref.watch(currentBusinessProvider).value;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (period == 'daily') ...[
          const _DateSelector(),
          const SizedBox(height: 16),
        ],
        _MainMetricCard(
          label: 'Total sales',
          amount: data.totalSalesPaise,
          count: data.totalOrders,
          countLabel: 'orders',
        ),
        const SizedBox(height: 16),
        _MetricGrid(data: data),
        const SizedBox(height: 24),
        Text('Top selling items', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (data.topSellingItems.isNotEmpty)
          _TopItemsCard(items: data.topSellingItems)
        else
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No sales data for this period',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _exportExcel(context, range, data, business),
                  onLongPress: () =>
                      _exportExcel(context, range, data, business, forcePicker: true),
                  icon: const Icon(Icons.table_chart),
                  label: const Text('Export Excel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _exportPdf(context, range, data, business),
                  onLongPress: () =>
                      _exportPdf(context, range, data, business, forcePicker: true),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Export PDF'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Long press to change export folder',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
            ),
          ),
          const SizedBox(height: 24),
        ],
    );
  }

  Future<void> _exportExcel(
      BuildContext context,
      ReportDateRange range,
      SalesReportData data,
      Business? business,
      {bool forcePicker = false}) async {
    try {
      final result = await ReportExportService.exportToExcel(
        period: period,
        start: range.start,
        end: range.end,
        data: data,
        business: business,
        forcePicker: forcePicker,
      );

      if (!context.mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            action: result.path != null
                ? SnackBarAction(
                    label: 'Open',
                    onPressed: () => ReportExportService.openFile(result.path!),
                  )
                : null,
          ),
        );
      } else if (result.message != 'Export cancelled by user') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unexpected error: $e')),
        );
      }
    }
  }

  Future<void> _exportPdf(
      BuildContext context,
      ReportDateRange range,
      SalesReportData data,
      Business? business,
      {bool forcePicker = false}) async {
    try {
      final result = await ReportExportService.exportToPdf(
        period: period,
        start: range.start,
        end: range.end,
        data: data,
        business: business,
        forcePicker: forcePicker,
      );

      if (!context.mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            action: result.path != null
                ? SnackBarAction(
                    label: 'Open',
                    onPressed: () => ReportExportService.openFile(result.path!),
                  )
                : null,
          ),
        );
      } else if (result.message != 'Export cancelled by user') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unexpected error: $e')),
        );
      }
    }
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
              'Rs. ${formatRupeesFromPaise(amount)}',
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
              'Rs. ${formatRupeesFromPaise(amount)}',
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

class _DateSelector extends ConsumerWidget {
  const _DateSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDailyReportDateProvider);
    final currentBusinessDate = ref.watch(effectiveBusinessDateProvider);
    final fmt = DateFormat('d MMMM yyyy');

    final isToday = selectedDate.year == currentBusinessDate.year &&
        selectedDate.month == currentBusinessDate.month &&
        selectedDate.day == currentBusinessDate.day;

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            final prev = selectedDate.subtract(const Duration(days: 1));
            ref.read(selectedDailyReportDateProvider.notifier).state = prev;
          },
        ),
        Expanded(
          child: InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2024),
                lastDate: currentBusinessDate,
              );
              if (picked != null) {
                ref.read(selectedDailyReportDateProvider.notifier).state = picked;
              }
            },
            child: Column(
              children: [
                Text(
                  isToday ? 'Today' : (isYesterday(selectedDate, currentBusinessDate) ? 'Yesterday' : fmt.format(selectedDate)),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (!isToday)
                  Text(
                    fmt.format(selectedDate),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: isToday
              ? null
              : () {
                  final next = selectedDate.add(const Duration(days: 1));
                  ref.read(selectedDailyReportDateProvider.notifier).state = next;
                },
        ),
      ],
    );
  }

  bool isYesterday(DateTime date, DateTime today) {
    final yesterday = today.subtract(const Duration(days: 1));
    return date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;
  }
}
