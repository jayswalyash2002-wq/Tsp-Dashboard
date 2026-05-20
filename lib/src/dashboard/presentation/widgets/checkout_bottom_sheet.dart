import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsp_dashboard/src/dashboard/application/order_controller.dart';
import 'package:tsp_dashboard/src/dashboard/domain/order_models.dart';
import 'cancellation_dialog.dart';
import 'order_shared_widgets.dart';
import '../../../core/rbac/permission.dart';
import '../../../core/rbac/permission_gate.dart';

class CheckoutBottomSheet extends ConsumerStatefulWidget {
  const CheckoutBottomSheet({super.key});

  @override
  ConsumerState<CheckoutBottomSheet> createState() => _CheckoutBottomSheetState();
}

class _CheckoutBottomSheetState extends ConsumerState<CheckoutBottomSheet> {
  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(orderControllerProvider);
    final draft = orderState.draft;
    final isCancelled = orderState.originalOrder?.isCancelled ?? false;
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.85, // increased initial size for better visibility
      minChildSize: 0.5,
      maxChildSize: 0.98,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // 1. Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              // 2. Header row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            orderState.isEditing ? 'Edit Order' : 'Current Order',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                          ),
                          Text(
                            '${draft.lines.length} ${draft.lines.length == 1 ? 'item' : 'items'} selected',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 3. Scrollable content area
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 120), // extra bottom padding
                  children: [
                    if (draft.lines.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Text('Your cart is empty'),
                        ),
                      )
                    else ...[
                      // A. Order items list
                      ...draft.lines.map((line) => OrderChip(line: line, isReadOnly: isCancelled)),
                    ],
                    const Divider(height: 48),
                    
