import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/activity_log_entry.dart';
import 'activity_log_helper.dart';
import 'activity_log_detail_sheet.dart';

class ActivityLogEntryTile extends StatelessWidget {
  final ActivityLogEntry entry;

  const ActivityLogEntryTile({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ListTile(
      onTap: () => ActivityLogDetailSheet.show(context, entry),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: entry.categoryColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(entry.categoryIcon, color: entry.categoryColor, size: 20),
      ),
      title: Text(
        entry.humanReadableAction,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                entry.performedByName,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  entry.performedByRole.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9, 
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: Text(
        _formatTimestamp(entry.timestamp),
        style: TextStyle(
          fontSize: 11, 
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) {
      if (now.day == timestamp.day) {
        return DateFormat('hh:mm a').format(timestamp);
      }
      return 'Yesterday';
    }
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    
    return DateFormat('dd MMM').format(timestamp);
  }
}
