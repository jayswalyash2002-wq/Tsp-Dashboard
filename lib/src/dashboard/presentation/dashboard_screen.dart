import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_providers.dart';
import '../../core/firebase/firebase_providers.dart';
import '../application/order_controller.dart';
import '../data/dashboard_providers.dart';
import '../domain/menu_item.dart';
import '../domain/order_models.dart';
import 'widgets/sticky_cart_bar.dart';

import '../../memberships/data/membership_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final session = ref.watch(sessionProvider);
    final user = ref.watch(firebaseAuthProvider).currentUser;
    
    String userName = 'User';
    
    profileAsync.whenData((profile) {
      if (profile != null) {
        final roleName = session.role?.name.toUpperCase() ?? profile.role.name;
        userName = '${profile.displayName} ($roleName)';
        
        if (session.isLoaded && session.role != null) {
          debugPrint('DASHBOARD: Displaying role ${session.role!.name} for user ${profile.displayName}');
        }
      }
    });

    if (userName == 'User') {
      userName = user?.displayName ?? user?.email?.split('@')[0] ?? 'User';
    }

    final menu = ref.watch(menuItemsProvider);
    final orderState = ref.watch(orderControllerProvider);
    final draft = orderState.draft;
    final isCancelled = orderState.originalOrder?.isCancelled ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(orderState.isEditing
            ? (isCancelled ? 'View Cancelled Order' : 'Edit Order')
            : 'TSP Dashboard'),
        actions: [
          if (orderState.isEditing)
            TextButton(
              onPressed: () => ref.read(orderControllerProvider.notifier).clear(),
              child: Text(isCancelled ? 'Close' : 'Cancel Edit',
                  style: const TextStyle(color: Colors.red)),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                userName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: menu.when(
                    data: (items) {
                      final visible = items.where((i) => i.available).toList();
                      if (visible.isEmpty) {
                        return const Center(
                          child: Text('No available menu items'),
                        );
                      }

                      // 1. Group menu items by category.
                      final grouped = <String, List<MenuItem>>{};
                      for (final item in visible) {
                        // 5. If category is null or empty, fallback to "Uncategorized"
                        final cat = item.category.trim().isEmpty ? 'Uncategorized' : item.category;
                        grouped.putIfAbsent(cat, () => []).add(item);
                      }

                      // 4. Items inside each category must render using item sortOrder.
                      for (final list in grouped.values) {
                        list.sort((a, b) {
                          final res = a.sortOrder.compareTo(b.sortOrder);
                          if (res != 0) return res;
                          return a.name.compareTo(b.name);
                        });
                      }

                      // 3. Categories must render using categorySortOrder.
                      final sortedCategories = grouped.keys.toList()
                        ..sort((a, b) {
                          final orderA = grouped[a]?.firstOrNull?.categorySortOrder ?? 0;
                          final orderB = grouped[b]?.firstOrNull?.categorySortOrder ?? 0;
                          final res = orderA.compareTo(orderB);
                          if (res != 0) return res;
                          return a.compareTo(b);
                        });

                      // 9. Restore the grouped CustomScrollView + Sliver structure.
                      return CustomScrollView(
                        slivers: [
                          for (final category in sortedCategories) ...[
                            // 2. Each category must render: category title/header + spacing above and below
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
                                child: Text(
                                  category,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                            ),
                            // 7. Keep the existing 2-column grid layout.
                            SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.25,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final item = grouped[category]![index];
                                  return _MenuCard(
                                    item: item,
                                    qtyInOrder: draft.lineFor(item.id)?.qty ?? 0,
                                    onTap: isCancelled
                                        ? () {} // Read-only
                                        : () => ref.read(orderControllerProvider.notifier).add(item),
                                  );
                                },
                                childCount: grouped[category]!.length,
                              ),
                            ),
                          ],
                          const SliverToBoxAdapter(child: SizedBox(height: 20)),
                        ],
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Menu error: $e')),
                  ),
                ),
              ),
              // space for sticky cart height when visible
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: draft.lines.isNotEmpty ? 64 : 0,
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: const StickyCartBar(),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.item,
    required this.onTap,
    required this.qtyInOrder,
  });

  final MenuItem item;
  final VoidCallback onTap;
  final int qtyInOrder;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (qtyInOrder > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'x$qtyInOrder',
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                item.category,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Rs. ${(item.pricePaise / 100).toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
