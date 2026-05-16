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
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Menu is empty. Add items above.'));
          }

          // 1. Group menu items by category.
          final grouped = <String, List<MenuItem>>{};
          for (final item in items) {
            final cat =
                item.category.trim().isEmpty ? 'Uncategorized' : item.category;
            grouped.putIfAbsent(cat, () => []).add(item);
          }

          // 2. Sort items within categories by sortOrder.
          for (final list in grouped.values) {
            list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          }

          // 3. Sort categories by their first item's categorySortOrder.
          final sortedCategories = grouped.keys.toList()
            ..sort((a, b) {
              final orderA = grouped[a]!.first.categorySortOrder;
              final orderB = grouped[b]!.first.categorySortOrder;
              return orderA.compareTo(orderB);
            });

          // 4. Flatten the structure for ReorderableListView.
          final flattened = <dynamic>[];
          for (final cat in sortedCategories) {
            flattened.add(cat);
            flattened.addAll(grouped[cat]!);
          }

          return ReorderableListView.builder(
            itemCount: flattened.length,
            buildDefaultDragHandles: false,
            onReorder: (oldIndex, newIndex) =>
                _onReorder(ref, flattened, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final item = flattened[index];

              if (item is String) {
                return Container(
                  key: ValueKey('cat_$item'),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: ListTile(
                    title: Text(
                      item,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    trailing: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle),
                    ),
                  ),
                );
              }

              final menuItem = item as MenuItem;
              return ListTile(
                key: ValueKey(menuItem.id),
                leading: ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_handle),
                ),
                title: Text(menuItem.name),
                subtitle: Text(
                    'Rs. ${(menuItem.pricePaise / 100).toStringAsFixed(0)}'),
                trailing: Switch(
                  value: menuItem.available,
                  onChanged: (val) {
                    ref.read(menuRepositoryProvider).updateMenuItem(MenuItem(
                          id: menuItem.id,
                          name: menuItem.name,
                          pricePaise: menuItem.pricePaise,
                          category: menuItem.category,
                          available: val,
                          sortOrder: menuItem.sortOrder,
                          categorySortOrder: menuItem.categorySortOrder,
                        ));
                  },
                ),
                onTap: () => _showEditDialog(context, ref, item: menuItem),
                onLongPress: () => _showDeleteConfirm(context, ref, menuItem),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _onReorder(
      WidgetRef ref, List<dynamic> list, int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final item = list.removeAt(oldIndex);

    // If we are moving a category, we must also move all items in that category.
    if (item is String) {
      final itemsToMove = <MenuItem>[];
      // Collect items that were immediately after the category header
      while (oldIndex < list.length && list[oldIndex] is MenuItem) {
        itemsToMove.add(list.removeAt(oldIndex) as MenuItem);
      }

      // Ensure newIndex is still valid after removals
      final targetIndex = newIndex.clamp(0, list.length);
      list.insert(targetIndex, item);
      list.insertAll(targetIndex + 1, itemsToMove);
    } else {
      list.insert(newIndex, item);
    }

    // Now re-calculate all sort orders and update Firestore.
    final repo = ref.read(menuRepositoryProvider);
    String currentCategory = 'Uncategorized';
    int catOrder = 0;
    int itemOrder = 0;

    for (final element in list) {
      if (element is String) {
        currentCategory = element;
        catOrder++;
        itemOrder = 0;
      } else if (element is MenuItem) {
        final updatedItem = MenuItem(
          id: element.id,
          name: element.name,
          pricePaise: element.pricePaise,
          category: currentCategory,
          available: element.available,
          sortOrder: itemOrder++,
          categorySortOrder: catOrder,
        );
        // Only update if something changed to save writes
        if (updatedItem.sortOrder != element.sortOrder ||
            updatedItem.categorySortOrder != element.categorySortOrder ||
            updatedItem.category != element.category) {
          await repo.updateMenuItem(updatedItem);
        }
      }
    }
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
              decoration: const InputDecoration(labelText: 'Price (Rs.)'),
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
                    sortOrder: 999, // Will be updated by drag and drop
                  ));
                } else {
                  await repo.updateMenuItem(MenuItem(
                    id: item.id,
                    name: name,
                    category: cat,
                    pricePaise: price.toInt(),
                    available: item.available,
                    sortOrder: item.sortOrder,
                    categorySortOrder: item.categorySortOrder,
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
