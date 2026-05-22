import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tsp_dashboard/src/constants/roles.dart';
import 'package:tsp_dashboard/src/features/rbac/domain/models/business_invite.dart';
import 'package:tsp_dashboard/src/features/staff/providers/staff_providers.dart';
import '../data/auth_providers.dart';
import '../domain/app_user.dart';

class StaffManagementScreen extends ConsumerStatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  ConsumerState<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends ConsumerState<StaffManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final businessId = ref.watch(userBusinessIdProvider);
    if (businessId == null) return const Scaffold(body: Center(child: Text('No business selected')));

    final staffAsync = ref.watch(staffListProvider);
    final invitesAsync = ref.watch(invitesStreamProvider(businessId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active Staff'),
            Tab(text: 'Pending Invites'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildOverview(staffAsync, invitesAsync),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ActiveStaffTab(staffAsync: staffAsync),
                _PendingInvitesTab(invitesAsync: invitesAsync),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/staff/add'),
        label: const Text('Add Staff'),
        icon: const Icon(Icons.person_add_alt_1),
      ),
    );
  }

  Widget _buildOverview(AsyncValue<List<AppUser>> staffAsync, AsyncValue<List<InviteModel>> invitesAsync) {
    final now = DateTime.now();
    final activeCount = staffAsync.value?.length ?? 0;
    final pendingCount = invitesAsync.value?.where((i) => !i.isUsed && i.expiresAt.isAfter(now)).length ?? 0;
    final expiredCount = invitesAsync.value?.where((i) => !i.isUsed && i.expiresAt.isBefore(now)).length ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: _StatCard(label: 'Active', count: activeCount, color: Colors.green)),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(label: 'Pending', count: pendingCount, color: Colors.amber)),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(label: 'Expired', count: expiredCount, color: Colors.red)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.count, required this.color});
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count.toString(),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}

class _ActiveStaffTab extends StatelessWidget {
  const _ActiveStaffTab({required this.staffAsync});
  final AsyncValue<List<AppUser>> staffAsync;

  @override
  Widget build(BuildContext context) {
    return staffAsync.when(
      data: (staffList) {
        if (staffList.isEmpty) {
          return _EmptyState(
            icon: Icons.people_outline,
            message: 'No staff members yet.\nInvite your team to collaborate.',
            actionLabel: 'Add Staff',
            onAction: () => context.push('/staff/add'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: staffList.length,
          itemBuilder: (context, index) {
            final staff = staffList[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(staff.displayName[0].toUpperCase()),
                ),
                title: Text(staff.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(staff.roleType.name.toUpperCase()),
                trailing: const _StatusBadge(label: 'Active', color: Colors.green),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _PendingInvitesTab extends ConsumerWidget {
  const _PendingInvitesTab({required this.invitesAsync});
  final AsyncValue<List<InviteModel>> invitesAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return invitesAsync.when(
      data: (invites) {
        final now = DateTime.now();
        final displayInvites = invites.toList();

        if (displayInvites.isEmpty) {
          return const _EmptyState(
            icon: Icons.mail_outline,
            message: 'No pending invites.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: displayInvites.length,
          itemBuilder: (context, index) {
            final invite = displayInvites[index];
            final isExpired = invite.expiresAt.isBefore(now) && !invite.isUsed;
            final statusLabel = invite.isUsed ? 'Accepted' : (isExpired ? 'Expired' : 'Pending');
            final statusColor = invite.isUsed ? Colors.green : (isExpired ? Colors.red : Colors.amber);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showInviteDetails(context, ref, invite),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(invite.staffName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                Text(invite.role.name.toUpperCase(), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          _StatusBadge(label: statusLabel, color: statusColor),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Code', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              Text(invite.code, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                            ],
                          ),
                          if (!invite.isUsed && !isExpired)
                            Text(
                              _formatCountdown(invite.expiresAt),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  String _formatCountdown(DateTime expiresAt) {
    final now = DateTime.now();
    final diff = expiresAt.difference(now);
    if (diff.isNegative) return 'Expired';
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    return 'Expires in ${hours}h ${minutes}m';
  }

  void _showInviteDetails(BuildContext context, WidgetRef ref, InviteModel invite) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _InviteDetailSheet(invite: invite),
    );
  }
}

class _InviteDetailSheet extends ConsumerWidget {
  const _InviteDetailSheet({required this.invite});
  final InviteModel invite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final isExpired = invite.expiresAt.isBefore(now) && !invite.isUsed;
    final dateFormat = DateFormat('MMM dd, yyyy hh:mm a');

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Invite Details', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 24),
          _DetailRow(label: 'Staff Name', value: invite.staffName),
          _DetailRow(label: 'Role', value: invite.role.name.toUpperCase()),
          _DetailRow(label: 'Invite Code', value: invite.code, isMonospace: true),
          _DetailRow(label: 'Created At', value: dateFormat.format(invite.createdAt)),
          _DetailRow(label: 'Expires At', value: dateFormat.format(invite.expiresAt)),
          _DetailRow(
            label: 'Status',
            value: invite.isUsed ? 'ACCEPTED' : (isExpired ? 'EXPIRED' : 'PENDING'),
            valueColor: invite.isUsed ? Colors.green : (isExpired ? Colors.red : Colors.amber),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: invite.code));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Share.share('Join our team at TSP Dashboard!\nCode: ${invite.code}');
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _showQrDialog(context, invite),
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Generate QR'),
                ),
              ),
              const SizedBox(width: 12),
              if (!invite.isUsed)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _confirmRevoke(context, ref),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Revoke'),
                    style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showQrDialog(BuildContext context, InviteModel invite) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite QR Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: QrImageView(
                data: '{"businessId": "${invite.businessId}", "inviteCode": "${invite.code}"}',
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(invite.code, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _confirmRevoke(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revoke Invite?'),
        content: const Text('This will permanently delete the invite code.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // 1. Immediately close the confirmation dialog
              Navigator.of(dialogContext).pop();

              // 2. Perform the async operation
              try {
                await ref.read(inviteServiceProvider).revokeInvite(invite.businessId, invite.id!);

                // 3. Close the bottom sheet safely after the operation
                if (context.mounted) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  });
                }
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.isMonospace = false, this.valueColor});
  final String label;
  final String value;
  final bool isMonospace;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: isMonospace ? 'monospace' : null,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message, this.actionLabel, this.onAction});
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 32),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
