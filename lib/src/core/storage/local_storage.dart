import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'prefs.dart';

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).maybeWhen(
    data: (p) => p,
    orElse: () => null,
  );
  return LocalStorageService(prefs);
});

class LocalStorageService {
  LocalStorageService(this._prefs);
  final SharedPreferences? _prefs;

  static const _ordersKey = 'local_orders';
  static const _menuKey = 'local_menu';

  Future<void> saveOrder(Map<String, dynamic> order) async {
    if (_prefs == null) return;
    final orders = getOrders();
    orders.add(order);
    await _prefs.setString(_ordersKey, jsonEncode(orders));
  }

  List<Map<String, dynamic>> getOrders() {
    if (_prefs == null) return [];
    final raw = _prefs.getString(_ordersKey);
    if (raw == null) return [];
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(raw));
    } catch (_) {
      return [];
    }
  }

  Future<void> saveMenu(List<Map<String, dynamic>> menu) async {
    if (_prefs == null) return;
    await _prefs.setString(_menuKey, jsonEncode(menu));
  }

  List<Map<String, dynamic>> getMenu() {
    if (_prefs == null) return [];
    final raw = _prefs.getString(_menuKey);
    if (raw == null) return [];
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(raw));
    } catch (_) {
      return [];
    }
  }
}
