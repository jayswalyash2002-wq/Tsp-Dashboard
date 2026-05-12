import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import 'router.dart';

class TspDashboardApp extends ConsumerWidget {
  const TspDashboardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'TSP Dashboard',
      debugShowCheckedModeBanner: false,
      theme: appThemeDark(),
      routerConfig: router,
    );
  }
}

