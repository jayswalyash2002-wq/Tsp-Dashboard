import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/activity_log_enums.dart';
import '../providers/activity_log_providers.dart';
import '../widgets/activity_log_entry_tile.dart';

class ActivityLogScreen extends ConsumerStatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  ConsumerState<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends ConsumerState<ActivityLogScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(activityLogNotifierProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(activityLogNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Log'),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: stateAsync.when(
              data: (state) => _buildList(state),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: $err'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.read(activityLogNotifierProvider.notifier).refresh(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final activeCategory = ref.watch(activityLogNotifierProvider).value?.activeCategory;

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _FilterChip(
            label: 'All',
            isSelected: activeCategory == null,
            onSelected: () => ref.read(activityLogNotifierProvider.notifier).filterByCategory(null),
          ),
          ...ActivityCategory.values.map((category) => _FilterChip(
                label: category.name[0].toUpperCase() + category.name.substring(1),
                isSelected: activeCategory == category,
                onSelected: () => ref.read(activityLogNotifierProvider.notifier).filterByCategory(category),
              )),
        ],
      ),
    );
  }

  Widget _buildList(ActivityLogState state) {
    if (state.entries.isEmpty && !state.isLoading) {
      return const Center(child: Text('No activity recorded yet'));
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(activityLogNotifierProvider.notifier).refresh(),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.entries.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          if (index == state.entries.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return ActivityLogEntryTile(entry: state.entries[index]);
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: isSelected,
        onSelected: (_) => onSelected(),
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
