import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/data/auth_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Tile(
              title: 'Edit menu',
              subtitle: 'Add, edit, disable items',
              onTap: () => context.push('/edit-menu'),
            ),
            const SizedBox(height: 10),
            _Tile(
              title: 'Reports',
              subtitle: 'Weekly email report automation',
              onTap: () {},
            ),
            const SizedBox(height: 10),
            _Tile(
              title: 'Device settings',
              subtitle: 'Device name and notifications',
              onTap: () {},
            ),
            const SizedBox(height: 10),
            _Tile(
              title: 'Account info',
              subtitle: 'Signed in user details',
              onTap: () {},
            ),
            const SizedBox(height: 14),
            FilledButton.tonal(
              onPressed: () async {
                final repo = await ref.read(authRepositoryProvider.future);
                await repo.signOut();
                // Clear local device name state on logout
                ref.read(deviceNameProvider.notifier).state = null;
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
