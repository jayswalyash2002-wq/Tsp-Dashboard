import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tsp_dashboard/src/auth/data/auth_providers.dart';
import 'package:tsp_dashboard/src/features/rbac/domain/models/business_invite.dart';
import '../providers/staff_providers.dart';

class PendingInvitesScreen extends ConsumerStatefulWidget {
  const PendingInvitesScreen({super.key});

  @override
  ConsumerState<PendingInvitesScreen> createState() => _PendingInvitesScreenState();
}

class _PendingInvitesScreenState extends ConsumerState<PendingInvitesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cleanup();
    });
  }

  void _cleanup() {
    final businessId = ref.read(userBusinessIdProvider);
    if (businessId != null) {
      ref.read(inviteServiceProvider).cleanupInvites(businessId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessId = ref.watch(userBusinessIdProvider);
    if (businessId == null) return const Scaffold(body: Center(child: Text('No business selected')));

    final invitesAsync = ref.watch(invitesStreamProvider(businessId));

    return Scaffold(
      appBar: AppBar(title: const Text('Invites')),
      body: invitesAsync.when(
        data: (invites) {
          if (invites.isEmpty) {
            return const Center(child: Text('No active invites'));
          }

          final now = DateTime.now();
          final pending = invites.where((i) => !i.isUsed && i.expiresAt.isAfter(now)).toList();
          final inactive = invites.where((i) => i.isUsed || i.expiresAt.isBefore(now)).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (pending.isNotEmpty) ...[
                const _SectionHeader(title: 'Active Invites'),
                ...pending.map((invite) => _InviteCard(invite: invite)),
              ],
              if (inactive.isNotEmpty) ...[
                const SizedBox(height: 24),
                const _SectionHeader(title: 'Used or Expired'),
                ...inactive.map((invite) => _InviteCard(invite: invite, isInactive: true)),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _InviteCard extends ConsumerWidget {
  const _InviteCard({required this.invite, this.isInactive = false});
  final InviteModel invite;
  final bool isInactive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final expiryFormat = DateFormat('MMM dd, hh:mm a');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invite.staffName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        invite.role.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isInactive)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _confirmRevoke(context, ref),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: invite.isUsed ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      invite.isUsed ? 'USED' : 'EXPIRED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: invite.isUsed ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Code', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(
                      invite.code,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Expires', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(
                      expiryFormat.format(invite.expiresAt),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRevoke(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revoke Invite?'),
        content: const Text('This will permanently delete the invite and the code will no longer work.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                await ref.read(inviteServiceProvider).revokeInvite(invite.businessId, invite.id!);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error revoking invite: $e')),
                  );
                }
              }
            },
            child: const Text('Revoke', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
