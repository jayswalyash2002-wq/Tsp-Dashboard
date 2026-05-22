import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/activity_log_enums.dart';
import '../providers/activity_log_providers.dart';
import '../widgets/activity_log_entry_tile.dart';
import '../utils/activity_log_export_service.dart';
import '../../../business/data/business_providers.dart';

class ActivityLogScreen extends ConsumerStatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  ConsumerState<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends ConsumerState<ActivityLogScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isExporting = false;

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

  Future<void> _handleExport(Future<void> Function() exportFn) async {
    final state = ref.read(activityLogNotifierProvider).value;
    if (state == null || state.entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No logs available to export')),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      await exportFn();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportPdf() async {
    await _handleExport(() async {
      final entries = ref.read(activityLogNotifierProvider).value?.entries ?? [];
      final business = ref.read(currentBusinessProvider).value;
      await ActivityLogExportService.exportToPdf(
        entries: entries,
        business: business,
      );
    });
  }

  Future<void> _exportCsv() async {
    await _handleExport(() async {
      final entries = ref.read(activityLogNotifierProvider).value?.entries ?? [];
      await ActivityLogExportService.exportToCsv(entries: entries);
    });
  }

  Future<void> _exportXlsx() async {
    await _handleExport(() async {
      final entries = ref.read(activityLogNotifierProvider).value?.entries ?? [];
      await ActivityLogExportService.exportToXlsx(entries: entries);
    });
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(activityLogNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Log'),
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.download),
              tooltip: 'Export Logs',
              onSelected: (value) {
                switch (value) {
                  case 'pdf':
                    _exportPdf();
                    break;
                  case 'csv':
                    _exportCsv();
                    break;
                  case 'xlsx':
                    _exportXlsx();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'pdf',
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf, size: 20),
                      SizedBox(width: 12),
                      Text('Export as PDF'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'csv',
                  child: Row(
                    children: [
                      Icon(Icons.description, size: 20),
                      SizedBox(width: 12),
                      Text('Export as CSV'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'xlsx',
                  child: Row(
                    children: [
                      Icon(Icons.table_chart, size: 20),
                      SizedBox(width: 12),
                      Text('Export as XLSX'),
                    ],
                  ),
                ),
              ],
            ),
        ],
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
