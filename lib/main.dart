import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'src/app/app.dart';
import 'src/core/firebase/firebase_bootstrap.dart';
import 'src/core/sync/sync_service.dart';
import 'src/core/sync/local_database_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await bootstrapFirebase();
  
  final container = ProviderContainer();
  // Initialize Local DB
  await container.read(localDatabaseServiceProvider).init();
  // Initialize Sync Service
  container.read(syncServiceProvider).init();

  runApp(UncontrolledProviderScope(
    container: container,
    child: const TspDashboardApp(),
  ));
}


