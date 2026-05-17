import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/presentation/auth_gate.dart';
import '../auth/presentation/otp_verification_screen.dart';
import '../auth/presentation/register_details_screen.dart';
import '../auth/presentation/sign_up_screen.dart';
import '../dashboard/presentation/dashboard_screen.dart';
import '../dashboard/presentation/edit_menu_screen.dart';
import '../dashboard/presentation/history_screen.dart';
import '../expenses/presentation/expenses_screen.dart';
import '../profile/presentation/profile_screen.dart';
import '../reports/presentation/expense_reports_screen.dart';
import '../reports/presentation/sales_reports_screen.dart';
import '../business/presentation/business_setup_screen.dart';
import 'shell_scaffold.dart';

import '../core/rbac/permission.dart';
import '../core/rbac/permission_manager.dart';

import '../auth/presentation/staff_management_screen.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final permissionManager = ref.watch(permissionManagerProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final path = state.uri.path;

      // Centralized Route-Permission mapping
      final routePermissions = {
        '/sales-reports': Permission.viewReports,
        '/expense-reports': Permission.viewReports,
        '/edit-menu': Permission.manageBusiness,
        '/business-setup': Permission.manageBusiness,
        '/expenses': Permission.manageExpenses,
        '/staff': Permission.manageStaff,
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
        path: '/staff',
        builder: (context, state) => const StaffManagementScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthGate(),
        routes: [
          GoRoute(
            path: 'signup',
            builder: (context, state) => const SignUpScreen(),
          ),
          GoRoute(
            path: 'otp',
            builder: (context, state) {
              final email = state.uri.queryParameters['email'] ?? '';
              return OtpVerificationScreen(email: email);
            },
          ),
          GoRoute(
            path: 'details',
            builder: (context, state) {
              final email = state.uri.queryParameters['email'] ?? '';
              return RegisterDetailsScreen(email: email);
            },
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => AuthGate(child: child),
        routes: [
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
            builder: (context, state) => const BusinessSetupScreen(),
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
