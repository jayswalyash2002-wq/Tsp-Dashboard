import 'package:flutter/foundation.dart';
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
import '../../memberships/presentation/business_selector_screen.dart';
import '../../business/presentation/business_setup_screen.dart';
import '../../business/data/business_providers.dart';
import '../../core/device/device_providers.dart';
import '../../activity_log/domain/entities/activity_log_enums.dart';
import '../../activity_log/data/models/activity_log_model.dart';
import '../../features/staff/providers/staff_providers.dart';

import 'package:go_router/go_router.dart';

enum _AppState {
  loading,
  intentSelection,
  login,
  businessSetup, 
  onboarding, // Generic onboarding state
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
    
    final currentPath = GoRouterState.of(context).uri.path;

    final state = _determineState(
      authState: authState,
      membershipsAsync: membershipsAsync,
      session: session,
      deviceName: deviceName,
      profileAsync: userProfileAsync,
      currentPath: currentPath,
    );

    if (kDebugMode && session.businessId != null) {
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
      case _AppState.onboarding:
        // Ready to show the child (setup, join, etc)
        return widget.child ?? const IntentSelectionScreen();
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
    required String currentPath,
  }) {
    if (authState.isLoading || membershipsAsync.isLoading || profileAsync.isLoading) {
      return _AppState.loading;
    }
    
    if (authState.hasError || membershipsAsync.hasError || profileAsync.hasError) {
      return _AppState.error;
    }

    final user = authState.value;
    if (user == null) {
      if (kDebugMode) {
        debugPrint('AUTH_GATE: No Firebase User found. Checking for landing/onboarding routes.');
      }
      
      // ALLOW Onboarding/Landing routes without a user
      final publicRoutes = [
        '/auth/join',
        '/auth/signup',
        '/auth/otp',
        '/business-setup',
        '/auth/login',
        '/auth/forgot-password',
        '/onboarding'
      ];
      if (publicRoutes.contains(currentPath)) {
        return _AppState.onboarding; 
      }

      // Clear session on logout
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(sessionProvider).businessId != null) {
          ref.read(sessionProvider.notifier).clear();
        }
      });
      return _AppState.intentSelection;
    }

    if (kDebugMode) {
      debugPrint('AUTH_GATE: Firebase User authenticated: ${user.uid}');
    }

    final memberships = membershipsAsync.value ?? [];
    final profile = profileAsync.value;
    
    if (kDebugMode) {
      debugPrint('AUTH_GATE: Resolved ${memberships.length} memberships. Profile businessId: ${profile?.businessId}');
    }

    // Auth Resolution Flow
    
    // CASE A — empty result (no active memberships)
    if (memberships.isEmpty) {
      // If we are still loading profile or memberships, wait.
      if (profile != null && profile.businessId != null) {
        if (kDebugMode) {
          debugPrint('AUTH_GATE: Profile has businessId ${profile.businessId} but memberships list is empty. Waiting for sync...');
        }
        return _AppState.loading;
      }

      if (kDebugMode) {
        debugPrint('AUTH_GATE: No memberships found for UID: ${user.uid}. Routing to Onboarding/Intent Selection.');
      }
      
      // AUTO CLAIM if pending invite exists
      final pendingInvite = ref.read(pendingInviteProvider);
      if (pendingInvite != null) {
        if (kDebugMode) {
          debugPrint('AUTH_GATE: Found pending invite for ${pendingInvite.businessId}. Auto-claiming...');
        }
        
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          // Clear pending immediately to prevent multiple triggers
          ref.read(pendingInviteProvider.notifier).state = null;
          
          try {
            await ref.read(claimInviteProvider.notifier).claim(
              businessId: pendingInvite.businessId,
              inviteCode: pendingInvite.code,
            );
          } catch (e) {
            debugPrint('AUTH_GATE: Auto-claim failed: $e');
          }
        });
        return _AppState.loading;
      }

      // AUTO CREATE if pending business exists
      final pendingBusiness = ref.read(pendingBusinessProvider);
      if (pendingBusiness != null) {
        if (kDebugMode) {
          debugPrint('AUTH_GATE: Found pending business "${pendingBusiness.businessName}". Auto-creating...');
        }
        
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          // Clear pending immediately
          ref.read(pendingBusinessProvider.notifier).state = null;
          
          try {
            // Safety check: Don't create if memberships appeared during sync
            final currentMemberships = ref.read(userMembershipsProvider).value ?? [];
            if (currentMemberships.isNotEmpty) {
              debugPrint('AUTH_GATE: User already has memberships. Skipping auto-create.');
              return;
            }

            final repo = ref.read(businessRepositoryProvider);
            final deviceIdentity = ref.read(deviceIdentityProvider).value;
            final profile = ref.read(userProfileProvider).value;

            final logTemplate = ActivityLogModel(
              activityLogId: '',
              businessId: '',
              performedBy: user.uid,
              performedByName: profile?.displayName ?? 'Owner',
              performedByRole: 'owner',
              action: ActivityAction.businessCreated,
              category: ActivityCategory.business,
              metadata: {
                'businessType': pendingBusiness.businessType,
                'city': pendingBusiness.city ?? '',
                'area': pendingBusiness.area ?? '',
              },
              appVersion: deviceIdentity?.appVersion ?? 'unknown',
              platform: deviceIdentity?.platform ?? 'unknown',
            );

            await repo.createBusiness(
              uid: user.uid,
              business: pendingBusiness.copyWith(
                ownerName: profile?.displayName ?? 'Owner',
                officialEmail: profile?.email ?? '',
              ),
              logTemplate: logTemplate,
            );
            
            ref.invalidate(userProfileProvider);
          } catch (e) {
            debugPrint('AUTH_GATE: Auto-create failed: $e');
          }
        });
        return _AppState.loading;
      }

      // Allow onboarding-related routes to show through
      final onboardingRoutes = ['/business-setup', '/auth/join', '/auth/signup', '/auth/otp', '/onboarding'];
      if (onboardingRoutes.contains(currentPath)) {
        return _AppState.onboarding;
      }

      return _AppState.intentSelection;
    }

    // CASE B & C: Resolution
    if (session.businessId == null) {
      // RESTORATION HINT: Use businessId from user profile if available
      if (profile?.businessId != null) {
        final matching = memberships.where((m) => m.businessId == profile!.businessId).firstOrNull;
        if (matching != null) {
          if (kDebugMode) {
            debugPrint('AUTH_GATE: Restoring session from profile businessId: ${matching.businessId}');
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(sessionProvider.notifier).setSession(
              businessId: matching.businessId,
              userUid: user.uid,
              role: matching.role,
              membershipId: matching.membershipId,
              branchId: matching.branchId,
            );
          });
          return _AppState.loading;
        }
      }

      if (memberships.length == 1) {
        // CASE B: Single membership -> auto-resolve
        final m = memberships.first;
        if (kDebugMode) {
          debugPrint('AUTH_GATE: Auto-resolving business ${m.businessId} with role ${m.role.name}');
        }
        
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
        if (kDebugMode) {
          debugPrint('AUTH_GATE: Multiple memberships (${memberships.length}). Showing selector.');
        }
        return _AppState.selectBusiness;
      }
    }

    // Device Setup logic
    if (deviceName == null || deviceName.trim().isEmpty) {
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
