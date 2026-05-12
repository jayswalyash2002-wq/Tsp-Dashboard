import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_providers.dart';
import '../../core/firebase/firebase_providers.dart';
import '../application/order_controller.dart';
import '../data/dashboard_providers.dart';
import '../domain/menu_item.dart';
import '../domain/order_models.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final user = ref.watch(firebaseAuthProvider).currentUser;
    
    String userName = 'User';
    
    profileAsync.whenData((profile) {
      final name = profile?['displayName'] as String?;
      if (name != null && name.isNotEmpty) {
        userName = name;
      }
    });

    if (userName == 'User') {
      userName = user?.displayName ?? user?.email?.split('@')[0] ?? 'User';
    }

    final menu = ref.watch(menuItemsProvider);
    final draft = ref.watch(orderControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TSP Dashboard'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                userName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: menu.when(
                data: (items) {
                  final visible = items.where((i) => i.available).toList();
                  if (visible.isEmpty) {
                    return const Center(
                      child: Text('No available menu items'),
                    );
                  }
                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.25,
                    ),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final item = visible[index];
                      return _MenuCard(
                        item: item,
                        qtyInOrder: draft.lineFor(item.id)?.qty ?? 0,
                        onTap: () => ref.read(orderControllerProvider.notifier).add(item),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Menu error: $e')),
              ),
            ),
          ),
          _CurrentOrderBar(draft: draft),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.item,
    required this.onTap,
    required this.qtyInOrder,
  });

  final MenuItem item;
  final VoidCallback onTap;
  final int qtyInOrder;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (qtyInOrder > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'x$qtyInOrder',
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                item.category,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                '₹${(item.pricePaise / 100).toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentOrderBar extends ConsumerWidget {
  const _CurrentOrderBar({required this.draft});

  final OrderDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'Current order',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Text(
                'Subtotal ₹${(draft.subtotalPaise / 100).toStringAsFixed(0)}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: cs.onSurface.withValues(alpha: 0.85)),
              ),
            ],
          ),
          if (draft.discountPaise > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Spacer(),
                  Text(
                    'Discount -₹${(draft.discountPaise / 100).toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.error,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              const Spacer(),
              Text(
                'Total ₹${(draft.totalPaise / 100).toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!draft.hasItems)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'Tap menu items to add them.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onSurface.withValues(alpha: 0.7)),
              ),
            )
          else
            SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: draft.lines.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final line = draft.lines[index];
                  return _OrderChip(line: line);
                },
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CompactSelect<DiscountType>(
                  label: 'Discount',
                  value: draft.discountType,
                  items: const {
                    DiscountType.none: 'None',
                    DiscountType.flat: 'Flat ₹',
                    DiscountType.percent: 'Percent %',
                    DiscountType.complimentary: 'Complimentary',
                  },
                  onChanged: (v) {
                    ref.read(orderControllerProvider.notifier).setDiscountType(v);
                    if (v == DiscountType.flat || v == DiscountType.percent) {
                      _showDiscountValueDialog(context, ref, v);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CompactSelect<PaymentMethod>(
                  label: 'Payment method',
                  value: draft.paymentMethod,
                  items: const {
                    PaymentMethod.cash: 'Cash',
                    PaymentMethod.upi: 'Upi',
                    PaymentMethod.card: 'Card',
                    PaymentMethod.split: 'Split payment',
                  },
                  onChanged: (v) {
                    ref.read(orderControllerProvider.notifier).setPaymentMethod(v);
                    if (v == PaymentMethod.split) {
                       _showSplitPaymentDialog(context, ref, draft.totalPaise);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CompactSelect<PaymentStatus>(
                  label: 'Payment status',
                  value: draft.paymentStatus,
                  items: const {
                    PaymentStatus.paid: 'Paid',
                    PaymentStatus.pending: 'Pending',
                  },
                  onChanged: (v) => ref.read(orderControllerProvider.notifier).setPaymentStatus(v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: (!draft.hasItems || !draft.splitValid)
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            final repo = await ref.read(orderRepositoryProvider.future);
                            final orderId = await repo.saveOrder(draft);
                            ref.read(orderControllerProvider.notifier).clear();
                            messenger.showSnackBar(
                              SnackBar(content: Text('Order saved: $orderId')),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Failed to save order: $e')),
                            );
                          }
                        },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    draft.splitValid ? 'Save order' : 'Fix split payment',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDiscountValueDialog(BuildContext context, WidgetRef ref, DiscountType type) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(type == DiscountType.flat ? 'Enter Flat Amount (₹)' : 'Enter Percentage (%)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: type == DiscountType.flat ? 'e.g. 50' : 'e.g. 10',
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
        title: Text('Split Payment (Total: ₹${(totalPaise/100).toStringAsFixed(0)})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: cashController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cash Amount (₹)'),
            ),
            TextField(
              controller: upiController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'UPI/Other Amount (₹)'),
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

class _OrderChip extends ConsumerWidget {
  const _OrderChip({required this.line});

  final OrderLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            line.item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          Row(
            children: [
              _QtyButton(
                icon: Icons.remove,
                onPressed: () => ref.read(orderControllerProvider.notifier).decrement(line.item.id),
              ),
              const SizedBox(width: 10),
              Text(
                '${line.qty}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(width: 10),
              _QtyButton(
                icon: Icons.add,
                onPressed: () => ref.read(orderControllerProvider.notifier).increment(line.item.id),
              ),
              const Spacer(),
              Text(
                '₹${(line.lineTotalPaise / 100).toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        minimumSize: const Size(46, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _CompactSelect<T> extends StatelessWidget {
  const _CompactSelect({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: items.entries
          .map(
            (e) => DropdownMenuItem<T>(
              value: e.key,
              child: Text(e.value),
            ),
          )
          .toList(growable: false),
      onChanged: (v) {
        if (v == null) return;
        onChanged(v);
      },
    );
  }
}
