import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format/money.dart';
import '../../core/utils/business_date_utils.dart';
import '../data/report_providers.dart';
import '../domain/report_models.dart';

class ExpenseReportsScreen extends ConsumerWidget {
  const ExpenseReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final start = BusinessDateUtils.getStartOfBusinessMonth(now);
    final end = BusinessDateUtils.getEndOfBusinessMonth(now);
    final range = ReportDateRange(start, end);
    final data = ref.watch(expenseReportProvider(range));

    return Scaffold(
      appBar: AppBar(title: const Text('Expense Reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SummarySection(data: data),
          const SizedBox(height: 24),
          Text('Category breakdown', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _CategoryBreakdownCard(breakdown: data.categoryBreakdown),
          const SizedBox(height: 24),
          Text('Current balances', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _BalancesCard(data: data),
        ],
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.data});
  final ExpenseReportData data;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Card(
          color: cs.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Monthly expenses', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: cs.onErrorContainer.withValues(alpha: 0.8))),
                const SizedBox(height: 8),
                Text(
                  'Rs. ${formatRupeesFromPaise(data.totalExpensesPaise)}',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onErrorContainer,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Cash expenses',
                amount: data.cashExpensesPaise,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricTile(
                label: 'Bank expenses',
                amount: data.bankExpensesPaise,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _MetricTile(
          label: 'Total fund additions',
          amount: data.totalFundAdditionsPaise,
          color: cs.primary,
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.amount, required this.color});
  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              'Rs. ${formatRupeesFromPaise(amount)}',
              style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBreakdownCard extends StatelessWidget {
  const _CategoryBreakdownCard({required this.breakdown});
  final Map<String, int> breakdown;

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) {
      return const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No expenses recorded'))));
    }

    final sorted = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: sorted.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(child: Text(e.key)),
                Text('Rs. ${formatRupeesFromPaise(e.value)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          )).toList(),
        ),
      ),
    );
  }
}

class _BalancesCard extends StatelessWidget {
  const _BalancesCard({required this.data});
  final ExpenseReportData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _BalanceRow(label: 'Cash balance', amount: data.cashBalancePaise, color: Colors.green),
            const Divider(),
            _BalanceRow(label: 'Bank balance', amount: data.bankBalancePaise, color: Colors.blue),
          ],
        ),
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.label, required this.amount, required this.color});
  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            'Rs. ${formatRupeesFromPaise(amount)}',
            style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 18),
          ),
        ],
      ),
    );
  }
}
