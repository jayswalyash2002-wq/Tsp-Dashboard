import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/data/auth_providers.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/format/money.dart';
import '../../dashboard/domain/order_models.dart';
import '../data/expense_providers.dart';
import '../data/expense_repository.dart';
import '../domain/expense.dart';
import '../../core/widgets/responsive_widgets.dart';
import '../domain/fund_movement.dart';

import '../../activity_log/presentation/providers/activity_log_providers.dart';
import '../../activity_log/domain/entities/activity_log_enums.dart';
import '../../core/widgets/sync_indicator.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesProvider);
    final filteredExpensesAsync = ref.watch(filteredExpensesProvider);
    final balancesAsync = ref.watch(balancesProvider);
    final fundMovementsAsync = ref.watch(fundMovementsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          const SyncIndicator(),
          const SizedBox(width: 16),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _SummaryCard(balancesAsync: balancesAsync, expensesAsync: expensesAsync),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text('Recent fund additions', style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          SliverToBoxAdapter(
            child: fundMovementsAsync.when(
              data: (movements) {
                if (movements.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: Text('No fund additions recorded.')),
                  );
                }
                return SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: movements.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => _FundMovementCard(movement: movements[index]),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Expense history', style: Theme.of(context).textTheme.titleMedium),
                      const _ExpenseFilters(),
                    ],
                  ),
                ],
              ),
            ),
          ),
          filteredExpensesAsync.when(
            data: (expenses) {
              if (expenses.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('No expenses recorded.')),
                );
              }

              final groups = _groupExpenses(expenses);
              
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final group = groups[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    group.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.outline,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Total: Rs. ${formatRupeesFromPaise(group.totalPaise)}',
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...group.expenses.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ExpenseTile(expense: e),
                          )),
                        ],
                      );
                    },
                    childCount: groups.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(child: Text('Error: $e')),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showExpenseDialog(context),
        label: const Text('Add expense'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  List<_ExpenseGroup> _groupExpenses(List<Expense> expenses) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));
    final monthAgo = DateTime(now.year, now.month - 1, now.day);

    final Map<String, List<Expense>> groups = {
      'Today': [],
      'Yesterday': [],
      'Earlier This Week': [],
      'Earlier This Month': [],
      'Older': [],
    };

    for (final e in expenses) {
      final date = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
      if (date == today) {
        groups['Today']!.add(e);
      } else if (date == yesterday) {
        groups['Yesterday']!.add(e);
      } else if (date.isAfter(weekAgo)) {
        groups['Earlier This Week']!.add(e);
      } else if (date.isAfter(monthAgo)) {
        groups['Earlier This Month']!.add(e);
      } else {
        groups['Older']!.add(e);
      }
    }

    return groups.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => _ExpenseGroup(
              title: entry.key,
              expenses: entry.value,
              totalPaise: entry.value.fold(0, (sum, e) => sum + e.amountPaise),
            ))
        .toList();
  }

  void _showExpenseDialog(BuildContext context, [Expense? expense]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ExpenseFormSheet(expense: expense),
    );
  }
}

class _ExpenseGroup {
  final String title;
  final List<Expense> expenses;
  final int totalPaise;

  _ExpenseGroup({required this.title, required this.expenses, required this.totalPaise});
}

class _ExpenseFilters extends ConsumerWidget {
  const _ExpenseFilters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(expenseFilterProvider);
    final cs = Theme.of(context).colorScheme;

