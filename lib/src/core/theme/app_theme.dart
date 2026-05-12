import 'package:flutter/material.dart';

ThemeData appThemeDark() {
  const surface = Color(0xFF0B0C0F);
  const surface2 = Color(0xFF11131A);
  const card = Color(0xFF141826);
  const accent = Color(0xFFB9F6CA); // mint
  const text = Color(0xFFEDEFF6);
  const textMuted = Color(0xFFB6BBD0);
  const danger = Color(0xFFFF6B6B);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: Brightness.dark,
    surface: surface,
    onSurface: text,
    primary: accent,
    onPrimary: Colors.black,
    secondary: Color(0xFF7AA2FF),
    onSecondary: Colors.black,
    error: danger,
    onError: Colors.black,
  ).copyWith(
    surfaceContainerHighest: surface2,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: surface,
    fontFamily: null,
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: surface,
      foregroundColor: text,
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: colorScheme.primary,
      unselectedItemColor: textMuted,
      type: BottomNavigationBarType.fixed,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      hintStyle: const TextStyle(color: textMuted),
    ),
    textTheme: base.textTheme.copyWith(
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        height: 1.2,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surface2,
      contentTextStyle: const TextStyle(color: text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

