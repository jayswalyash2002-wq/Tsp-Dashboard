import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/business_date_utils.dart';
import '../application/order_controller.dart';
import '../data/dashboard_providers.dart';
import '../domain/order_models.dart';
import '../../core/format/money.dart';
import '../../business/data/business_providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => context.push('/sales-reports'),
          ),
        ],
      ),
      body: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(child: Text('No orders yet'));
          }

          // 5. Use a grouped structure like: Map<String, List<Order>>
          final groupedOrders = <String, List<SavedOrder>>{};

          for (final order in orders) {
            // Apply business day logic for grouping
            final dateStr = BusinessDateUtils.formatBusinessDate(order.createdAt ?? order.timestamp);
            groupedOrders.putIfAbsent(dateStr, () => []).add(order);
          }

          final flattenedItems = <dynamic>[];
          groupedOrders.forEach((date, ordersInDate) {
            flattenedItems.add(date);
            flattenedItems.addAll(ordersInDate);
          });

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: flattenedItems.length,
            itemBuilder: (context, index) {
              final item = flattenedItems[index];
              if (item is String) {
                return _DateHeader(date: item);
              }
              final order = item as SavedOrder;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _OrderTile(order: order),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date});
  final String date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 0, 12),
      child: Text(
        date,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});
  final SavedOrder order;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM dd, hh:mm a');
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _showOrderDetails(context, order);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    fmt.format(order.timestamp),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  _StatusChip(status: order.paymentStatus),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                order.lines.map((l) => '${l.qty}x ${l.item.name}').join(', '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${order.paymentMethod.name.toUpperCase()} • ${order.deviceName}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    'Rs. ${formatRupeesFromPaise(order.totalPaise)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOrderDetails(BuildContext context, SavedOrder order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _OrderDetailsSheet(order: order),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final PaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final isPaid = status == PaymentStatus.paid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isPaid ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isPaid ? Colors.green : Colors.orange,
        ),
      ),
    );
  }
}

class _OrderDetailsSheet extends ConsumerWidget {
  const _OrderDetailsSheet({required this.order});
  final SavedOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final business = ref.watch(currentBusinessProvider).value;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (business != null) ...[
            Center(
              child: Column(
                children: [
                  Text(business.businessName.toUpperCase(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  if (business.address != null)
                    Text(business.address!,
                        textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                  if (business.isGstRegistered)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('GSTIN: ${business.gstNumber}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  const SizedBox(height: 8),
                  const Divider(),
                ],
              ),
            ),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Order Details', style: Theme.of(context).textTheme.headlineSmall),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const Divider(),
          const SizedBox(height: 16),
          ...order.lines.map((l) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${l.qty}x ${l.item.name}'),
                Text('Rs. ${formatRupeesFromPaise(l.lineTotalPaise)}'),
              ],
            ),
          )),
          const SizedBox(height: 16),
          if (order.discountPaise > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Discount (${order.discountType.name})'),
                Text('-Rs. ${formatRupeesFromPaise(order.discountPaise)}', style: const TextStyle(color: Colors.red)),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Rs. ${formatRupeesFromPaise(order.totalPaise)}', style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () {
              ref.read(orderControllerProvider.notifier).editOrder(order);
              Navigator.pop(context);
              context.go('/dashboard');
            },
            icon: const Icon(Icons.edit),
            label: const Text('Edit Order'),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
