import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';
import '../data/auth_providers.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';
import 'device_name_screen.dart';
import 'login_screen.dart';
import 'intent_selection_screen.dart';
import '../../memberships/data/membership_providers.dart';
import '../../memberships/domain/membership.dart';
import '../../memberships/presentation/no_business_access_screen.dart';
import '../../memberships/presentation/business_selector_screen.dart';
import '../../business/presentation/business_setup_screen.dart';

enum _AppState {
  loading,
  intentSelection,
  login,
  businessSetup, // Step 2
  selectBusiness,
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
    final membershipsAsync = ref.watch(userMembershipsProvider);
    final session = ref.watch(sessionProvider);
    final deviceName = ref.watch(deviceNameProvider);
    final authRepoAsync = ref.watch(authRepositoryProvider);
    final userProfileAsync = ref.watch(userProfileProvider);

    final state = _determineState(
      authState: authState,
      membershipsAsync: membershipsAsync,
      session: session,
      deviceName: deviceName,
      profileAsync: userProfileAsync,
    );

    if (session.businessId != null) {
      debugPrint('AUTH_GATE: Active Session detected for Business: ${session.businessId}');
    }

    switch (state) {
      case _AppState.loading:
        return const _BlockingLoader();
      case _AppState.intentSelection:
        return const IntentSelectionScreen();
      case _AppState.login:
        return const LoginScreen();
      case _AppState.businessSetup:
        return const BusinessSetupScreen();
      case _AppState.selectBusiness:
        return BusinessSelectorScreen(memberships: membershipsAsync.value!);
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
        final error = authState.error ?? membershipsAsync.error ?? userProfileAsync.error;
        return _BlockingError(message: error.toString());
    }
  }

  _AppState _determineState({
    required AsyncValue<User?> authState,
    required AsyncValue<List<Membership>> membershipsAsync,
    required SessionState session,
    required String? deviceName,
    required AsyncValue<AppUser?> profileAsync,
  }) {
    if (authState.isLoading || membershipsAsync.isLoading || profileAsync.isLoading) {
      return _AppState.loading;
    }
    
    if (authState.hasError || membershipsAsync.hasError || profileAsync.hasError) {
      return _AppState.error;
    }

    final user = authState.value;
    if (user == null) {
      debugPrint('AUTH_GATE: No Firebase User found. Redirecting to Intent Selection.');
      // Clear session on logout
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(sessionProvider).businessId != null) {
          ref.read(sessionProvider.notifier).clear();
        }
      });
      return _AppState.intentSelection;
    }

    debugPrint('AUTH_GATE: Firebase User authenticated: ${user.uid}');

    final memberships = membershipsAsync.value ?? [];
    
    // Auth Resolution Flow
    
    // CASE A — empty result (no active memberships)
    if (memberships.isEmpty) {
      debugPrint('AUTH_GATE: No memberships found for UID: ${user.uid}. Routing to Business Setup (Step 2)');
      return _AppState.businessSetup;
    }

    // CASE B & C: Resolution
    if (session.businessId == null) {
      if (memberships.length == 1) {
        // CASE B: Single membership -> auto-resolve
        final m = memberships.first;
        debugPrint('AUTH_GATE: Auto-resolving business ${m.businessId} with role ${m.role.name}');
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(sessionProvider.notifier).setSession(
            businessId: m.businessId,
            userUid: user.uid,
            role: m.role,
            membershipId: m.membershipId,
            branchId: m.branchId,
          );
        });
        return _AppState.loading;
      } else {
        // CASE C: Multiple memberships -> show selector
        debugPrint('AUTH_GATE: Multiple memberships (${memberships.length}). Showing selector.');
        return _AppState.selectBusiness;
      }
    }

    // Device Setup logic
    if (deviceName == null || deviceName.trim().isEmpty) {
      final profile = profileAsync.value;
      if (profile != null && profile.displayName.trim().isNotEmpty) {
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
