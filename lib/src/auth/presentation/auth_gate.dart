import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';
import '../../core/sync/local_database_service.dart';
import '../data/auth_providers.dart';
import '../domain/app_user.dart';
import 'login_screen.dart';
import '../../memberships/data/membership_providers.dart';
import '../../memberships/domain/membership.dart';
import '../../memberships/presentation/business_selector_screen.dart';

enum _AuthV2State {
  unauthenticated,
  noMembership,
  authenticated,
  loading,
  error,
}

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key, this.child});

  final Widget? child;

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateChangesProvider);
    final membershipsAsync = ref.watch(userMembershipsProvider);
    final userProfileAsync = ref.watch(userProfileProvider);
    final session = ref.watch(sessionProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          debugPrint('AUTH_V2_STEP_1: Unauthenticated');
          
          // CRITICAL: Clear leaked session data and local cache on logout
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final session = ref.read(sessionProvider);
            if (session.businessId != null || session.isLoaded) {
              debugPrint('AUTH_V2_STEP_1: Clearing leaked session and local cache');
              ref.read(sessionProvider.notifier).clear();
              // Also ensure local partitioned storage is wiped
              await ref.read(localDatabaseServiceProvider).clearAll();
            }
          });
          
          return const LoginScreen();
        }

        return membershipsAsync.when(
          data: (memberships) {
            return userProfileAsync.when(
              data: (profile) {
                final activeMemberships = memberships
                    .where((m) => m.status == MembershipStatus.accepted)
                    .toList();

                if (activeMemberships.isEmpty) {
                  debugPrint('AUTH_V2_STEP_2: Authenticated, No Membership');
                  
                  // If we are in the shell, we must not show the dashboard child.
                  // The router will handle redirection to /business-setup.
                  // Showing a loader here is safer than showing a potentially leaked dashboard.
                  if (widget.child != null) {
                    return const _ProfessionalLoader(message: 'Preparing your workspace...');
                  }
                  
                  return const SizedBox.shrink();
                }

                debugPrint('AUTH_V2_STEP_3: Authenticated, Active Membership Found');
                
                // Session resolution
                if (session.businessId == null) {
                  // If multiple businesses and no restoration hint, show selector
                  if (activeMemberships.length > 1 && profile?.businessId == null) {
                    return BusinessSelectorScreen(memberships: activeMemberships);
                  }

                  _handleSessionRestoration(
                    activeMemberships: activeMemberships,
                    profile: profile,
                    user: user,
                  );
                  return const _ProfessionalLoader(message: 'Restoring session...');
                }

                // Ensure device session is registered
                _ensureDeviceSession(user);

                return widget.child ?? const SizedBox.shrink();
              },
              loading: () => const _ProfessionalLoader(message: 'Loading user profile...'),
              error: (e, st) => _BlockingError(message: 'Profile Error: $e'),
            );
          },
          loading: () => const _ProfessionalLoader(message: 'Checking memberships...'),
          error: (e, st) => _BlockingError(message: 'Membership Error: $e'),
        );
      },
      loading: () => const _ProfessionalLoader(message: 'Authenticating...'),
      error: (e, st) => _BlockingError(message: 'Auth Error: $e'),
    );
  }

  void _handleSessionRestoration({
    required List<Membership> activeMemberships,
    required AppUser? profile,
    required User user,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // 1. Try to restore from profile
      if (profile?.businessId != null) {
        final matching = activeMemberships
            .where((m) => m.businessId == profile!.businessId)
            .firstOrNull;
        if (matching != null) {
          ref.read(sessionProvider.notifier).setSession(
                businessId: matching.businessId,
                userUid: user.uid,
                role: matching.role,
                membershipId: matching.membershipId,
                branchId: matching.branchId,
              );
          return;
        }
      }

      // 2. If only one membership, auto-select it
      if (activeMemberships.length == 1) {
        final m = activeMemberships.first;
        ref.read(sessionProvider.notifier).setSession(
              businessId: m.businessId,
              userUid: user.uid,
              role: m.role,
              membershipId: m.membershipId,
              branchId: m.branchId,
            );
      }
    });
  }

  void _ensureDeviceSession(User user) {
    final deviceName = ref.read(deviceNameProvider);
    if (deviceName == null || deviceName.trim().isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authRepoAsync = ref.read(authRepositoryProvider);
      if (authRepoAsync.hasValue) {
        final repo = authRepoAsync.value!;
        await repo.registerDeviceSession(deviceName: deviceName);
        await repo.heartbeat();
      }
    });
  }
}

class _ProfessionalLoader extends StatelessWidget {
  const _ProfessionalLoader({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
