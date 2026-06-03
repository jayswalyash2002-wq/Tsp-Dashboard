import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/finance_providers.dart';
import '../../../analytics/data/analytics_providers.dart';
import '../../../expenses/data/expense_providers.dart';
import '../../../core/format/money.dart';
import 'monthly_closing_wizard.dart';
import 'monthly_closing_history_screen.dart';

class MonthClosingScreen extends ConsumerWidget {
  const MonthClosingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    final analyticsSummaryAsync = ref.watch(analyticsSummaryProvider);
    final expensesAsync = ref.watch(expensesProvider);
    final balancesAsync = ref.watch(financeBalancesProvider);
    final closableMonthAsync = ref.watch(closableMonthProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Month Closing'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          closableMonthAsync.when(
            data: (closableMonth) {
              if (closableMonth == null) {
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
                        const SizedBox(height: 16),
                        Text(
                          'All Months Closed',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You are up to date. Next closing available after this month ends.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final fullMonthName = DateFormat('MMMM yyyy').format(closableMonth);

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'STATUS: PENDING',
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                      color: Colors.orange,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                fullMonthName,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                            ),
                            child: const Text(
                              'PENDING',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 48),
                      Text(
                        'Financial Summary',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricTile(
                              label: 'Revenue',
                              // Note: analyticsSummaryProvider should ideally target the closableMonth.
                              // For simplicity in this UI pass, we reuse the existing monthlyRevenuePaise.
                              valueAsync: analyticsSummaryAsync.whenData((s) => s.monthlyRevenuePaise),
                              color: Colors.green,
                              icon: Icons.trending_up,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _MetricTile(
                              label: 'Expenses',
                              valueAsync: expensesAsync.whenData((expenses) => expenses
                                  .where((e) => e.timestamp.month == closableMonth.month && e.timestamp.year == closableMonth.year)
                                  .fold(0, (sum, e) => sum + e.amountPaise)),
                              color: Colors.redAccent,
                              icon: Icons.trending_down,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      balancesAsync.maybeWhen(
                        data: (balances) => Row(
                          children: [
                            Expanded(
                              child: _MetricTile(
                                label: 'Cash Balance',
                                value: balances?.cash ?? 0,
                                color: cs.onSurfaceVariant,
                                icon: Icons.payments_outlined,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _MetricTile(
                                label: 'Bank Balance',
                                value: balances?.bank ?? 0,
                                color: cs.onSurfaceVariant,
                                icon: Icons.account_balance_outlined,
                              ),
                            ),
                          ],
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 40),
                      FilledButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MonthlyClosingWizard(
                              targetMonth: closableMonth,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Close Previous Month'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
          const SizedBox(height: 24),
          _ActionTile(
            title: 'Closing History',
            subtitle: 'View records of previous months',
            icon: Icons.history,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MonthlyClosingHistoryScreen()),
            ),
          ),
          _ActionTile(
            title: 'Unlock Requests',
            subtitle: 'Request to modify a closed month',
            icon: Icons.lock_open,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Unlock requests coming soon')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    this.value,
    this.valueAsync,
    required this.color,
    required this.icon,
  });

  final String label;
  final int? value;
  final AsyncValue<int>? valueAsync;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 4),
          if (valueAsync != null)
            valueAsync!.when(
              data: (v) => Text(
                'Rs. ${formatRupeesFromPaise(v)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
              loading: () => Text('...', style: TextStyle(color: color)),
              error: (_, __) => Text('Err', style: TextStyle(color: color)),
            )
          else
            Text(
              'Rs. ${formatRupeesFromPaise(value ?? 0)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
