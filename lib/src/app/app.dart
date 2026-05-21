import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/theme_providers.dart';
import 'router.dart';

class TspDashboardApp extends ConsumerWidget {
  const TspDashboardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final accentColor = ref.watch(accentColorProvider);

    return MaterialApp.router(
      title: 'TSP Dashboard',
      debugShowCheckedModeBanner: false,
      theme: createAppTheme(Brightness.light, accentColor),
      darkTheme: createAppTheme(Brightness.dark, accentColor),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
