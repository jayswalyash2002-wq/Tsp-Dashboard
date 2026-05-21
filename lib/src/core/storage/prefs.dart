import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

class PrefKeys {
  static const deviceName = 'device_name';
  static const themeMode = 'theme_mode';
  static const accentColor = 'accent_color';
}

