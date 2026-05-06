import 'package:flutter/material.dart';

class AppTheme {
  static const ColorScheme _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF4A6FA5),
    onPrimary: Colors.white,
    secondary: Color(0xFF6B8FBF),
    onSecondary: Colors.white,
    error: Color(0xFFBA1A1A),
    onError: Colors.white,
    surface: Color(0xFFFAF8FF),
    onSurface: Color(0xFF1A1B22),
    surfaceContainerHighest: Color(0xFFE3E1F0),
    outline: Color(0xFF767586),
  );

  static const ColorScheme _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFA6E22E),
    onPrimary: Color(0xFF1C2408),
    secondary: Color(0xFFF92672),
    onSecondary: Color(0xFF300013),
    error: Color(0xFFFF6188),
    onError: Color(0xFF3A0012),
    surface: Color(0xFF2D2A2E),
    onSurface: Color(0xFFF8F8F2),
    surfaceContainerHighest: Color(0xFF49483E),
    outline: Color(0xFF9B9685),
  );

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: _lightColorScheme,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: _darkColorScheme,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: const Color(0xFF272822),
    canvasColor: const Color(0xFF272822),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF2D2A2E),
      foregroundColor: Color(0xFFF8F8F2),
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF34352F),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF34352F),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF5A584A)),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFA6E22E), width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF49483E),
      labelStyle: const TextStyle(color: Color(0xFFF8F8F2)),
      side: const BorderSide(color: Color(0xFF5A584A)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFFA6E22E),
      foregroundColor: Color(0xFF1C2408),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
