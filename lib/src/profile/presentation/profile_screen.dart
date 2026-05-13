import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/data/auth_providers.dart';
import '../../core/firebase/firebase_providers.dart';

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
                        (profile?['displayName'] ?? user?.email ?? '?')[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profile?['displayName'] ?? 'User',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      user?.email ?? 'No email',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _Tile(
              title: 'Edit menu',
              subtitle: 'Add, edit, disable items',
              onTap: () => context.push('/edit-menu'),
            ),
            const SizedBox(height: 10),
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
            _Tile(
              title: 'Device settings',
              subtitle: 'Device: ${deviceName ?? "Not set"}',
              onTap: () {},
            ),
            const SizedBox(height: 10),
            _Tile(
              title: 'Account info',
              subtitle: 'Created: ${profile?['createdAt'] != null ? (profile!['createdAt'] as Timestamp).toDate().toString().split(' ')[0] : "Recently"}',
              onTap: () {},
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
