import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../sync/sync_models.dart';
import '../sync/sync_service.dart';

class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    final cs = Theme.of(context).colorScheme;

    IconData icon;
    Color color;
    String tooltip;

    switch (status) {
      case SyncStatus.synced:
        icon = Icons.cloud_done_outlined;
        color = Colors.green;
        tooltip = 'All records synced';
        break;
      case SyncStatus.pending:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case SyncStatus.offline:
        icon = Icons.cloud_off_outlined;
        color = Colors.orange;
        tooltip = 'Offline - changes saved locally';
        break;
      case SyncStatus.failed:
        icon = Icons.cloud_off_outlined;
        color = cs.error;
        tooltip = 'Sync failed - retrying later';
        break;
    }

    return Tooltip(
      message: tooltip,
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class PendingSyncBadge extends StatelessWidget {
  const PendingSyncBadge({super.key, required this.isSynced});
  final bool isSynced;

  @override
  Widget build(BuildContext context) {
    if (isSynced) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sync, size: 10, color: Colors.orange),
          SizedBox(width: 4),
          Text(
            'PENDING SYNC',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}
