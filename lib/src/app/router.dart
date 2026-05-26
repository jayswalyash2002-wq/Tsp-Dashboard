import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tsp_dashboard/src/auth/domain/app_user.dart';
import 'package:tsp_dashboard/src/auth/presentation/auth_gate.dart';
import 'package:tsp_dashboard/src/auth/presentation/login_screen.dart';
import 'package:tsp_dashboard/src/auth/presentation/otp_verification_screen.dart';
import 'package:tsp_dashboard/src/auth/presentation/sign_up_screen.dart';
import 'package:tsp_dashboard/src/auth/presentation/forgot_password_screen.dart';
import 'package:tsp_dashboard/src/auth/presentation/intent_selection_screen.dart';
import 'package:tsp_dashboard/src/core/firebase/firebase_providers.dart';
import 'package:tsp_dashboard/src/memberships/presentation/join_business_placeholder_screen.dart';
import 'package:tsp_dashboard/src/dashboard/presentation/dashboard_screen.dart';
import 'package:tsp_dashboard/src/dashboard/presentation/edit_menu_screen.dart';
import 'package:tsp_dashboard/src/dashboard/presentation/history_screen.dart';
import 'package:tsp_dashboard/src/expenses/presentation/expenses_screen.dart';
import 'package:tsp_dashboard/src/profile/presentation/profile_screen.dart';
import 'package:tsp_dashboard/src/profile/presentation/settings_screen.dart';
import 'package:tsp_dashboard/src/reports/presentation/expense_reports_screen.dart';
import 'package:tsp_dashboard/src/reports/presentation/sales_reports_screen.dart';
import 'package:tsp_dashboard/src/business/presentation/business_setup_screen.dart';
import 'package:tsp_dashboard/src/auth/presentation/staff_management_screen.dart';
import 'package:tsp_dashboard/src/inventory/presentation/inventory_screen.dart';
import 'package:tsp_dashboard/src/features/staff/presentation/add_staff_screen.dart';
import 'package:tsp_dashboard/src/features/staff/presentation/edit_staff_screen.dart';
import 'package:tsp_dashboard/src/features/staff/presentation/invite_code_screen.dart';
import 'package:tsp_dashboard/src/features/staff/presentation/pending_invites_screen.dart';
import 'package:tsp_dashboard/src/activity_log/presentation/screens/activity_log_screen.dart';
import 'package:tsp_dashboard/src/analytics/presentation/analytics_screen.dart';
import 'package:tsp_dashboard/src/app/shell_scaffold.dart';
import 'package:tsp_dashboard/src/constants/roles.dart'; // Added for extra param casting

import 'package:tsp_dashboard/src/core/rbac/permission.dart';
import 'package:tsp_dashboard/src/core/rbac/permission_manager.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final permissionManager = ref.watch(permissionManagerProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final path = state.uri.path;
      
      final authState = ref.read(authStateChangesProvider);
      final user = authState.value;
      
      final isAuthPath = path.startsWith('/auth');
      final isBusinessSetup = path.startsWith('/business-setup');
      final isOnboarding = path == '/onboarding' || path == '/';

      // 1. Unauthenticated users should be on /auth, /business-setup, or /onboarding (root)
      if (user == null && !isAuthPath && !isBusinessSetup && !isOnboarding) {
        return '/onboarding';
      }

      // 2. Authenticated users should not be on Login pages if they have a session
      // We allow /auth/signup and /onboarding to persist because they handle 
      // the "authenticated but no business" state via AuthGate.
      if (user != null && path == '/auth/login') {
        return '/dashboard';
      }

      // 3. Centralized Route-Permission mapping
      final routePermissions = {
        '/sales-reports': Permission.viewReports,
        '/expense-reports': Permission.viewReports,
        '/edit-menu': Permission.manageMenu,
        '/business-setup': Permission.manageBusiness,
        '/expenses': Permission.manageExpenses,
        '/staff': Permission.manageStaff,
        '/activity-log': Permission.viewActivityLog,
        '/inventory': Permission.manageInventory,
        '/analytics': Permission.viewAnalytics,
      };

      for (final entry in routePermissions.entries) {
        if (path.startsWith(entry.key)) {
          if (!permissionManager.hasPermission(entry.value)) {
            return '/dashboard'; // Safe fallback
          }
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/auth/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthGate(),
        routes: [
          GoRoute(
            path: 'login',
            name: 'login',
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: 'signup',
            name: 'signup',
            builder: (context, state) => const SignUpScreen(),
          ),
          GoRoute(
            path: 'join',
            name: 'join',
            builder: (context, state) {
              final code = state.uri.queryParameters['code'];
              return JoinBusinessPlaceholderScreen(initialCode: code);
            },
          ),
          GoRoute(
            path: 'otp',
            name: 'otp',
            builder: (context, state) {
              final params = state.uri.queryParameters;
              return OtpVerificationScreen(
                email: params['email'] ?? '',
                phone: params['phone'] ?? '',
                name: params['name'] ?? '',
                password: params['password'] ?? '',
                verificationId: params['verificationId'] ?? '',
              );
            },
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => AuthGate(child: child),
        routes: [
          GoRoute(
            path: '/staff',
            builder: (context, state) => const StaffManagementScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) => const AddStaffScreen(),
              ),
              GoRoute(
                path: 'pending',
                builder: (context, state) => const PendingInvitesScreen(),
              ),
              GoRoute(
                path: 'edit',
                builder: (context, state) {
                  final staff = state.extra as AppUser;
                  return EditStaffScreen(staff: staff);
                },
              ),
              GoRoute(
                path: 'invite-code',
                builder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>;
                  return InviteCodeScreen(
                    code: extra['code'] as String,
                    role: extra['role'] as Role,
                    name: extra['name'] as String,
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/edit-menu',
            builder: (context, state) => const EditMenuScreen(),
          ),
          GoRoute(
            path: '/sales-reports',
            builder: (context, state) => const SalesReportsScreen(),
          ),
          GoRoute(
            path: '/expense-reports',
            builder: (context, state) => const ExpenseReportsScreen(),
          ),
          GoRoute(
            path: '/business-setup',
            builder: (context, state) {
              final businessId = state.uri.queryParameters['id'];
              return BusinessSetupScreen(businessId: businessId);
            },
          ),
          GoRoute(
            path: '/onboarding',
            builder: (context, state) => const IntentSelectionScreen(),
          ),
          GoRoute(
            path: '/activity-log',
            builder: (context, state) => const ActivityLogScreen(),
          ),
          GoRoute(
            path: '/inventory',
            builder: (context, state) => const InventoryScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) {
              return ShellScaffold(navigationShell: navigationShell);
            },
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/dashboard',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: DashboardScreen(),
                    ),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/history',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: HistoryScreen(),
                    ),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/expenses',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: ExpensesScreen(),
                    ),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/analytics',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: AnalyticsScreen(),
                    ),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/profile',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: ProfileScreen(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text(state.error.toString())),
    ),
  );
});
