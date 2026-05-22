import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/order_models.dart';
import '../../application/order_controller.dart';

class CancellationDialog extends StatefulWidget {
  const CancellationDialog({super.key, required this.order});
  final SavedOrder order;

  @override
  State<CancellationDialog> createState() => _CancellationDialogState();
}

class _CancellationDialogState extends State<CancellationDialog> {
  CancellationReason? _selectedReason;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancel Order'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to cancel this order?'),
            const SizedBox(height: 16),
            const Text('This action will:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const Text('• Mark the order as cancelled', style: TextStyle(fontSize: 13)),
            const Text('• Exclude it from sales reports', style: TextStyle(fontSize: 13)),
            const Text('• Keep it in order history', style: TextStyle(fontSize: 13)),
            const Text('• Preserve audit and activity tracking', style: TextStyle(fontSize: 13)),
            if (widget.order.isPaid) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This order is already marked as paid. A refund may be required separately. Cancellation will not automatically process a refund.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text('Reason (optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            DropdownButtonFormField<CancellationReason>(
              value: _selectedReason,
              items: CancellationReason.values
                  .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(r.displayName),
                      ))
                  .toList(),
              onChanged: _isProcessing ? null : (val) => setState(() => _selectedReason = val),
              decoration: const InputDecoration(
                hintText: 'Select a reason',
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
          child: const Text('No'),
        ),
        Consumer(
          builder: (context, ref, child) {
            return FilledButton(
              onPressed: _isProcessing
                  ? null
                  : () async {
                      setState(() => _isProcessing = true);
                      try {
                        await ref.read(orderControllerProvider.notifier).cancelOrder(
                              order: widget.order,
                              reason: _selectedReason,
                            );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Order cancelled successfully')),
                          );
                        }
                      } catch (e) {
                        setState(() => _isProcessing = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to cancel order: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: _isProcessing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Yes, Cancel Order'),
            );
          },
        ),
      ],
    );
  }
}
