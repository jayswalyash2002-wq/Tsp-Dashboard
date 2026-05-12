import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';
import '../data/auth_providers.dart';
import '../data/auth_repository.dart';
import 'device_name_screen.dart';
import 'login_screen.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key, this.child});

  final Widget? child;

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  String? _sessionUid;
  String? _sessionDeviceName;

  void _ensureDeviceSession({
    required AuthRepository repo,
    required String uid,
    required String deviceName,
  }) {
    final normalizedName = deviceName.trim();
    if (normalizedName.isEmpty) return;

    if (_sessionUid == uid && _sessionDeviceName == normalizedName) return;
    _sessionUid = uid;
    _sessionDeviceName = normalizedName;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ignore: discarded_futures
      repo.registerDeviceSession(deviceName: normalizedName);
      // ignore: discarded_futures
      repo.heartbeat();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateChangesProvider);
    return authState.when(
      data: (user) {
        if (user == null) return const LoginScreen();
        
        final deviceName = ref.watch(deviceNameProvider);
        if (deviceName == null || deviceName.trim().isEmpty) {
          // Instead of showing DeviceNameScreen, try to auto-fetch from profile
          return ref.watch(userProfileProvider).when(
                data: (profile) {
                  final name = profile?['displayName'] as String?;
                  if (name != null && name.trim().isNotEmpty) {
                    // Auto-set the device name and let the provider refresh
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      final repo = await ref.read(authRepositoryProvider.future);
                      await repo.setLocalDeviceName(name);
                      ref.read(deviceNameProvider.notifier).state = name;
                    });
                    return const _BlockingLoader();
                  }
                  // Fallback to manual naming if no profile name found
                  return const DeviceNameScreen();
                },
                loading: () => const _BlockingLoader(),
                error: (e, _) => _BlockingError(message: e.toString()),
              );
        }

        return ref.watch(authRepositoryProvider).when(
              data: (repo) {
                _ensureDeviceSession(
                  repo: repo,
                  uid: user.uid,
                  deviceName: deviceName,
                );
                return widget.child ?? const SizedBox.shrink();
              },
              loading: () => const _BlockingLoader(),
              error: (e, _) => _BlockingError(message: e.toString()),
            );
      },
      loading: () => const _BlockingLoader(),
      error: (e, _) => _BlockingError(message: e.toString()),
    );
  }
}

class _BlockingLoader extends StatelessWidget {
  const _BlockingLoader();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _BlockingError extends StatelessWidget {
  const _BlockingError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

