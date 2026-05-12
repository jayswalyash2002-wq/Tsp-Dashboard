import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/presentation/auth_gate.dart';
import '../dashboard/presentation/dashboard_screen.dart';
import '../dashboard/presentation/edit_menu_screen.dart';
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
      ),
      GoRoute(
        path: '/edit-menu',
        builder: (context, state) => const EditMenuScreen(),
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
                  child: AuthGate(child: DashboardScreen()),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/expenses',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: AuthGate(child: ExpensesScreen()),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: AuthGate(child: ProfileScreen()),
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
