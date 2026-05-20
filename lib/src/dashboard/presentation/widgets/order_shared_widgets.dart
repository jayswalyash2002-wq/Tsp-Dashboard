import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsp_dashboard/src/dashboard/application/order_controller.dart';
import 'package:tsp_dashboard/src/dashboard/domain/order_models.dart';

class OrderChip extends ConsumerWidget {
  const OrderChip({super.key, required this.line, this.isReadOnly = false});

  final OrderLine line;
  final bool isReadOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          // 1. Item Info (Name + Unit Price)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  line.item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                ),
                Text(
                  'Rs. ${(line.item.pricePaise / 100).toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          
          // 2. Quantity Controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                QtyButton(
                  icon: Icons.remove,
                  onPressed: isReadOnly
                      ? null
                      : () => ref.read(orderControllerProvider.notifier).decrement(line.item.id),
                ),
                SizedBox(
                  width: 32,
                  child: Text(
                    '${line.qty}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                QtyButton(
                  icon: Icons.add,
                  onPressed: isReadOnly
                      ? null
                      : () => ref.read(orderControllerProvider.notifier).increment(line.item.id),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 12),
          
          // 3. Line Total
          SizedBox(
            width: 70,
            child: Text(
              'Rs.${(line.lineTotalPaise / 100).toStringAsFixed(0)}',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: cs.primary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class QtyButton extends StatelessWidget {
  const QtyButton({super.key, required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}

class CompactSelect<T> extends StatelessWidget {
  const CompactSelect({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    this.onChanged,
  });

  final String label;
  final T value;
  final Map<T, String> items;
  final void Function(T?)? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: items.entries
          .map((e) => DropdownMenuItem<T>(value: e.key, child: Text(e.value)))
          .toList(growable: false),
      onChanged: onChanged,
    );
  }
}
