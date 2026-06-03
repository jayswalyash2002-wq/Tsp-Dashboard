import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/rbac/permission.dart';
import '../../core/rbac/permission_gate.dart';
import '../data/business_providers.dart';
import '../../inventory/data/inventory_providers.dart';

class BusinessSettingsScreen extends ConsumerWidget {
  const BusinessSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessAsync = ref.watch(currentBusinessProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Settings'),
      ),
      body: businessAsync.when(
        data: (business) {
          if (business == null) return const Center(child: Text('No business found'));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SettingTile(
                title: 'Business Information',
                subtitle: 'Update address, contact, and GST info',
                icon: Icons.business,
                onTap: () => context.push('/business-setup?id=${business.id}'),
              ),
              const SizedBox(height: 12),
              PermissionGate(
                permission: Permission.manageStaff,
                child: _SettingTile(
                  title: 'Members & Roles',
                  subtitle: 'Manage roles, access, and team members',
                  icon: Icons.people_alt_outlined,
                  onTap: () => context.push('/staff'),
                ),
              ),
              const SizedBox(height: 12),
              PermissionGate(
                permission: Permission.manageInventory,
                child: Consumer(
                  builder: (context, ref, child) {
                    final hasLowStock = ref.watch(hasLowStockProvider);
                    return _SettingTile(
                      title: 'Inventory Settings',
                      subtitle: 'Units, categories, and stock alerts',
                      icon: Icons.inventory_2_outlined,
                      onTap: () => context.push('/inventory'),
                      trailing: hasLowStock
                          ? const Badge(backgroundColor: Colors.red)
                          : null,
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              PermissionGate(
                permission: Permission.accessSettings,
                child: _SettingTile(
                  title: 'Month Closing',
                  subtitle: 'Financial settlement and book locking',
                  icon: Icons.account_balance_wallet_outlined,
                  onTap: () => context.push('/month-closing'),
                ),
              ),
              const SizedBox(height: 12),
              PermissionGate(
                permission: Permission.viewActivityLog,
                child: _SettingTile(
                  title: 'Activity Logs',
                  subtitle: 'Audit trail of all business actions',
                  icon: Icons.history_edu_outlined,
                  onTap: () => context.push('/activity-log'),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? trailing;

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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: cs.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
              if (trailing != null) ...[
                trailing!,
                const SizedBox(width: 8),
              ],
              Icon(Icons.chevron_right, color: cs.onSurface.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

