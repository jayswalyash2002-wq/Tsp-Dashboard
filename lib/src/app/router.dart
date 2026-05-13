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
import '../dashboard/presentation/reports_screen.dart';
import '../expenses/presentation/expenses_screen.dart';
import '../profile/presentation/profile_screen.dart';
import 'shell_scaffold.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/dashboard',
    routes: [
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
      GoRoute(
        path: '/edit-menu',
        builder: (context, state) => const EditMenuScreen(),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AuthGate(
            child: ShellScaffold(navigationShell: navigationShell),
          );
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
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text(state.error.toString())),
    ),
  );
});
