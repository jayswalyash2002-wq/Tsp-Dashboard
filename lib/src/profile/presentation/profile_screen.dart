import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../auth/data/auth_providers.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/utils/business_date_utils.dart';
import '../../dashboard/data/dashboard_providers.dart';
import '../../business/data/business_providers.dart';
import '../../memberships/data/membership_providers.dart';
import '../../core/rbac/permission.dart';
import '../../core/rbac/permission_gate.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateChangesProvider).value;
    final profile = ref.watch(userProfileProvider).value;
    final deviceName = ref.watch(deviceNameProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // User Header
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        _getAvatarLetter(profile?.displayName, user?.email),
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profile?.displayName ?? 'User',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      user?.email ?? 'No email',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const _BusinessIdentityCard(),
            const SizedBox(height: 24),
            const _BusinessStatusCard(),
            const SizedBox(height: 24),
            PermissionGate(
              permission: Permission.accessSettings,
              child: Column(
                children: [
                  _Tile(
                    title: 'Edit menu',
                    subtitle: 'Add, edit, disable items',
                    onTap: () => context.push('/edit-menu'),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            PermissionGate(
              permission: Permission.viewReports,
              child: Column(
                children: [
                  _Tile(
                    title: 'Sales reports',
                    subtitle: 'Weekly and monthly sales performance',
                    onTap: () => context.push('/sales-reports'),
                  ),
                  const SizedBox(height: 10),
                  _Tile(
                    title: 'Expense reports',
                    subtitle: 'Monthly expense breakdown',
                    onTap: () => context.push('/expense-reports'),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            PermissionGate(
              permission: Permission.manageStaff,
              child: Column(
                children: [
                  _Tile(
                    title: 'Manage Staff',
                    subtitle: 'Roles, access, and team members',
                    onTap: () => context.push('/staff'),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            Consumer(
              builder: (context, ref, child) {
                final businessId = ref.watch(userBusinessIdProvider);
                if (businessId == null) return const SizedBox.shrink();
                return Column(
                  children: [
                    _Tile(
                      title: 'Data Migration',
                      subtitle: 'Fix missing business data from old app version',
                      onTap: () => _runMigration(context, ref, businessId),
                    ),
                    const SizedBox(height: 10),
                  ],
                );
              },
            ),
            _Tile(
              title: 'Device settings',
              subtitle: 'Device: ${deviceName ?? "Not set"}',
              onTap: () {},
            ),
            const SizedBox(height: 10),
            Consumer(
              builder: (context, ref, child) {
                final session = ref.watch(sessionProvider);
                return _Tile(
                  title: 'Account info',
                  subtitle: 'Role: ${session.role?.name.toUpperCase() ?? "Loading..."}',
                  onTap: () {},
                );
              },
            ),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: () async {
                final repo = await ref.read(authRepositoryProvider.future);
                await repo.signOut();
                // Clear local device name state on logout
                ref.read(deviceNameProvider.notifier).state = null;
                if (context.mounted) context.go('/auth');
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }

  String _getAvatarLetter(String? displayName, String? email) {
    if (displayName != null && displayName.trim().isNotEmpty) {
      return displayName.trim()[0].toUpperCase();
    }
    if (email != null && email.trim().isNotEmpty) {
      return email.trim()[0].toUpperCase();
    }
    return '?';
  }

  Future<void> _runMigration(BuildContext context, WidgetRef ref, String businessId) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Run Data Migration?'),
        content: const Text(
          'This will scan your records and link them to this business. '
          'Only run this if you are missing orders or menu items from the previous version.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Run Migration')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repo = ref.read(dataMigrationRepositoryProvider);
      final count = await repo.migrateLegacyData(businessId);
      
      messenger.showSnackBar(
        SnackBar(content: Text('Migration complete! Fixed $count records.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Migration failed: $e')),
      );
    }
  }
}

class _BusinessIdentityCard extends ConsumerWidget {
  const _BusinessIdentityCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessAsync = ref.watch(currentBusinessProvider);
    final cs = Theme.of(context).colorScheme;

    return businessAsync.when(
      data: (business) {
        if (business == null) return const SizedBox.shrink();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (business.logoUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundImage: NetworkImage(business.logoUrl!),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            business.businessName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            business.businessType,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                                const Divider(height: 24),
                _InfoRow(label: 'UIN', value: business.uin),
                _InfoRow(label: 'Email', value: business.officialEmail, isVertical: true),
                _InfoRow(label: 'Phone', value: business.phoneNumber),
                if (business.address != null)
                  _InfoRow(label: 'Address', value: business.address!, isVertical: true),
                if (business.isGstRegistered)
                  _InfoRow(label: 'GSTIN', value: business.gstNumber!, isVertical: true),
                const SizedBox(height: 16),
                PermissionGate(
                  permission: Permission.accessSettings,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/business-setup'),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit Business Details'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
    );
  }
}

class _BusinessStatusCard extends ConsumerWidget {
  const _BusinessStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(currentSessionProvider);
    final cs = Theme.of(context).colorScheme;

    return sessionAsync.when(
      data: (session) {
        final isOpen = session?.isOpen ?? false;
        final businessDate = session?.businessDate ??
            BusinessDateUtils.formatBusinessDate(DateTime.now());

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isOpen ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isOpen ? 'Business Open' : 'Business Closed',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      businessDate,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (session != null) ...[
                  if (session.openedAt != null)
                    _InfoRow(
                      label: 'Opened at',
                      value: DateFormat('hh:mm a').format(session.openedAt!),
                    ),
                  if (session.closedAt != null && !isOpen)
                    _InfoRow(
                      label: 'Closed at',
                      value: DateFormat('hh:mm a').format(session.closedAt!),
                    ),
                  const SizedBox(height: 16),
                ],
                if (isOpen)
                  FilledButton.icon(
                    onPressed: () => _showCloseConfirm(context, ref),
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('CLOSE BUSINESS'),
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.error,
                      foregroundColor: cs.onError,
                    ),
                  )
                else
                  FilledButton.icon(
                    onPressed: () => _openBusiness(context, ref),
                    icon: const Icon(Icons.lock_open),
                    label: const Text('OPEN BUSINESS'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Session error: $e'),
    );
  }

  Future<void> _openBusiness(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final businessDate = BusinessDateUtils.formatBusinessDate(now);
    final repo = ref.read(sessionRepositoryProvider);
    if (repo == null) return;
    await repo.openBusiness(businessDate);
  }

  void _showCloseConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Business?'),
        content: const Text('This will end the current business session.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final repo = ref.read(sessionRepositoryProvider);
              if (repo != null) {
                repo.closeBusiness();
              }
              Navigator.pop(context);
            },
            child: const Text('Close', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.isVertical = false});
  final String label;
  final String value;
  final bool isVertical;

  @override
  Widget build(BuildContext context) {
    if (isVertical) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.bodySmall,
              softWrap: true,
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.7),
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurface.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}
