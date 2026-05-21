import 'package:flutter/material.dart';

ThemeData createAppTheme(Brightness brightness, Color accentColor) {
  final isDark = brightness == Brightness.dark;
  
  final surface = isDark ? const Color(0xFF0B0C0F) : const Color(0xFFF8F9FA);
  final surface2 = isDark ? const Color(0xFF11131A) : const Color(0xFFF1F3F5);
  final card = isDark ? const Color(0xFF141826) : Colors.white;
  final text = isDark ? const Color(0xFFEDEFF6) : const Color(0xFF1A1C1E);
  final textMuted = isDark ? const Color(0xFFB6BBD0) : const Color(0xFF6C757D);
  const danger = Color(0xFFFF6B6B);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: accentColor,
    brightness: brightness,
    surface: surface,
    onSurface: text,
    primary: accentColor,
    onPrimary: isDark ? Colors.black : Colors.white,
    secondary: const Color(0xFF7AA2FF),
    onSecondary: isDark ? Colors.black : Colors.white,
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
    appBarTheme: AppBarTheme(
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
      hintStyle: TextStyle(color: textMuted),
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
      contentTextStyle: TextStyle(color: text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

// Keep the old name for backward compatibility if needed, 
// but it's better to use the new one.
ThemeData appThemeDark() => createAppTheme(Brightness.dark, const Color(0xFFB9F6CA));
