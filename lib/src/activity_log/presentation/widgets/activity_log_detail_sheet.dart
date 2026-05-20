import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/activity_log_entry.dart';
import 'activity_log_helper.dart';

class ActivityLogDetailSheet extends StatelessWidget {
  final ActivityLogEntry entry;

  const ActivityLogDetailSheet({super.key, required this.entry});

  static void show(BuildContext context, ActivityLogEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ActivityLogDetailSheet(entry: entry),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: entry.categoryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(entry.categoryIcon, color: entry.categoryColor, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.humanReadableAction,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          entry.category.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12, 
                            letterSpacing: 1.2,
                            color: entry.categoryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _buildSection(
                title: 'PERFORMED BY',
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: cs.primaryContainer,
                      child: Text(
                        entry.performedByName[0].toUpperCase(),
                        style: TextStyle(color: cs.onPrimaryContainer, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.performedByName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${entry.performedByRole} • UID: ${entry.performedBy}',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: 'TIMESTAMP',
                child: Text(
                  entry.timestamp != null 
                    ? DateFormat('dd MMM yyyy, hh:mm:ss a').format(entry.timestamp!)
                    : 'Pending server timestamp...',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              if (entry.targetId != null) ...[
                const SizedBox(height: 24),
                _buildSection(
                  title: 'TARGET',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Type: ${entry.targetType ?? 'N/A'}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Name: ${entry.targetName ?? 'N/A'}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'ID: ${entry.targetId}',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
              if (entry.metadata.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildSection(
                  title: 'METADATA',
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Column(
                      children: entry.metadata.entries.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(e.key, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
                            Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _InfoItem(label: 'PLATFORM', value: entry.platform.toUpperCase()),
                  _InfoItem(label: 'APP VERSION', value: entry.appVersion),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _InfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
