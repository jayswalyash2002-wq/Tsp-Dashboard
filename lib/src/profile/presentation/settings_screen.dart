import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/data/auth_providers.dart';
import '../../business/data/business_providers.dart';
import '../../core/rbac/permission.dart';
import '../../core/rbac/permission_gate.dart';
import '../../core/theme/theme_providers.dart';
import '../../business/application/business_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceName = ref.watch(deviceNameProvider);
    final themeMode = ref.watch(themeModeProvider);
    final accentColor = ref.watch(accentColorProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(title: 'DEVICE'),
          _SettingTile(
            title: 'Device Name',
            subtitle: deviceName ?? 'Not set',
            onTap: () {}, // Preserve existing behavior (empty onTap)
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'APPEARANCE'),
          _ThemeModeTile(currentMode: themeMode),
          const SizedBox(height: 12),
          _AccentColorTile(currentColor: accentColor),
          const SizedBox(height: 24),
          _SectionHeader(title: 'BUSINESS'),
          const _BusinessSettingsSection(),
          const SizedBox(height: 24),
          _SectionHeader(title: 'BUSINESS HOURS'),
          const _BusinessHoursSection(),
        ],
      ),
    );
  }
}

class _BusinessHoursSection extends ConsumerWidget {
  const _BusinessHoursSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessAsync = ref.watch(currentBusinessProvider);
    final service = ref.watch(businessServiceProvider);

    return businessAsync.when(
      data: (business) {
        if (business == null) return const SizedBox.shrink();

        final isOpen = business.businessStatus == 'open';

        return PermissionGate(
          permission: Permission.accessSettings,
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Current Status',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Chip(
                            label: Text(
                              isOpen ? 'OPEN' : 'CLOSED',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                            backgroundColor: isOpen ? Colors.green : Colors.red,
                          ),
                        ],
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: const Text('Manual Override'),
                        subtitle: const Text('Manually control business status'),
                        value: business.manualOverride,
                        onChanged: (val) => service.toggleManualOverride(business, val),
                      ),
                      if (business.manualOverride)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'open',
                                label: Text('OPEN'),
                                icon: Icon(Icons.door_front_door),
                              ),
                              ButtonSegment(
                                value: 'closed',
                                label: Text('CLOSED'),
                                icon: Icon(Icons.lock),
                              ),
                            ],
                            selected: {business.businessStatus},
                            onSelectionChanged: (val) =>
                                service.setBusinessStatus(business, val.first),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Auto Open'),
                      subtitle: Text('Open at ${business.openingTime}'),
                      value: business.autoOpenEnabled,
                      onChanged: (val) {
                        ref.read(businessRepositoryProvider).updateBusiness(
                          business.copyWith(autoOpenEnabled: val),
                        );
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Auto Close'),
                      subtitle: Text('Close at ${business.closingTime}'),
                      value: business.autoCloseEnabled,
                      onChanged: (val) {
                        ref.read(businessRepositoryProvider).updateBusiness(
                          business.copyWith(autoCloseEnabled: val),
                        );
                      },
                    ),
                    const Divider(),
                    ListTile(
                      title: const Text('Opening Time'),
                      trailing: Text(
                        business.openingTime,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      onTap: () async {
                        final parts = business.openingTime.split(':');
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: int.parse(parts[0]),
                            minute: int.parse(parts[1]),
                          ),
                        );
                        if (time != null) {
                          final formatted =
                              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                          ref.read(businessRepositoryProvider).updateBusiness(
                            business.copyWith(openingTime: formatted),
                          );
                        }
                      },
                    ),
                    ListTile(
                      title: const Text('Closing Time'),
                      trailing: Text(
                        business.closingTime,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      onTap: () async {
                        final parts = business.closingTime.split(':');
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: int.parse(parts[0]),
                            minute: int.parse(parts[1]),
                          ),
                        );
                        if (time != null) {
                          final formatted =
                              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                          ref.read(businessRepositoryProvider).updateBusiness(
                            business.copyWith(closingTime: formatted),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error loading business: $e'),
    );
  }
}

class _BusinessSettingsSection extends ConsumerWidget {
  const _BusinessSettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessAsync = ref.watch(currentBusinessProvider);

    return businessAsync.maybeWhen(
      data: (business) {
        if (business == null) return const SizedBox.shrink();
        return PermissionGate(
          permission: Permission.accessSettings,
          child: _SettingTile(
            title: 'Edit Business Details',
            subtitle: 'Update address, contact, and GST info',
            onTap: () => context.push('/business-setup?id=${business.id}'),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeModeTile extends ConsumerWidget {
  const _ThemeModeTile({required this.currentMode});
  final ThemeMode currentMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Theme Mode', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode),
                ),
              ],
              selected: {currentMode},
              onSelectionChanged: (newSelection) {
                ref.read(themeModeProvider.notifier).setThemeMode(newSelection.first);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AccentColorTile extends ConsumerWidget {
  const _AccentColorTile({required this.currentColor});
  final Color currentColor;

  static const colors = [
    (name: 'Green', color: Color(0xFFB9F6CA)),
    (name: 'Blue', color: Color(0xFF448AFF)),
    (name: 'Orange', color: Color(0xFFFFAB40)),
    (name: 'Purple', color: Color(0xFFE040FB)),
    (name: 'Red', color: Color(0xFFFF5252)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Accent Color', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: colors.map((c) {
                final isSelected = currentColor.toARGB32() == c.color.toARGB32();
                return GestureDetector(
                  onTap: () => ref.read(accentColorProvider.notifier).setAccentColor(c.color),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c.color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3)
                          : null,
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: c.color.withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                      ],
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.black)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
