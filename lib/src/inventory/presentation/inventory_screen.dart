import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/inventory_service.dart';
import '../data/inventory_providers.dart';
import '../domain/inventory_item.dart';

// Provider to track which items have already triggered a low-stock alert in this session
final alertedItemsProvider = StateProvider<Set<String>>((ref) => <String>{});

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryStreamProvider);
    final cs = Theme.of(context).colorScheme;

    // Listen for low stock events to show one-time snackbars
    ref.listen(inventoryStreamProvider, (previous, next) {
      if (next.hasValue) {
        final alerted = ref.read(alertedItemsProvider);
        final currentItems = next.value!;
        
        final newlyLow = currentItems.where((item) => item.isLowStock && !alerted.contains(item.id)).toList();
        final replenished = alerted.where((id) => currentItems.any((item) => item.id == id && !item.isLowStock)).toList();

        if (newlyLow.isNotEmpty || replenished.isNotEmpty) {
          final nextAlerts = {...alerted};
          
          // Clear replenished items from alerted set so they can alert again if they drop low later
          for (final id in replenished) {
            nextAlerts.remove(id);
          }

          for (final item in newlyLow) {
            nextAlerts.add(item.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${item.name} stock is below threshold (${item.stock} ${item.unit} remaining)'),
                backgroundColor: Colors.orange.shade900,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          ref.read(alertedItemsProvider.notifier).state = nextAlerts;
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Management'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SearchBar(
              hintText: 'Search inventory items...',
              onChanged: (val) => setState(() => _searchQuery = val),
              leading: const Icon(Icons.search),
              elevation: WidgetStateProperty.all(0),
              backgroundColor: WidgetStateProperty.all(cs.surfaceContainerHighest.withValues(alpha: 0.5)),
            ),
          ),
        ),
      ),
      body: inventoryAsync.when(
        data: (items) {
          final filtered = items
              .where((i) => i.name.toLowerCase().contains(_searchQuery.toLowerCase()))
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty ? 'No inventory items yet' : 'No items matching "$_searchQuery"',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final item = filtered[index];
              return _InventoryItemCard(item: item);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            height: 60,
            child: FilledButton.icon(
              onPressed: () => _showAddEditDialog(context),
              icon: const Icon(Icons.add),
              label: const Text(
                'Add Item',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddEditDialog(BuildContext context, [InventoryItem? item]) {
    showDialog(
      context: context,
      builder: (context) => _AddEditInventoryDialog(item: item),
    );
  }
}

class _InventoryItemCard extends ConsumerWidget {
  const _InventoryItemCard({required this.item});
  final InventoryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isLow = item.isLowStock;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showAddEditDialog(context, ref, item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              item.name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            if (isLow) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 10),
                                    SizedBox(width: 4),
                                    Text(
                                      'Low Stock',
                                      style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${item.stock}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: isLow ? Colors.orange : cs.primary,
                            ),
                      ),
                      Text(
                        item.unit,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isLow ? Icons.warning_amber_rounded : Icons.info_outline,
                        size: 14,
                        color: isLow ? Colors.orange : cs.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Threshold: ${item.lowStockThreshold} ${item.unit}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isLow ? Colors.orange : null,
                              fontWeight: isLow ? FontWeight.bold : null,
                            ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => _showAdjustStockDialog(context, ref, item),
                    icon: const Icon(Icons.edit_note, size: 18),
                    label: const Text('Update Stock'),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddEditDialog(BuildContext context, WidgetRef ref, InventoryItem item) {
    showDialog(
      context: context,
      builder: (context) => _AddEditInventoryDialog(item: item),
    );
  }

  void _showAdjustStockDialog(BuildContext context, WidgetRef ref, InventoryItem item) {
    final controller = TextEditingController(text: item.stock.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Adjust Stock: ${item.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Current Stock (${item.unit})',
            suffixText: item.unit,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final newStock = int.tryParse(controller.text) ?? item.stock;
              final service = ref.read(inventoryServiceProvider);
              await service.updateItem(item, item.copyWith(stock: newStock));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _AddEditInventoryDialog extends ConsumerStatefulWidget {
  const _AddEditInventoryDialog({this.item});
  final InventoryItem? item;

  @override
  ConsumerState<_AddEditInventoryDialog> createState() => _AddEditInventoryDialogState();
}

class _AddEditInventoryDialogState extends ConsumerState<_AddEditInventoryDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _stockController;
  late final TextEditingController _unitController;
  late final TextEditingController _thresholdController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name);
    _stockController = TextEditingController(text: widget.item?.stock.toString() ?? '0');
    _unitController = TextEditingController(text: widget.item?.unit ?? 'pcs');
    _thresholdController = TextEditingController(text: widget.item?.lowStockThreshold.toString() ?? '10');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _stockController.dispose();
    _unitController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Item' : 'Add Inventory Item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Item Name', hintText: 'e.g. Plastic Glass'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _stockController,
                    decoration: const InputDecoration(labelText: 'Initial Stock'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _unitController,
                    decoration: const InputDecoration(labelText: 'Unit', hintText: 'pcs/ml/g'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _thresholdController,
              decoration: const InputDecoration(labelText: 'Low Stock Threshold'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        if (isEdit)
          TextButton(
            onPressed: () => _confirmDelete(),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => _save(),
          child: Text(isEdit ? 'Update' : 'Add Item'),
        ),
      ],
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item?'),
        content: Text('Are you sure you want to delete "${widget.item!.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final service = ref.read(inventoryServiceProvider);
              await service.deleteItem(widget.item!);
              if (mounted) {
                Navigator.pop(context); // Close confirm
                Navigator.pop(context); // Close edit dialog
              }
            },
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final service = ref.read(inventoryServiceProvider);

    final newItem = InventoryItem(
      id: widget.item?.id ?? '',
      name: name,
      stock: int.tryParse(_stockController.text) ?? 0,
      unit: _unitController.text.trim(),
      lowStockThreshold: int.tryParse(_thresholdController.text) ?? 0,
    );

    if (widget.item != null) {
      await service.updateItem(widget.item!, newItem);
    } else {
      await service.addItem(newItem);
    }

    if (mounted) Navigator.pop(context);
  }
}
