import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_providers.dart';

class DeviceNameScreen extends ConsumerStatefulWidget {
  const DeviceNameScreen({super.key});

  @override
  ConsumerState<DeviceNameScreen> createState() => _DeviceNameScreenState();
}

class _DeviceNameScreenState extends ConsumerState<DeviceNameScreen> {
  final _name = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    try {
      final repo = await ref.read(authRepositoryProvider.future);
      await repo.setLocalDeviceName(name);
      await repo.registerDeviceSession(deviceName: name);
      
      // Update provider to trigger AuthGate rebuild
      ref.read(deviceNameProvider.notifier).state = name;
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save device name: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device name'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Name this device',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'This shows on orders for accountability.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onSurface.withValues(alpha: 0.75)),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _name,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _busy ? null : _save(),
                decoration: const InputDecoration(
                  labelText: 'Device name',
                  hintText: 'Example: Yash’s Phone',
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _busy ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save device name'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

