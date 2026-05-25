import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/dashboard_providers.dart';
import '../domain/menu_item.dart';
import '../../activity_log/presentation/providers/activity_log_providers.dart';
import '../../activity_log/domain/entities/activity_log_enums.dart';
import '../../inventory/data/inventory_providers.dart';
import '../../inventory/domain/inventory_item.dart';

// Provider to track which categories are expanded in the menu editor
final expandedCategoriesProvider = StateProvider<Set<String>>((ref) => <String>{});

class EditMenuScreen extends ConsumerWidget {
  const EditMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(menuItemsProvider);
    final expandedCategories = ref.watch(expandedCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Management'),
        actions: [
          // Global button ONLY for creating new categories
          TextButton.icon(
            onPressed: () => _showAddCategoryDialog(context, ref),
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('Add Category'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: menuAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Your menu is empty.'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddCategoryDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Create First Category'),
                  ),
                ],
              ),
            );
          }

          // 1. Group menu items by category.
          final grouped = <String, List<MenuItem>>{};
          for (final item in items) {
            final cat = item.category.trim().isEmpty ? 'Uncategorized' : item.category;
            grouped.putIfAbsent(cat, () => []).add(item);
          }

          // 2. Map to CategoryModel and sort.
          final categories = grouped.entries.map((e) {
            final catItems = e.value..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
            return CategoryModel(
              id: e.key,
              name: e.key,
              orderIndex: catItems.firstOrNull?.categorySortOrder ?? 0,
              items: catItems,
            );
          }).toList()
            ..sort((a, b) {
              if (a.orderIndex != b.orderIndex) return a.orderIndex.compareTo(b.orderIndex);
              return a.name.compareTo(b.name);
            });

          return ReorderableListView.builder(
            itemCount: categories.length,
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.only(bottom: 80),
            onReorder: (oldIndex, newIndex) => _onCategoryReorder(ref, categories, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final category = categories[index];
              final isExpanded = expandedCategories.contains(category.name);

              return Column(
                key: ValueKey('category_wrapper_${category.id}'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CategoryHeader(
                    name: category.name,
                    isExpanded: isExpanded,
                    index: index,
                    onToggle: () {
                      final current = ref.read(expandedCategoriesProvider);
                      if (isExpanded) {
                        ref.read(expandedCategoriesProvider.notifier).state =
                            current.where((c) => c != category.name).toSet();
                      } else {
                        ref.read(expandedCategoriesProvider.notifier).state = {...current, category.name};
                      }
                    },
                    onAddItem: () => _showEditDialog(context, ref, initialCategory: category.name),
                    onDelete: () => _showDeleteCategoryConfirm(context, ref, category.name, category.items),
                  ),
                  Visibility(
                    visible: isExpanded,
                    maintainState: true,
                    child: ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: category.items.length,
                      buildDefaultDragHandles: false,
                      onReorder: (oldItemIndex, newItemIndex) =>
                          _onItemReorder(ref, category, oldItemIndex, newItemIndex),
                      itemBuilder: (context, itemIndex) {
                        final menuItem = category.items[itemIndex];
                        return _MenuItemTile(
                          key: ValueKey('menu_item_${menuItem.id}'),
                          item: menuItem,
                          index: itemIndex,
                          onTap: () => _showEditDialog(context, ref, item: menuItem),
                          onDelete: () => _showDeleteConfirm(context, ref, menuItem),
                          onStatusChange: (val) => _updateItemStatus(ref, menuItem, val),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _updateItemStatus(WidgetRef ref, MenuItem item, bool val) {
    final repo = ref.read(menuRepositoryProvider);
    if (repo == null) return;
    repo.updateMenuItem(item.copyWith(available: val));

    unawaited(
      ref.read(logActivityUseCaseProvider).execute(
            action: ActivityAction.menuItemModified,
            category: ActivityCategory.operational,
            targetType: 'menuItem',
            targetId: item.id,
            targetName: item.name,
            metadata: {'available': val},
          ),
    );
  }

  Future<void> _onCategoryReorder(
    WidgetRef ref,
    List<CategoryModel> categories,
    int oldIndex,
    int newIndex,
  ) async {
    final repo = ref.read(menuRepositoryProvider);
    if (repo == null) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final category = categories.removeAt(oldIndex);
    categories.insert(newIndex, category);

    // Persist updated categorySortOrder for all items in all categories.
    // Use parallel updates to improve performance and consistency.
    final List<Future<void>> updates = [];
    for (int i = 0; i < categories.length; i++) {
      final cat = categories[i];
      for (final item in cat.items) {
        final updated = item.copyWith(categorySortOrder: i);
        if (updated.categorySortOrder != item.categorySortOrder) {
          updates.add(repo.updateMenuItem(updated));
        }
      }
    }
    await Future.wait(updates);
  }

  Future<void> _onItemReorder(
    WidgetRef ref,
    CategoryModel category,
    int oldIndex,
    int newIndex,
  ) async {
    final repo = ref.read(menuRepositoryProvider);
    if (repo == null) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final items = List<MenuItem>.from(category.items);
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);

    // Update sortOrder for items in this category.
    final List<Future<void>> updates = [];
    for (int i = 0; i < items.length; i++) {
      final updated = items[i].copyWith(sortOrder: i);
      if (updated.sortOrder != items[i].sortOrder) {
        updates.add(repo.updateMenuItem(updated));
      }
    }
    await Future.wait(updates);
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g. Beverages, Mains, Desserts',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              // After submitting category name, immediately open Add Item for that category
              _showEditDialog(context, ref, initialCategory: name);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, {MenuItem? item, String? initialCategory}) {
    showDialog(
      context: context,
      builder: (context) => _EditMenuItemDialog(item: item, initialCategory: initialCategory),
    );
  }
}

class _EditMenuItemDialog extends ConsumerStatefulWidget {
  const _EditMenuItemDialog({this.item, this.initialCategory});
  final MenuItem? item;
  final String? initialCategory;

  @override
  ConsumerState<_EditMenuItemDialog> createState() => _EditMenuItemDialogState();
}

class _EditMenuItemDialogState extends ConsumerState<_EditMenuItemDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _priceController;
  late Map<String, int> _consumableMappings;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name);
    _categoryController = TextEditingController(text: widget.item?.category ?? widget.initialCategory);
    _priceController =
        TextEditingController(text: widget.item != null ? (widget.item!.pricePaise / 100).toStringAsFixed(0) : '');
    _consumableMappings = Map.from(widget.item?.consumableMappings ?? {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final initialCategory = widget.initialCategory;
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(item == null ? 'Add Item to ${initialCategory ?? "Menu"}' : 'Edit Item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: item == null,
              decoration: const InputDecoration(labelText: 'Item Name'),
              textCapitalization: TextCapitalization.words,
            ),
            if (initialCategory == null)
              TextField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
                textCapitalization: TextCapitalization.words,
              ),
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: 'Price (Rs.)'),
              keyboardType: TextInputType.number,
            ),
            _ConsumableMappingSection(
              initialMappings: _consumableMappings,
              onChanged: (mappings) => _consumableMappings = mappings,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () async {
            final name = _nameController.text.trim();
            final cat = _categoryController.text.trim();
            final price = (double.tryParse(_priceController.text) ?? 0) * 100;

            if (name.isEmpty || cat.isEmpty) return;

            try {
              final repo = ref.read(menuRepositoryProvider);
              if (repo == null) return;
              
              if (item == null) {
                // Determine the correct categorySortOrder and sortOrder for the new item
                final currentItems = ref.read(menuItemsProvider).value ?? [];
                
                // 1. Find if category already exists to inherit its sort order
                int categorySortOrder = 0;
                int maxSortOrder = -1;
                
                final sameCategoryItems = currentItems.where((i) => i.category == cat).toList();
                if (sameCategoryItems.isNotEmpty) {
                  categorySortOrder = sameCategoryItems.first.categorySortOrder;
                  for (final i in sameCategoryItems) {
                    if (i.sortOrder > maxSortOrder) maxSortOrder = i.sortOrder;
                  }
                } else {
                  // New category: find the current max categorySortOrder
                  int maxCatOrder = -1;
                  for (final i in currentItems) {
                    if (i.categorySortOrder > maxCatOrder) maxCatOrder = i.categorySortOrder;
                  }
                  categorySortOrder = maxCatOrder + 1;
                }

                final newItem = MenuItem(
                  id: '',
                  name: name,
                  category: cat,
                  pricePaise: price.toInt(),
                  available: true,
                  sortOrder: maxSortOrder + 1,
                  categorySortOrder: categorySortOrder,
                  consumableMappings: _consumableMappings,
                );
                await repo.addMenuItem(newItem);
                unawaited(
                  ref.read(logActivityUseCaseProvider).execute(
                        action: ActivityAction.menuItemAdded,
                        category: ActivityCategory.operational,
                        targetType: 'menuItem',
                        targetName: name,
                        metadata: {
                          'price': price / 100,
                          'category': cat,
                          'consumables': _consumableMappings,
                        },
                      ),
                );
              } else {
                final updatedItem = MenuItem(
                  id: item.id,
                  name: name,
                  category: cat,
                  pricePaise: price.toInt(),
                  available: item.available,
                  sortOrder: item.sortOrder,
                  categorySortOrder: item.categorySortOrder,
                  consumableMappings: _consumableMappings,
                );
                await repo.updateMenuItem(updatedItem);
                unawaited(
                  ref.read(logActivityUseCaseProvider).execute(
                        action: ActivityAction.menuItemModified,
                        category: ActivityCategory.operational,
                        targetType: 'menuItem',
                        targetId: item.id,
                        targetName: name,
                        metadata: {'consumables': _consumableMappings},
                      ),
                );
              }
              if (!mounted) return;
              Navigator.pop(context);
              // Expand category automatically when adding new item
              final currentExpanded = ref.read(expandedCategoriesProvider);
              ref.read(expandedCategoriesProvider.notifier).state = {...currentExpanded, cat};
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ConsumableMappingSection extends ConsumerStatefulWidget {
  const _ConsumableMappingSection({
    required this.initialMappings,
    required this.onChanged,
  });

  final Map<String, int> initialMappings;
  final ValueChanged<Map<String, int>> onChanged;

  @override
  ConsumerState<_ConsumableMappingSection> createState() => _ConsumableMappingSectionState();
}

class _ConsumableMappingSectionState extends ConsumerState<_ConsumableMappingSection> {
  late Map<String, int> _mappings;

  @override
  void initState() {
    super.initState();
    _mappings = Map.from(widget.initialMappings);
  }

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryStreamProvider);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        Text(
          'CONSUMABLE MAPPING',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
        ),
        const SizedBox(height: 12),
        inventoryAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return Text(
                'No inventory items found. Add items to inventory first to link them to this product.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontStyle: FontStyle.italic),
              );
            }

            return Column(
              children: [
                ..._mappings.entries.map((entry) {
                  final item = items.firstWhere(
                    (i) => i.id == entry.key,
                    orElse: () => InventoryItem(
                      id: entry.key,
                      name: 'Unknown Item',
                      stock: 0,
                      unit: '',
                      lowStockThreshold: 0,
                    ),
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 50,
                          child: TextFormField(
                            initialValue: entry.value.toString(),
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                            ),
                            onChanged: (val) {
                              final qty = int.tryParse(val) ?? 0;
                              if (qty > 0) {
                                _mappings[entry.key] = qty;
                                widget.onChanged(_mappings);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(item.unit, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                        IconButton(
                          icon: Icon(Icons.remove_circle_outline, size: 20, color: cs.error),
                          onPressed: () {
                            setState(() {
                              _mappings.remove(entry.key);
                              widget.onChanged(_mappings);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }),
                if (_mappings.length < items.length)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _showAddItemDialog(context, items),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Consumable Mapping'),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())),
          error: (e, _) => Text('Error loading inventory: $e'),
        ),
      ],
    );
  }

  void _showAddItemDialog(BuildContext context, List<InventoryItem> items) {
    showDialog(
      context: context,
      builder: (context) {
        final available = items.where((i) => !_mappings.containsKey(i.id)).toList();
        return AlertDialog(
          title: const Text('Select Consumable'),
          content: available.isEmpty
              ? const Text('All items already mapped.')
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: available.length,
                    itemBuilder: (context, index) {
                      final item = available[index];
                      return ListTile(
                        title: Text(item.name),
                        trailing: Text(item.unit, style: const TextStyle(fontSize: 12)),
                        onTap: () {
                          setState(() {
                            _mappings[item.id] = 1;
                            widget.onChanged(_mappings);
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ],
        );
      },
    );
  }
}

void _showDeleteCategoryConfirm(BuildContext context, WidgetRef ref, String category, List<MenuItem> items) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete $category?'),
      content: Text(items.isEmpty
          ? 'Are you sure you want to delete this empty category?'
          : 'This will delete the category and all ${items.length} items inside it. This action cannot be easily undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () async {
            final repo = ref.read(menuRepositoryProvider);
            if (repo != null) {
              for (final item in items) {
                await repo.deleteMenuItem(item.id);
              }
            }
            if (context.mounted) Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Category $category deleted')),
            );
          },
          child: const Text('Delete All', style: TextStyle(color: Colors.red)),
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
            final repo = ref.read(menuRepositoryProvider);
            if (repo != null) {
              repo.deleteMenuItem(item.id);
              unawaited(
                ref.read(logActivityUseCaseProvider).execute(
                      action: ActivityAction.menuItemDeleted,
                      category: ActivityCategory.operational,
                      targetType: 'menuItem',
                      targetId: item.id,
                      targetName: item.name,
                    ),
              );
            }
            Navigator.pop(context);
          },
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    super.key,
    required this.name,
    required this.isExpanded,
    required this.onToggle,
    required this.onAddItem,
    required this.onDelete,
    required this.index,
  });

  final String name;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onAddItem;
  final VoidCallback onDelete;
  final int index;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
      ),
      child: ListTile(
        onTap: onToggle,
        leading: Icon(
          isExpanded ? Icons.expand_more : Icons.chevron_right,
          color: cs.primary,
        ),
        title: Text(
          name.toUpperCase(),
          style: TextStyle(fontWeight: FontWeight.w900, color: cs.primary, letterSpacing: 1.1, fontSize: 13),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              onPressed: onAddItem,
              tooltip: 'Add item to $name',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
              onSelected: (val) {
                if (val == 'delete') onDelete();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep_outlined, size: 20, color: cs.error),
                      const SizedBox(width: 12),
                      const Text('Delete Category', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
            ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItemTile extends StatelessWidget {
  const _MenuItemTile({
    super.key,
    required this.item,
    required this.index,
    required this.onTap,
    required this.onDelete,
    required this.onStatusChange,
  });

  final MenuItem item;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<bool> onStatusChange;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 56, right: 8),
      onTap: onTap,
      title: Text(
        item.name,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: item.available ? null : cs.onSurface.withValues(alpha: 0.4),
          decoration: item.available ? null : TextDecoration.lineThrough,
        ),
      ),
      subtitle: Text(
        'Rs. ${(item.pricePaise / 100).toStringAsFixed(0)}',
        style: TextStyle(
          color: item.available ? null : cs.onSurface.withValues(alpha: 0.3),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Availability toggle (Primary Action)
          Transform.scale(
            scale: 0.8,
            child: Switch.adaptive(
              value: item.available,
              onChanged: onStatusChange,
              activeColor: cs.primary,
            ),
          ),
          // Actions Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
            onSelected: (val) {
              if (val == 'delete') onDelete();
              if (val == 'edit') onTap();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Edit Item'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20, color: cs.error),
                    const SizedBox(width: 12),
                    Text('Delete Item', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
