import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'widgets/cancellation_dialog.dart';
import '../../core/utils/business_date_utils.dart';
import '../../core/widgets/sync_indicator.dart';
import '../application/order_controller.dart';
import '../data/dashboard_providers.dart';
import '../domain/order_models.dart';
import '../../core/format/money.dart';
import '../../business/data/business_providers.dart';
import '../../core/utils/toast_service.dart';
import 'package:share_plus/share_plus.dart';

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

class _OrderTile extends ConsumerWidget {
  const _OrderTile({required this.order});
  final SavedOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = DateFormat('hh:mm a');
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Opacity(
      opacity: order.isCancelled ? 0.7 : 1.0,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showOrderDetails(context, order),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Order ID + Actions
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#${order.id.substring(order.id.length - 6).toUpperCase()}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurfaceVariant,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PendingSyncBadge(isSynced: order.isSynced),
                    const Spacer(),
                    _OrderPopupMenu(order: order),
                  ],
                ),
                const SizedBox(height: 8),

                // Customer Info
                Text(
                  order.customerName ?? 'Guest Customer',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Items Summary
                Text(
                  order.lines.map((l) => '${l.qty}x ${l.item.name}').join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                ),

                if (order.isCancelled && order.cancellationReason != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Reason: ${CancellationReason.fromString(order.cancellationReason)?.displayName ?? order.cancellationReason}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Bottom Row: Amount + Info (left), Status (right)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rs. ${formatRupeesFromPaise(order.totalPaise)}',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: order.isCancelled ? cs.outline : cs.primary,
                                  fontWeight: FontWeight.w900,
                                  decoration: order.isCancelled ? TextDecoration.lineThrough : null,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${order.paymentMethod.name.toUpperCase()} • ${fmt.format(order.timestamp)}',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.5),
                                  letterSpacing: 0.3,
                                ),
                          ),
                        ],
                      ),
                    ),
                    _OrderStatusChip(order: order),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOrderDetails(BuildContext context, SavedOrder order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: _OrderDetailsSheet(order: order),
      ),
    );
  }
}

