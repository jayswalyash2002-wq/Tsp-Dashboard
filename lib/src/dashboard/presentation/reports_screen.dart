import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/dashboard_providers.dart';
import '../domain/order_models.dart';
import '../../core/format/money.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sales Reports')),
      body: ordersAsync.when(
        data: (orders) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          
          final dailyOrders = orders.where((o) => 
            o.timestamp.year == today.year && 
            o.timestamp.month == today.month && 
            o.timestamp.day == today.day &&
            o.paymentStatus == PaymentStatus.paid
          ).toList();

          final thisWeekOrders = orders.where((o) {
            final diff = today.difference(DateTime(o.timestamp.year, o.timestamp.month, o.timestamp.day)).inDays;
            return diff < 7 && o.paymentStatus == PaymentStatus.paid;
          }).toList();

          final thisMonthOrders = orders.where((o) => 
            o.timestamp.year == today.year && 
            o.timestamp.month == today.month &&
            o.paymentStatus == PaymentStatus.paid
          ).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ReportCard(
                title: 'Today\'s Sales',
                orders: dailyOrders,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              _ReportCard(
                title: 'Last 7 Days',
                orders: thisWeekOrders,
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              _ReportCard(
                title: 'This Month',
                orders: thisMonthOrders,
                color: Colors.orange,
              ),
              const SizedBox(height: 24),
              Text('Recent Performance', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _CategoryBreakdown(orders: orders),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.title,
    required this.orders,
    required this.color,
  });

  final String title;
  final List<SavedOrder> orders;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final totalPaise = orders.fold(0, (sum, o) => sum + o.totalPaise);
    final count = orders.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '₹${formatRupeesFromPaise(totalPaise)}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count orders',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.orders});
  final List<SavedOrder> orders;

  @override
  Widget build(BuildContext context) {
    final categoryTotals = <String, int>{};
    for (final order in orders) {
      if (order.paymentStatus != PaymentStatus.paid) continue;
      for (final line in order.lines) {
        final cat = line.item.category;
        categoryTotals[cat] = (categoryTotals[cat] ?? 0) + line.lineTotalPaise;
      }
    }

    final sorted = categoryTotals.entries.toList()
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
                Text('₹${formatRupeesFromPaise(e.value)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          )).toList(),
        ),
      ),
    );
  }
}
