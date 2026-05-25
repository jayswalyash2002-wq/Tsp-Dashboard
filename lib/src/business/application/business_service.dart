import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/business_providers.dart';
import '../domain/business.dart';
import '../data/business_repository.dart';

class BusinessService extends WidgetsBindingObserver {
  final Ref _ref;
  final BusinessRepository _repository;
  Timer? _checkTimer;
  bool _isObserving = false;

  BusinessService(this._ref, this._repository);

  void startPeriodicCheck() {
    if (!_isObserving) {
      WidgetsBinding.instance.addObserver(this);
      _isObserving = true;
    }

    if (_checkTimer != null) return;
    
    // Check every minute
    _checkTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      checkBusinessStatus();
    });
    // Initial check
    checkBusinessStatus();
  }

  void stopPeriodicCheck() {
    _checkTimer?.cancel();
    _checkTimer = null;
    if (_isObserving) {
      WidgetsBinding.instance.removeObserver(this);
      _isObserving = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('BusinessService: App resumed, checking status');
      checkBusinessStatus();
    }
  }

  Future<void> checkBusinessStatus() async {
    final business = await _ref.read(currentBusinessProvider.future);
    if (business == null) return;
    if (business.manualOverride) return;

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    final openParts = business.openingTime.split(':');
    final openMinutes = int.parse(openParts[0]) * 60 + int.parse(openParts[1]);

    final closeParts = business.closingTime.split(':');
    final closeMinutes = int.parse(closeParts[0]) * 60 + int.parse(closeParts[1]);

    String? targetStatus;

    // Logic: Support for wrap-around hours (e.g., 10 PM to 4 AM)
    bool isOperatingHours;
    if (openMinutes < closeMinutes) {
      isOperatingHours = currentMinutes >= openMinutes && currentMinutes < closeMinutes;
    } else {
      // Overnight operation
      isOperatingHours = currentMinutes >= openMinutes || currentMinutes < closeMinutes;
    }

    if (isOperatingHours) {
      if (business.autoOpenEnabled && business.businessStatus != 'open') {
        targetStatus = 'open';
      }
    } else {
      // Outside of operating hours
      if (business.autoCloseEnabled && business.businessStatus != 'closed') {
        targetStatus = 'closed';
      }
    }

    if (targetStatus != null) {
      debugPrint('BusinessService: Auto-changing status to $targetStatus');
      await _repository.updateBusiness(business.copyWith(
        businessStatus: targetStatus,
        lastStatusUpdate: DateTime.now(),
      ));
    }
  }

  Future<void> toggleManualOverride(Business business, bool override) async {
    await _repository.updateBusiness(business.copyWith(
      manualOverride: override,
      lastStatusUpdate: DateTime.now(),
    ));
  }

  Future<void> setBusinessStatus(Business business, String status) async {
    await _repository.updateBusiness(business.copyWith(
      businessStatus: status,
      manualOverride: true, // Manually setting status typically overrides auto
      lastStatusUpdate: DateTime.now(),
    ));
  }
}

final businessServiceProvider = Provider<BusinessService>((ref) {
  final repo = ref.watch(businessRepositoryProvider);
  return BusinessService(ref, repo);
});

final businessLifecycleProvider = Provider<void>((ref) {
  final business = ref.watch(currentBusinessProvider).value;
  final service = ref.watch(businessServiceProvider);
  
  if (business != null) {
    service.startPeriodicCheck();
  } else {
    service.stopPeriodicCheck();
  }
  
  ref.onDispose(() {
    service.stopPeriodicCheck();
  });
});
