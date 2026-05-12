import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/dashboard_providers.dart';
import '../domain/menu_item.dart';

class EditMenuScreen extends ConsumerWidget {
  const EditMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(menuItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Menu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showEditDialog(context, ref),
          ),
        ],
      ),
      body: menuAsync.when(
        data: (items) => ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              title: Text(item.name),
              subtitle: Text('${item.category} • ₹${(item.pricePaise / 100).toStringAsFixed(0)}'),
              trailing: Switch(
                value: item.available,
                onChanged: (val) {
                  final repo = ref.read(menuRepositoryProvider);
                  repo.updateMenuItem(MenuItem(
                    id: item.id,
                    name: item.name,
                    pricePaise: item.pricePaise,
                    category: item.category,
                    available: val,
                  ));
                },
              ),
              onTap: () => _showEditDialog(context, ref, item: item),
              onLongPress: () => _showDeleteConfirm(context, ref, item),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, {MenuItem? item}) {
    final nameController = TextEditingController(text: item?.name);
    final categoryController = TextEditingController(text: item?.category);
    final priceController = TextEditingController(
        text: item != null ? (item.pricePaise / 100).toStringAsFixed(0) : '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item == null ? 'Add Item' : 'Edit Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: 'Price (₹)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final cat = categoryController.text.trim();
              final price = (double.tryParse(priceController.text) ?? 0) * 100;

              if (name.isEmpty || cat.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }

              try {
                final repo = ref.read(menuRepositoryProvider);
                if (item == null) {
                  await repo.addMenuItem(MenuItem(
                    id: '',
                    name: name,
                    category: cat,
                    pricePaise: price.toInt(),
                    available: true,
                  ));
                } else {
                  await repo.updateMenuItem(MenuItem(
                    id: item.id,
                    name: name,
                    category: cat,
                    pricePaise: price.toInt(),
                    available: item.available,
                  ));
                }
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Menu updated successfully')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error saving menu: $e')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref, MenuItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item?'),
        content: Text('Are you sure you want to delete ${item.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(menuRepositoryProvider).deleteMenuItem(item.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
