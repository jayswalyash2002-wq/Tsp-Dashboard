import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsp_dashboard/src/dashboard/application/order_controller.dart';
import 'package:tsp_dashboard/src/dashboard/domain/order_models.dart';
import 'cancellation_dialog.dart';
import 'order_shared_widgets.dart';
import '../../../core/rbac/permission.dart';
import '../../../core/rbac/permission_gate.dart';
import '../../../business/data/business_providers.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/responsive_widgets.dart';
import '../../../customers/data/customer_providers.dart';
import '../../../customers/domain/customer.dart';

class CheckoutBottomSheet extends ConsumerStatefulWidget {
  const CheckoutBottomSheet({super.key});

  @override
  ConsumerState<CheckoutBottomSheet> createState() => _CheckoutBottomSheetState();
}

class _CheckoutBottomSheetState extends ConsumerState<CheckoutBottomSheet> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  final FocusNode _phoneFocusNode = FocusNode();
  Timer? _debounce;
  String _searchPhone = '';

  @override
  void initState() {
    super.initState();
    final draft = ref.read(orderControllerProvider).draft;
    _nameController = TextEditingController(text: draft.customerName);
    _phoneController = TextEditingController(text: draft.customerPhone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onPhoneChanged(String phone) {
    ref.read(orderControllerProvider.notifier).setCustomerDetails(phone: phone, clearId: true);
    
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final normalized = phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (normalized.length >= 10) {
        setState(() => _searchPhone = normalized);
      } else {
        setState(() => _searchPhone = '');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(orderControllerProvider);
    final draft = orderState.draft;
    final isCancelled = orderState.originalOrder?.isCancelled ?? false;
    final cs = Theme.of(context).colorScheme;
    final business = ref.watch(currentBusinessProvider).value;
    final isClosed = business != null && business.businessStatus == 'closed';

    // Automatic customer lookup
    if (_searchPhone.isNotEmpty) {
      ref.listen(customerSearchProvider(_searchPhone), (prev, next) {
        next.whenData((customer) {
          if (customer != null) {
            ref.read(orderControllerProvider.notifier).setCustomerDetails(
              customerId: customer.id,
              name: _nameController.text.trim().isEmpty ? customer.name : null,
            );
            if (_nameController.text.trim().isEmpty && customer.name != null) {
              _nameController.text = customer.name!;
            }
          }
        });
      });
    }

    final customerAsync = _searchPhone.isNotEmpty 
        ? ref.watch(customerSearchProvider(_searchPhone))
        : const AsyncValue<Customer?>.data(null);

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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                          ),
                          Text(
                            '${draft.lines.length} ${draft.lines.length == 1 ? 'item' : 'items'} selected',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                    const Divider(height: 32),

                    // Customer Details
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        title: Text(
                          'CUSTOMER DETAILS (OPTIONAL)',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.5),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                        ),
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: 16),
                        initiallyExpanded: draft.customerName != null || draft.customerPhone != null,
                        children: [
                          if (customerAsync.value != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
                              child: _ReturningCustomerBadge(customer: customerAsync.value!),
                            ),
                          ResponsiveFormRow(
                            children: [
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Customer Name',
                                  prefixIcon: Icon(Icons.person_outline),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onChanged: (v) => ref.read(orderControllerProvider.notifier).setCustomerDetails(name: v),
                                textCapitalization: TextCapitalization.words,
                                enabled: !isCancelled,
                              ),
                              RawAutocomplete<Customer>(
                                textEditingController: _phoneController,
                                focusNode: _phoneFocusNode,
                                optionsBuilder: (TextEditingValue textEditingValue) async {
                                  final text = textEditingValue.text.trim();
                                  if (text.length < 3) return const Iterable<Customer>.empty();
                                  final repo = ref.read(customerRepositoryProvider);
                                  return await repo?.searchCustomers(text) ?? [];
                                },
                                displayStringForOption: (Customer option) => option.phone,
                                onSelected: (Customer selection) {
                                  _nameController.text = selection.name ?? '';
                                  _phoneController.text = selection.phone;
                                  ref.read(orderControllerProvider.notifier).setCustomerDetails(
                                        customerId: selection.id,
                                        name: selection.name,
                                        phone: selection.phone,
                                      );
                                  setState(() => _searchPhone = selection.id);
                                },
                                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                  return TextFormField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    decoration: const InputDecoration(
                                      labelText: 'Phone Number',
                                      prefixIcon: Icon(Icons.phone_outlined),
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    keyboardType: TextInputType.phone,
                                    onChanged: _onPhoneChanged,
                                    enabled: !isCancelled,
                                    onFieldSubmitted: (value) => onFieldSubmitted(),
                                  );
                                },
                                optionsViewBuilder: (context, onSelected, options) {
                                  return _AutocompleteOptions(
                                    options: options,
                                    onSelected: onSelected,
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 32),
                    
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
                    ResponsiveFormRow(
                      children: [
                        CompactSelect<DiscountType>(
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
                        CompactSelect<PaymentMethod>(
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
                            if (isClosed)
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.lock_clock, color: Colors.red, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'Business is currently closed.',
                                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            FilledButton(
                              onPressed: (!draft.hasItems || !draft.splitValid || isClosed)
                                  ? null
                                  : () async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      try {
                                        await ref.read(orderControllerProvider.notifier).submit();
                                        if (!context.mounted) return;
                                        ref.read(toastServiceProvider).showSuccess(context, 'Order completed successfully');
                                        Navigator.pop(context);
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

class _AutocompleteOptions extends StatelessWidget {
  const _AutocompleteOptions({
    required this.options,
    required this.onSelected,
  });

  final Iterable<Customer> options;
  final AutocompleteOnSelected<Customer> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 8.0,
        borderRadius: BorderRadius.circular(12),
        color: cs.surfaceContainerHigh,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 250, maxWidth: 350),
          child: ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: options.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) {
              final Customer option = options.elementAt(index);
              return ListTile(
                title: Text(
                  option.name ?? 'Unknown Customer',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(option.phone),
                trailing: Icon(Icons.history, size: 16, color: cs.onSurfaceVariant),
                onTap: () => onSelected(option),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ReturningCustomerBadge extends StatelessWidget {
  const _ReturningCustomerBadge({required this.customer});
  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_outlined, color: cs.primary, size: 16),
          const SizedBox(width: 8),
          Text(
            'Returning Customer: ${customer.totalOrders} ${customer.totalOrders == 1 ? 'order' : 'orders'}',
            style: TextStyle(
              color: cs.primary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
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
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isTotal ? 18 : 14,
                fontWeight: isTotal ? FontWeight.w900 : FontWeight.w500,
                color: isTotal ? cs.onSurface : cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cancel, color: Colors.red, size: 24),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'ORDER CANCELLED',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (order.cancellationReason != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Reason: ${CancellationReason.fromString(order.cancellationReason)?.displayName ?? order.cancellationReason}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
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
                      Flexible(
                        child: Text(
                          'Refund Required',
                          style: TextStyle(fontSize: 13, color: Colors.brown, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
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
