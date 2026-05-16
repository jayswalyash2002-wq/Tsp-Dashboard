import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';
import '../data/auth_providers.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';
import 'device_name_screen.dart';
import 'login_screen.dart';
import '../../business/presentation/business_setup_screen.dart';

enum _AppState {
  loading,
  login,
  onboarding,
  deviceSetup,
  ready,
  error,
}

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
    final userProfileAsync = ref.watch(userProfileProvider);
    final deviceName = ref.watch(deviceNameProvider);
    final authRepoAsync = ref.watch(authRepositoryProvider);

    final state = _determineState(
      authState: authState,
      profileAsync: userProfileAsync,
      deviceName: deviceName,
    );

    switch (state) {
      case _AppState.loading:
        return const _BlockingLoader();
      case _AppState.login:
        return const LoginScreen();
      case _AppState.onboarding:
        return const BusinessSetupScreen();
      case _AppState.deviceSetup:
        return const DeviceNameScreen();
      case _AppState.ready:
        final user = authState.value!;
        return authRepoAsync.when(
          data: (repo) {
            _ensureDeviceSession(
              repo: repo,
              uid: user.uid,
              deviceName: deviceName!,
            );
            return widget.child ?? const SizedBox.shrink();
          },
          loading: () => const _BlockingLoader(),
          error: (e, _) => _BlockingError(message: e.toString()),
        );
      case _AppState.error:
        final error = authState.error ?? userProfileAsync.error;
        return _BlockingError(message: error.toString());
    }
  }

  _AppState _determineState({
    required AsyncValue<User?> authState,
    required AsyncValue<AppUser?> profileAsync,
    required String? deviceName,
  }) {
    if (authState.isLoading || profileAsync.isLoading) return _AppState.loading;
    if (authState.hasError || profileAsync.hasError) return _AppState.error;

    final user = authState.value;
    if (user == null) return _AppState.login;

    final profile = profileAsync.value;
    if (profile == null || profile.businessId == null || profile.businessId!.isEmpty) {
      return _AppState.onboarding;
    }

    if (deviceName == null || deviceName.trim().isEmpty) {
      // Auto-set device name from profile if possible
      if (profile.displayName.trim().isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final repo = await ref.read(authRepositoryProvider.future);
          await repo.setLocalDeviceName(profile.displayName);
          ref.read(deviceNameProvider.notifier).state = profile.displayName;
        });
        return _AppState.loading;
      }
      return _AppState.deviceSetup;
    }

    return _AppState.ready;
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

