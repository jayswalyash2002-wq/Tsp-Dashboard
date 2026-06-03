import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/finance_providers.dart';
import '../../domain/models/finance_transaction.dart';
import '../../domain/models/finance_enums.dart';
import '../../../core/format/money.dart';

class MonthlySummaryScreen extends ConsumerWidget {
  final int month;
  final int year;

  const MonthlySummaryScreen({super.key, required this.month, required this.year});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(financeTransactionsProvider);
    final monthName = DateFormat('MMMM yyyy').format(DateTime(year, month));

    return Scaffold(
      appBar: AppBar(title: Text('$monthName Summary')),
      body: transactionsAsync.when(
        data: (allTransactions) {
          final txs = allTransactions.where((t) => t.month == month && t.year == year).toList();
          
          int openingCash = 0;
          int openingBank = 0;
          int revenueCash = 0;
          int revenueBank = 0;
          int expenseCash = 0;
          int expenseBank = 0;
          
          for (final tx in txs) {
            if (tx.isDeleted) continue;
            
            if (tx.type == FinanceTransactionType.opening_balance) {
              if (tx.account == FinanceAccount.cash) openingCash += tx.amount;
              if (tx.account == FinanceAccount.bank) openingBank += tx.amount;
            } else if (tx.type == FinanceTransactionType.fund) {
              if (tx.account == FinanceAccount.cash) revenueCash += tx.amount;
              if (tx.account == FinanceAccount.bank) revenueBank += tx.amount;
            } else if (tx.type == FinanceTransactionType.expense) {
              if (tx.account == FinanceAccount.cash) expenseCash += tx.amount;
              if (tx.account == FinanceAccount.bank) expenseBank += tx.amount;
            }
            // Transfers don't affect total revenue/expense usually, but affect individual balances
          }

          final currentCash = openingCash + revenueCash - expenseCash;
          final currentBank = openingBank + revenueBank - expenseBank;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _section('Opening Balance', [
                _row('Cash', formatRupeesFromPaise(openingCash)),
                _row('Bank', formatRupeesFromPaise(openingBank)),
              ]),
              const SizedBox(height: 24),
              _section('Revenue (Funds)', [
                _row('Cash', formatRupeesFromPaise(revenueCash)),
                _row('Bank', formatRupeesFromPaise(revenueBank)),
              ], color: Colors.green),
              const SizedBox(height: 24),
              _section('Expenses', [
                _row('Cash', formatRupeesFromPaise(expenseCash)),
                _row('Bank', formatRupeesFromPaise(expenseBank)),
              ], color: Colors.red),
              const Divider(height: 48),
              _section('Current Calculated Balance', [
                _row('Cash', formatRupeesFromPaise(currentCash), bold: true),
                _row('Bank', formatRupeesFromPaise(currentBank), bold: true),
              ], color: Colors.blue),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _section(String title, List<Widget> children, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
