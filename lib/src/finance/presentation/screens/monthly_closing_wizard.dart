import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/finance_providers.dart';
import '../../../core/format/money.dart';
import '../../../core/firebase/firebase_providers.dart';

class MonthlyClosingWizard extends ConsumerStatefulWidget {
  const MonthlyClosingWizard({super.key, required this.targetMonth});

  final DateTime targetMonth;

  @override
  ConsumerState<MonthlyClosingWizard> createState() => _MonthlyClosingWizardState();
}

class _MonthlyClosingWizardState extends ConsumerState<MonthlyClosingWizard> {
  int _currentStep = 0;
  
  final _cashCarryController = TextEditingController();
  final _bankCarryController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedReason;
  
  bool _isSubmitting = false;

  final List<String> _reasons = [
    'Owner Withdrawal',
    'Salary Reserve',
    'Business Expansion',
    'Cash Deposit',
    'Investment Return',
    'Other'
  ];

  @override
  void dispose() {
    _cashCarryController.dispose();
    _bankCarryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Closing ${DateFormat('MMMM yyyy').format(widget.targetMonth)}')),
      body: Stepper(
        type: StepperType.horizontal,
        currentStep: _currentStep,
        onStepContinue: _currentStep < 1 ? () => setState(() => _currentStep++) : _submit,
        onStepCancel: _currentStep > 0 ? () => setState(() => _currentStep--) : () => Navigator.pop(context),
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: Row(
              children: [
                if (_isSubmitting)
                  const CircularProgressIndicator()
                else ...[
                  Expanded(
                    child: FilledButton(
                      onPressed: details.onStepContinue,
                      child: Text(_currentStep == 1 ? 'Confirm & Close Month' : 'Next'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Back'),
                  ),
                ]
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Carry Forward'),
            isActive: _currentStep >= 0,
            content: _buildInputsStep(),
          ),
          Step(
            title: const Text('Confirm'),
            isActive: _currentStep >= 1,
            content: _buildPreviewStep(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputsStep() {
    final balancesAsync = ref.watch(financeBalancesProvider);
    
    return balancesAsync.when(
      data: (balances) {
        if (balances == null) return const Text('Loading balances...');
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Balances', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _infoRow('Cash Balance', formatRupeesFromPaise(balances.cash)),
            _infoRow('Bank Balance', formatRupeesFromPaise(balances.bank)),
            const Divider(height: 32),
            const Text('How much should carry forward?'),
            const SizedBox(height: 16),
            TextField(
              controller: _cashCarryController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Carry Forward Cash (Rs.)',
                border: OutlineInputBorder(),
                prefixText: 'Rs. ',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bankCarryController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Carry Forward Bank (Rs.)',
                border: OutlineInputBorder(),
                prefixText: 'Rs. ',
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Text('Error loading balances: $err'),
    );
  }

  Widget _buildPreviewStep() {
    final balances = ref.read(financeBalancesProvider).value;
    if (balances == null) return const Text('Error: No balance data');

    final carryCash = (double.tryParse(_cashCarryController.text) ?? 0) * 100;
    final carryBank = (double.tryParse(_bankCarryController.text) ?? 0) * 100;
    
    final adjCash = balances.cash - carryCash;
    final adjBank = balances.bank - carryBank;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Closing Summary for ${DateFormat('MMMM yyyy').format(widget.targetMonth)}', 
          style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _previewRow('Closing Cash', formatRupeesFromPaise(balances.cash)),
        _previewRow('Carry Forward Cash', formatRupeesFromPaise(carryCash.round()), bold: true),
        _previewRow('Adjustment Cash', formatRupeesFromPaise(adjCash.round()), color: Colors.red),
        const Divider(),
        _previewRow('Closing Bank', formatRupeesFromPaise(balances.bank)),
        _previewRow('Carry Forward Bank', formatRupeesFromPaise(carryBank.round()), bold: true),
        _previewRow('Adjustment Bank', formatRupeesFromPaise(adjBank.round()), color: Colors.red),
        const Divider(height: 32),
        DropdownButtonFormField<String>(
          value: _selectedReason,
          decoration: const InputDecoration(labelText: 'Reason for Difference', border: OutlineInputBorder()),
          items: _reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
          onChanged: (v) => setState(() => _selectedReason = v),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _notesController,
          decoration: const InputDecoration(labelText: 'Additional Notes', border: OutlineInputBorder()),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))],
      ),
    );
  }

  Widget _previewRow(String label, String value, {bool bold = false, Color? color}) {
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

  Future<void> _submit() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a reason')),
      );
      return;
    }

    final carryCash = (double.tryParse(_cashCarryController.text) ?? 0) * 100;
    final carryBank = (double.tryParse(_bankCarryController.text) ?? 0) * 100;

    if (carryCash < 0 || carryBank < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Carry forward values cannot be negative')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(monthlyClosingRepositoryProvider);
      if (repo == null) throw Exception('Repository not available');
      
      final userId = ref.read(firebaseAuthProvider).currentUser?.uid ?? 'unknown';

      await repo.closeMonth(
        month: widget.targetMonth.month,
        year: widget.targetMonth.year,
        carryForwardCash: carryCash.round(),
        carryForwardBank: carryBank.round(),
        reason: _selectedReason!,
        notes: _notesController.text.trim(),
        userId: userId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Month closed successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
