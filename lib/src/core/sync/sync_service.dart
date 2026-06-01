import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsp_dashboard/src/dashboard/data/dashboard_providers.dart';
import 'package:tsp_dashboard/src/expenses/data/expense_providers.dart';
import 'local_database_service.dart';
import 'sync_models.dart';

final syncServiceProvider = Provider((ref) {
  final localDb = ref.watch(localDatabaseServiceProvider);
  return SyncService(ref, localDb);
});

final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.synced);

class SyncService {
  SyncService(this._ref, this._localDb);

  final Ref _ref;
  final LocalDatabaseService _localDb;
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;

  void init() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      bool hasConnection = false;
      for (final r in results) {
        if (r != ConnectivityResult.none) {
          hasConnection = true;
          break;
        }
      }
      if (hasConnection) {
        syncAll();
      }
    });
    // Initial sync attempt
    syncAll();
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  Future<void> syncAll() async {
    if (_isSyncing) return;
    
    final results = await Connectivity().checkConnectivity();
    bool isOffline = true;
    for (final r in results) {
      if (r != ConnectivityResult.none) {
        isOffline = false;
        break;
      }
    }
    
    if (isOffline) {
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.offline;
      return;
    }

    _isSyncing = true;
    _ref.read(syncStatusProvider.notifier).state = SyncStatus.pending;

    try {
      await _syncOrders();
      await _syncExpenses();
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.synced;
    } catch (e) {
      debugPrint('Sync failed: $e');
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.failed;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncOrders() async {
    final unsynced = _localDb.getUnsyncedOrders();
    if (unsynced.isEmpty) return;

    final repo = await _ref.read(orderRepositoryProvider.future);
    if (repo == null) return;

    for (final order in unsynced) {
      try {
        await repo.syncOrder(order);
      } catch (e) {
        debugPrint('Failed to sync order ${order.id}: $e');
      }
    }
  }

  Future<void> _syncExpenses() async {
    final unsynced = _localDb.getUnsyncedExpenses();
    if (unsynced.isEmpty) return;

    final repo = await _ref.read(expenseRepositoryProvider.future);
    if (repo == null) return;

    for (final expense in unsynced) {
      try {
        await repo.syncExpense(expense, true);
      } catch (e) {
        debugPrint('Failed to sync expense ${expense.id}: $e');
      }
    }
  }
}