    return SegmentedButton<ExpenseFilter>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
      segments: const [
        ButtonSegment(value: ExpenseFilter.all, label: Text('All')),
        ButtonSegment(value: ExpenseFilter.settled, label: Text('Settled')),
        ButtonSegment(value: ExpenseFilter.unsettled, label: Text('Unsettled')),
      ],
      selected: {filter},
      onSelectionChanged: (set) => ref.read(expenseFilterProvider.notifier).state = set.first,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.balancesAsync, required this.expensesAsync});
  final AsyncValue<Map<String, dynamic>> balancesAsync;
  final AsyncValue<List<Expense>> expensesAsync;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          expensesAsync.maybeWhen(
            data: (expenses) {
              final total = expenses.fold(0, (sum, e) => sum + e.amountPaise);
              final unsettled = expenses
                  .where((e) => e.expenseStatus == 'unsettled')
                  .fold(0, (sum, e) => sum + e.amountPaise);
              final settled = expenses
                  .where((e) => e.expenseStatus == 'settled')
                  .fold(0, (sum, e) => sum + e.amountPaise);

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryItem(
                          label: 'Total Expenses',
                          amount: total,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryItem(
                          label: 'Unsettled',
                          amount: unsettled,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryItem(
                          label: 'Settled',
                          amount: settled,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          balancesAsync.maybeWhen(
            data: (balances) {
              final cash = balances['cashBalancePaise'] ?? 0;
              final bank = balances['bankBalancePaise'] ?? 0;
              return Row(
                children: [
                  Expanded(
                    child: _BalanceItem(
                      label: 'Cash',
                      amount: cash,
                      icon: Icons.payments_outlined,
                      color: Colors.green,
                      onAdd: () => _showAddFundsDialog(context, 'cash'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BalanceItem(
                      label: 'Bank',
                      amount: bank,
                      icon: Icons.account_balance_outlined,
                      color: Colors.blue,
                      onAdd: () => _showAddFundsDialog(context, 'bank'),
                    ),
                  ),
                ],
              );
            },
            orElse: () => const CircularProgressIndicator(),
          ),
        ],
      ),
    );
  }

  void _showAddFundsDialog(BuildContext context, String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddFundsSheet(initialType: type),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.amount,
    required this.color,
  });
  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          Text(
            'Rs. ${formatRupeesFromPaise(amount)}',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
          ),
        ],
      ),
    );
  }
}