class _OrderPopupMenu extends ConsumerWidget {
  const _OrderPopupMenu({required this.order});
  final SavedOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_vert, color: cs.onSurfaceVariant),
      onSelected: (value) async {
        switch (value) {
          case 'edit':
            ref.read(orderControllerProvider.notifier).editOrder(order);
            context.go('/dashboard');
            break;
          case 'cancel':
            showDialog(
              context: context,
              builder: (context) => CancellationDialog(order: order),
            );
            break;
          case 'repeat':
            ref.read(orderControllerProvider.notifier).repeatOrder(order);
            context.go('/dashboard');
            ref.read(toastServiceProvider).showSuccess(context, 'Items added to current order');
            break;
          case 'share':
            final text = _generateShareText(order);
            await Share.share(text, subject: 'Invoice for Order #${order.id.substring(order.id.length - 6).toUpperCase()}');
            break;
        }
      },
      itemBuilder: (context) => [
        if (order.isEditable)
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_rounded, size: 18),
                SizedBox(width: 12),
                Text('Edit Order'),
              ],
            ),
          ),
        if (order.isEditable)
          const PopupMenuItem(
            value: 'cancel',
            child: Row(
              children: [
                Icon(Icons.cancel_rounded, size: 18, color: Colors.red),
                SizedBox(width: 12),
                Text('Cancel Order', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'repeat',
          child: Row(
            children: [
              Icon(Icons.repeat_rounded, size: 18),
              SizedBox(width: 12),
              Text('Repeat Order'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'share',
          child: Row(
            children: [
              Icon(Icons.share_rounded, size: 18),
              SizedBox(width: 12),
              Text('Share Invoice'),
            ],
          ),
        ),
      ],
    );
  }

  String _generateShareText(SavedOrder order) {
    final buffer = StringBuffer();
    buffer.writeln('Order Receipt');
    buffer.writeln('Order ID: #${order.id.substring(order.id.length - 6).toUpperCase()}');
    buffer.writeln('Date: ${DateFormat('MMM dd, yyyy hh:mm a').format(order.timestamp)}');
    buffer.writeln('--------------------------');
    for (final line in order.lines) {
      buffer.writeln('${line.qty}x ${line.item.name} - Rs. ${formatRupeesFromPaise(line.lineTotalPaise)}');
    }
    buffer.writeln('--------------------------');
    if (order.discountPaise > 0) {
      buffer.writeln('Discount: -Rs. ${formatRupeesFromPaise(order.discountPaise)}');
    }
    buffer.writeln('Total Amount: Rs. ${formatRupeesFromPaise(order.totalPaise)}');
    buffer.writeln('Payment: ${order.paymentMethod.name.toUpperCase()} (${order.paymentStatus.name.toUpperCase()})');
    buffer.writeln('--------------------------');
    buffer.writeln('Thank you for your business!');
    return buffer.toString();
  }
}

class _OrderStatusChip extends StatelessWidget {
  const _OrderStatusChip({required this.order});
  final SavedOrder order;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    if (order.isCancelled || order.status == OrderStatus.refunded) {
      color = Colors.red;
      label = 'CANCELLED';
      icon = Icons.cancel_rounded;
    } else if (order.paymentStatus == PaymentStatus.paid || order.status == OrderStatus.completed || order.status == OrderStatus.served) {
      color = Colors.green;
      label = 'COMPLETED';
      icon = Icons.check_circle_rounded;
    } else {
      color = Colors.orange;
      label = 'PENDING';
      icon = Icons.pending_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
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
    final dateFmt = DateFormat('MMM dd, yyyy • hh:mm a');

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Drag Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order Details',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                        ),
                        Text(
                          '#${order.id.toUpperCase()}',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                                letterSpacing: 1,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: cs.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                children: [
                  // Business & Timestamp Info
                  if (business != null) ...[
                    Text(
                      business.businessName.toUpperCase(),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: cs.primary,
                          ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    dateFmt.format(order.timestamp),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 24),

                  // Status Badge Section
                  Row(
                    children: [
                      _OrderStatusChip(order: order),
                      const Spacer(),
                      if (!order.isCancelled)
                        TextButton.icon(
                          onPressed: () {
                            ref.read(orderControllerProvider.notifier).editOrder(order);
                            Navigator.pop(context);
                            context.go('/dashboard');
                          },
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          label: const Text('Edit'),
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Customer Section
                  if (order.customerName != null || order.customerPhone != null) ...[
                    _SectionHeader(title: 'CUSTOMER'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: cs.primaryContainer,
                            radius: 20,
                            child: Icon(Icons.person_rounded, size: 20, color: cs.onPrimaryContainer),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.customerName ?? 'No Name Provided',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                if (order.customerPhone != null)
                                  Text(
                                    order.customerPhone!,
                                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Cancellation Info
                  if (order.isCancelled) ...[
                    _SectionHeader(title: 'CANCELLATION INFO'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                CancellationReason.fromString(order.cancellationReason)?.displayName ?? 
                                order.cancellationReason ?? 'Reason not specified',
                                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          if (order.cancelledAt != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Cancelled on: ${dateFmt.format(order.cancelledAt!)}',
                              style: const TextStyle(fontSize: 12, color: Colors.red),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Order Items Section
                  _SectionHeader(title: 'ITEMS'),
                  const SizedBox(height: 12),
                  ...order.lines.map((l) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${l.qty}x',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                l.item.name,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            Text(
                              'Rs. ${formatRupeesFromPaise(l.lineTotalPaise)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(),
                  ),

                  // Summary Section
                  _SummaryRow(
                    label: 'Subtotal',
                    value: 'Rs. ${formatRupeesFromPaise(order.subtotalPaise)}',
                  ),
                  if (order.discountPaise > 0)
                    _SummaryRow(
                      label: 'Discount (${order.discountType.name})',
                      value: '-Rs. ${formatRupeesFromPaise(order.discountPaise)}',
                      valueColor: Colors.red,
                    ),
                  const SizedBox(height: 8),
                  _SummaryRow(
                    label: 'Total',
                    value: 'Rs. ${formatRupeesFromPaise(order.totalPaise)}',
                    isBold: true,
                    fontSize: 20,
                  ),
                  const SizedBox(height: 16),
                  
                  // Payment Info Info
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.payment_rounded, size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text(
                          'Paid via ${order.paymentMethod.name.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        letterSpacing: 1.5,
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.fontSize = 14,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool isBold;
  final double fontSize;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w500,
              color: isBold ? null : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
              color: valueColor ?? (isBold ? Theme.of(context).colorScheme.primary : null),
            ),
          ),
        ],
      ),
    );
  }
}
