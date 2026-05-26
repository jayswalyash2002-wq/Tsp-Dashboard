import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/prefs.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this.ref) : super(ThemeMode.system) {
    _load();
  }

  final Ref ref;

  Future<void> _load() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final saved = prefs.getString(PrefKeys.themeMode);
    if (saved != null) {
      state = ThemeMode.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => ThemeMode.system,
      );
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setString(PrefKeys.themeMode, mode.name);
  }
}

final accentColorProvider = StateNotifierProvider<AccentColorNotifier, Color>((ref) {
  return AccentColorNotifier(ref);
});

class AccentColorNotifier extends StateNotifier<Color> {
  static const defaultAccent = Color(0xFFB9F6CA);

  AccentColorNotifier(this.ref) : super(defaultAccent) {
    _load();
  }

  final Ref ref;

  Future<void> _load() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final saved = prefs.getInt(PrefKeys.accentColor);
    if (saved != null) {
      state = Color(saved);
    }
  }

  Future<void> setAccentColor(Color color) async {
    state = color;
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setInt(PrefKeys.accentColor, color.toARGB32());
  }
}
