import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/finance_providers.dart';
import '../../domain/models/monthly_closing.dart';
import '../../../core/format/money.dart';
import 'monthly_closing_wizard.dart';

import '../../../auth/data/auth_providers.dart';
import '../../../core/rbac/role.dart';
import '../../../core/firebase/firebase_providers.dart';
import 'monthly_summary_screen.dart';

class MonthlyClosingHistoryScreen extends ConsumerWidget {
  const MonthlyClosingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final closingsAsync = ref.watch(monthlyClosingsProvider);
    final closableMonth = ref.watch(closableMonthProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Closing History'),
        actions: [
          if (closableMonth != null)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Close New Month',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MonthlyClosingWizard(targetMonth: closableMonth)),
              ),
            ),
        ],
      ),
      body: closingsAsync.when(
        data: (closings) {
          if (closings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No closing history found.'),
                  const SizedBox(height: 16),
                  if (closableMonth != null)
                    ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => MonthlyClosingWizard(targetMonth: closableMonth)),
                      ),
                      child: const Text('Close a Month'),
                    ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: closings.length,
            itemBuilder: (context, index) {
              final closing = closings[index];
              final userRole = ref.watch(userRoleProvider).value;
              final isOwner = userRole == RoleType.owner;

              return _ClosingCard(closing: closing, isOwner: isOwner, ref: ref);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _ClosingCard extends StatelessWidget {
  final MonthlyClosing closing;
  final bool isOwner;
  final WidgetRef ref;
  const _ClosingCard({required this.closing, required this.isOwner, required this.ref});

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy').format(DateTime(closing.year, closing.month));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Text(monthName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Status: ${closing.isLocked ? "Locked" : "Unlocked"}'),
        trailing: Wrap(
          spacing: 12,
          children: [
            IconButton(
              icon: const Icon(Icons.bar_chart),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MonthlySummaryScreen(month: closing.month, year: closing.year)),
              ),
            ),
            if (closing.isLocked) 
              const Icon(Icons.lock, color: Colors.orange) 
            else 
              const Icon(Icons.lock_open, color: Colors.green),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row('Opening Cash', formatRupeesFromPaise(closing.openingCash)),
                _row('Opening Bank', formatRupeesFromPaise(closing.openingBank)),
                const Divider(),
                _row('Closing Cash', formatRupeesFromPaise(closing.closingCash)),
                _row('Closing Bank', formatRupeesFromPaise(closing.closingBank)),
                const Divider(),
                _row('Carry Forward Cash', formatRupeesFromPaise(closing.carryForwardCash), bold: true),
                _row('Carry Forward Bank', formatRupeesFromPaise(closing.carryForwardBank), bold: true),
                const Divider(),
                _row('Adjustment Cash', formatRupeesFromPaise(closing.adjustmentCash), color: Colors.red),
                _row('Adjustment Bank', formatRupeesFromPaise(closing.adjustmentBank), color: Colors.red),
                const SizedBox(height: 16),
                Text('Reason: ${closing.reason}', style: const TextStyle(fontWeight: FontWeight.bold)),
                if (closing.notes.isNotEmpty) Text('Notes: ${closing.notes}'),
                const SizedBox(height: 8),
                Text('Closed by: ${closing.closedBy}', style: Theme.of(context).textTheme.bodySmall),
                Text('At: ${DateFormat('MMM dd, yyyy HH:mm').format(closing.closedAt)}', style: Theme.of(context).textTheme.bodySmall),
                if (!closing.isLocked && closing.unlockedBy != null) ...[
                  const SizedBox(height: 8),
                  Text('Unlocked by: ${closing.unlockedBy}', style: const TextStyle(color: Colors.red, fontSize: 12)),
                  Text('Reason: ${closing.unlockReason}', style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
                if (closing.isLocked && isOwner) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.lock_open),
                      label: const Text('Unlock Month'),
                      onPressed: () => _showUnlockDialog(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showUnlockDialog(BuildContext context) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlock Month?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Unlocking allows edits but creates an audit log entry.'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Reason for unlocking', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) return;
              final repo = ref.read(monthlyClosingRepositoryProvider);
              final userId = ref.read(firebaseAuthProvider).currentUser?.uid ?? 'unknown';
              
              await repo?.unlockMonth(
                month: closing.month,
                year: closing.year,
                reason: reasonController.text.trim(),
                userId: userId,
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color,
          )),
        ],
      ),
    );
  }
}