class _BalanceItem extends StatelessWidget {
  const _BalanceItem({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
    required this.onAdd,
  });
  final String label;
  final int amount;
  final IconData icon;
  final Color color;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Stack(
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  Text(
                    'Rs. ${formatRupeesFromPaise(amount)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            right: -8,
            top: -8,
            child: IconButton(
              icon: Icon(Icons.add_circle, size: 20, color: color),
              onPressed: onAdd,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final isSettled = status == 'settled';
    final color = isSettled ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
class _FundMovementCard extends StatelessWidget {
  const _FundMovementCard({required this.movement});
  final FundMovement movement;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = DateFormat('MMM dd');
    final isCash = movement.type == 'cash';
    final color = isCash ? Colors.green : Colors.blue;

    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rs. ${formatRupeesFromPaise(movement.amountPaise)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(fmt.format(movement.timestamp), style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'to ${movement.type.toUpperCase()}',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            movement.reason,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ExpenseTile extends ConsumerWidget {
  const _ExpenseTile({required this.expense});
  final Expense expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final fmt = DateFormat('MMM dd, hh:mm a');
    final isSettled = expense.expenseStatus == 'settled';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showOptions(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                expense.category.toUpperCase(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: cs.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            PendingSyncBadge(isSynced: expense.isSynced),
                            if (!expense.isSynced) const SizedBox(width: 8),
                            _StatusBadge(status: expense.expenseStatus),
                          ],
                        ),
                        if (expense.payableTo != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Payable to: ${expense.payableTo}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Rs. ${formatRupeesFromPaise(expense.amountPaise)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isSettled ? Colors.green : Colors.redAccent,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (expense.notes.isNotEmpty) ...[
                Text(expense.notes, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${expense.paymentMethod.name.toUpperCase()} • ${expense.createdBy}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    fmt.format(expense.timestamp),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit expense'),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => _ExpenseFormSheet(expense: expense),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete expense', style: TextStyle(color: Colors.red)),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                try {
                  final repo = await ref.read(expenseRepositoryProvider.future);
                  if (repo == null) throw StateError('Expense repository not available');
                  
                  await repo.deleteExpense(
                    expense,
                  );

                  unawaited(
                    ref.read(logActivityUseCaseProvider).execute(
                      action: ActivityAction.expenseDeleted,
                      category: ActivityCategory.financial,
                      targetType: 'expense',
                      targetId: expense.id,
                      targetName: expense.category,
                      metadata: {'amount': expense.amountPaise / 100},
                    ),
                  );

                  messenger.showSnackBar(const SnackBar(content: Text('Expense deleted')));
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseFormSheet extends ConsumerStatefulWidget {
  const _ExpenseFormSheet({this.expense});
  final Expense? expense;

  @override
  ConsumerState<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends ConsumerState<_ExpenseFormSheet> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _customCategoryController = TextEditingController();
  final _payableToController = TextEditingController();
  
  String? _selectedCategory;
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  String _expenseStatus = 'unsettled';
  bool _busy = false;

  final List<String> _categories = [
    'Milk', 'Cocoa', 'Ice', 'Water bottles', 'Cups', 
    'Mango stock', 'Dry fruits', 'Fuel', 'Maintenance', 'Miscellaneous', 'Custom'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.expense != null) {
      _amountController.text = (widget.expense!.amountPaise / 100).toStringAsFixed(0);
      _notesController.text = widget.expense!.notes;
      _payableToController.text = widget.expense!.payableTo ?? '';
      _paymentMethod = widget.expense!.paymentMethod;
      _expenseStatus = widget.expense!.expenseStatus;
      if (_categories.contains(widget.expense!.category)) {
        _selectedCategory = widget.expense!.category;
      } else {
        _selectedCategory = 'Custom';
        _customCategoryController.text = widget.expense!.category;
      }
    } else {
      _selectedCategory = 'Milk';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _customCategoryController.dispose();
    _payableToController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) return;
    final amount = (double.tryParse(amountText) ?? 0) * 100;
    if (amount <= 0) return;

    final category = _selectedCategory == 'Custom' 
        ? _customCategoryController.text.trim() 
        : _selectedCategory;
    
    if (category == null || category.isEmpty) return;

    final payableTo = _payableToController.text.trim();
    if (_expenseStatus == 'unsettled' && payableTo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payable To is required for unsettled expenses')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final user = ref.read(deviceNameProvider) ?? 'User';
      final repo = await ref.read(expenseRepositoryProvider.future);
      if (repo == null) throw StateError('Expense repository not available');

      DateTime? settledAt;
      String? settledBy;

      if (_expenseStatus == 'settled') {
        // If it was already settled, keep original settlement info if editing
        if (widget.expense != null && widget.expense!.expenseStatus == 'settled') {
          settledAt = widget.expense!.settledAt;
          settledBy = widget.expense!.settledBy;
        } else {
          settledAt = DateTime.now();
          settledBy = user;
        }
      }

      final expense = Expense(
        id: widget.expense?.id ?? '',
        amountPaise: amount.round(),
        category: category,
        paymentMethod: _paymentMethod,
        notes: _notesController.text.trim(),
        createdBy: user,
        timestamp: widget.expense?.timestamp ?? DateTime.now(),
        timestampMs: widget.expense?.timestampMs ?? DateTime.now().millisecondsSinceEpoch,
        payableTo: payableTo.isNotEmpty ? payableTo : null,
        expenseStatus: _expenseStatus,
        settledAt: settledAt,
        settledBy: settledBy,
      );

      await repo.saveExpense(
        expense,
      );

      final isNew = widget.expense == null;
      unawaited(
        ref.read(logActivityUseCaseProvider).execute(
          action: isNew ? ActivityAction.expenseAdded : ActivityAction.expenseModified,
          category: ActivityCategory.financial,
          targetType: 'expense',
          targetId: expense.id,
          targetName: expense.category,
          metadata: {
            'amount': expense.amountPaise / 100,
            'paymentMethod': expense.paymentMethod.name,
          },
        ),
      );

      if (!context.mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.expense == null ? 'Add expense' : 'Edit expense',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              autofocus: widget.expense == null,
              decoration: const InputDecoration(
                labelText: 'Amount (Rs.)',
                border: OutlineInputBorder(),
                prefixText: 'Rs. ',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedCategory,
              decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
              items: _categories.map((c) => DropdownMenuItem(
                value: c, 
                child: Text(c, overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (v) => setState(() => _selectedCategory = v),
            ),
            if (_selectedCategory == 'Custom') ...[
              const SizedBox(height: 16),
              TextField(
                controller: _customCategoryController,
                decoration: const InputDecoration(labelText: 'Custom category name', border: OutlineInputBorder()),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _payableToController,
              decoration: const InputDecoration(
                labelText: 'Payable To',
                border: OutlineInputBorder(),
                hintText: 'e.g. Yash, Milk Vendor',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'unsettled', label: Text('Unsettled'), icon: Icon(Icons.pending_outlined)),
                ButtonSegment(value: 'settled', label: Text('Settled'), icon: Icon(Icons.check_circle_outline)),
              ],
              selected: {_expenseStatus},
              onSelectionChanged: (set) => setState(() => _expenseStatus = set.first),
            ),
            const SizedBox(height: 16),
            const Text('Payment Method', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<PaymentMethod>(
              segments: const [
                ButtonSegment(value: PaymentMethod.cash, label: Text('Cash'), icon: Icon(Icons.payments_outlined)),
                ButtonSegment(value: PaymentMethod.upi, label: Text('UPI'), icon: Icon(Icons.qr_code_scanner)),
                ButtonSegment(value: PaymentMethod.card, label: Text('Card'), icon: Icon(Icons.credit_card)),
              ],
              selected: {_paymentMethod},
              onSelectionChanged: (set) => setState(() => _paymentMethod = set.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes (Optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(60)),
              child: _busy 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : Text(widget.expense == null ? 'Save expense' : 'Update expense'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddFundsSheet extends ConsumerStatefulWidget {
  const _AddFundsSheet({required this.initialType});
  final String initialType;

  @override
  ConsumerState<_AddFundsSheet> createState() => _AddFundsSheetState();
}

class _AddFundsSheetState extends ConsumerState<_AddFundsSheet> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  
  late String _type;
  String? _selectedReason;
  bool _busy = false;

  final List<String> _reasons = [
    'Opening balance', 'Owner contribution', 'Float cash', 
    'Emergency deposit', 'Cash refill', 'Miscellaneous'
  ];

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _selectedReason = _reasons.isNotEmpty ? _reasons[0] : '';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) return;
    final amount = (double.tryParse(amountText) ?? 0) * 100;
    if (amount <= 0) return;
    final reason = _selectedReason;
    if (reason == null) return;

    setState(() => _busy = true);
    try {
      final user = ref.read(firebaseAuthProvider).currentUser;
      final deviceName = ref.read(deviceNameProvider) ?? 'Unknown device';
      final repo = ref.read(fundRepositoryProvider);
      if (repo == null) throw StateError('Fund repository not available');

      final movement = FundMovement(
        id: '',
        type: _type,
        amountPaise: amount.round(),
        reason: reason,
        notes: _notesController.text.trim(),
        createdBy: deviceName,
        createdByUid: user?.uid ?? '',
        timestamp: DateTime.now(),
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        deviceName: deviceName,
      );

      await repo.addFunds(
        movement,
      );

      unawaited(
        ref.read(logActivityUseCaseProvider).execute(
          action: ActivityAction.fundAdded,
          category: ActivityCategory.financial,
          targetType: 'fund',
          targetName: movement.reason,
          metadata: {
            'amount': movement.amountPaise / 100,
            'type': movement.type,
          },
        ),
      );

      if (!context.mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add funds', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Amount (Rs.)',
                border: OutlineInputBorder(),
                prefixText: 'Rs. ',
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'cash', label: Text('Cash'), icon: Icon(Icons.payments_outlined)),
                ButtonSegment(value: 'bank', label: Text('Bank'), icon: Icon(Icons.account_balance_outlined)),
              ],
              selected: {_type},
              onSelectionChanged: (set) => setState(() => _type = set.first),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedReason,
              decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder()),
              items: _reasons.map((r) => DropdownMenuItem(
                value: r, 
                child: Text(r, overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (v) => setState(() => _selectedReason = v),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes (Optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(60)),
              child: _busy 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text('Save funds'),
            ),
          ],
        ),
      ),
    );
  }
}