                    // Billing & Payment Controls
                    Text(
                      'PAYMENT & DISCOUNTS',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.5),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: CompactSelect<DiscountType>(
                            label: 'Discount Type',
                            value: draft.discountType,
                            items: const {
                              DiscountType.none: 'None',
                              DiscountType.flat: 'Flat Rs.',
                              DiscountType.percent: 'Percent %',
                              DiscountType.complimentary: 'Complimentary',
                            },
                            onChanged: isCancelled
                                ? null
                                : (v) {
                                    if (v == null) return;
                                    ref.read(orderControllerProvider.notifier).setDiscountType(v);
                                    if (v == DiscountType.flat || v == DiscountType.percent) {
                                      _showDiscountValueDialog(context, ref, v);
                                    }
                                  },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CompactSelect<PaymentMethod>(
                            label: 'Payment Method',
                            value: draft.paymentMethod,
                            items: const {
                              PaymentMethod.cash: 'Cash',
                              PaymentMethod.upi: 'Upi',
                              PaymentMethod.card: 'Card',
                              PaymentMethod.split: 'Split payment',
                            },
                            onChanged: isCancelled
                                ? null
                                : (v) {
                                    if (v == null) return;
                                    ref.read(orderControllerProvider.notifier).setPaymentMethod(v);
                                    if (v == PaymentMethod.split) {
                                      _showSplitPaymentDialog(context, ref, draft.totalPaise);
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    CompactSelect<PaymentStatus>(
                      label: 'Payment Status',
                      value: draft.paymentStatus,
                      items: const {
                        PaymentStatus.paid: 'Paid',
                        PaymentStatus.pending: 'Pending',
                      },
                      onChanged: isCancelled
                          ? null
                          : (v) {
                              if (v == null) return;
                              ref.read(orderControllerProvider.notifier).setPaymentStatus(v);
                            },
                    ),
                    const SizedBox(height: 32),
                    
                    // D. Order summary
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        children: [
                          _SummaryRow(
                            label: 'Subtotal',
                            value: 'Rs. ${(draft.subtotalPaise / 100).toStringAsFixed(0)}',
                          ),
                          if (draft.discountPaise > 0) ...[
                            const SizedBox(height: 8),
                            _SummaryRow(
                              label: 'Discount',
                              value: '-Rs. ${(draft.discountPaise / 100).toStringAsFixed(0)}',
                              valueColor: cs.error,
                              isBold: true,
                            ),
                          ],
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(),
                          ),
                          _SummaryRow(
                            label: 'Total Amount',
                            value: 'Rs. ${(draft.totalPaise / 100).toStringAsFixed(0)}',
                            isTotal: true,
                            valueColor: cs.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // 4. Fixed bottom section
              Container(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).padding.bottom),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 15,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCancelled) ...[
                       const _CancelledInfo(),
                    ] else
                      PermissionGate(
                        permission: Permission.createOrder,
                        fallback: const FilledButton(
                          onPressed: null,
                          child: Text('Unauthorized'),
                        ),
                        child: Column(
                          children: [
                            FilledButton(
                              onPressed: (!draft.hasItems || !draft.splitValid)
                                  ? null
                                  : () async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      try {
                                        await ref.read(orderControllerProvider.notifier).submit();
                                        if (mounted) Navigator.pop(context);
                                        messenger.showSnackBar(
                                          const SnackBar(content: Text('Order completed successfully')),
                                        );
                                      } catch (e) {
                                        messenger.showSnackBar(
                                          SnackBar(content: Text('Failed to save order: $e')),
                                        );
                                      }
                                    },
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(60),
                                backgroundColor: cs.primary,
                                foregroundColor: cs.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                !draft.splitValid
                                    ? 'Fix Split Amount'
                                    : (orderState.isEditing ? 'Update & Save' : 'Complete Order'),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (orderState.isEditing) ...[
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: () => _showCancelOrderDialog(context, ref, orderState.originalOrder!),
                                icon: const Icon(Icons.cancel_outlined, size: 20),
                                label: const Text('Cancel This Order'),
                                style: TextButton.styleFrom(
                                  foregroundColor: cs.error,
                                  minimumSize: const Size.fromHeight(44),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCancelOrderDialog(BuildContext context, WidgetRef ref, SavedOrder order) {
    showDialog(
      context: context,
      builder: (context) => CancellationDialog(order: order),
    );
  }

  void _showDiscountValueDialog(BuildContext context, WidgetRef ref, DiscountType type) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(type == DiscountType.flat ? 'Enter Flat Amount (Rs.)' : 'Enter Percentage (%)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: type == DiscountType.flat ? 'e.g. 50' : 'e.g. 10',
            suffixText: type == DiscountType.flat ? 'Rs.' : '%',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final val = int.tryParse(controller.text) ?? 0;
              if (type == DiscountType.flat) {
                ref.read(orderControllerProvider.notifier).setDiscountValue(val * 100);
              } else {
                ref.read(orderControllerProvider.notifier).setDiscountValue(val);
              }
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showSplitPaymentDialog(BuildContext context, WidgetRef ref, int totalPaise) {
    final cashController = TextEditingController();
    final upiController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Split Payment (Total: Rs. ${(totalPaise / 100).toStringAsFixed(0)})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: cashController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cash Amount (Rs.)', prefixText: 'Rs. '),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: upiController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'UPI/Other Amount (Rs.)', prefixText: 'Rs. '),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final cash = (int.tryParse(cashController.text) ?? 0) * 100;
              final upi = (int.tryParse(upiController.text) ?? 0) * 100;

              if (cash + upi != totalPaise) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Total split amount must match order total')),
                );
                return;
              }

              ref.read(orderControllerProvider.notifier).setSplitLines([
                SplitLine(method: PaymentMethod.cash, amountPaise: cash),
                SplitLine(method: PaymentMethod.upi, amountPaise: upi),
              ]);
              Navigator.pop(context);
            },
            child: const Text('Confirm Split'),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
    this.isBold = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool isTotal;
  final bool isBold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isTotal ? 4 : 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w500,
              color: isTotal ? cs.onSurface : cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 20 : 15,
              fontWeight: isTotal || isBold ? FontWeight.w900 : FontWeight.w700,
              color: valueColor ?? (isTotal ? cs.primary : cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelledInfo extends ConsumerWidget {
  const _CancelledInfo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderState = ref.watch(orderControllerProvider);
    final order = orderState.originalOrder!;
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cancel, color: Colors.red, size: 24),
                  SizedBox(width: 8),
                  Text('ORDER CANCELLED',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              if (order.cancellationReason != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Reason: ${CancellationReason.fromString(order.cancellationReason)?.displayName ?? order.cancellationReason}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              if (order.refundRequired)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.brown, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Refund Required',
                        style: TextStyle(fontSize: 13, color: Colors.brown, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const FilledButton(
          onPressed: null,
          child: Text('Cannot Modify Cancelled Order'),
        ),
      ],
    );
  }
}
