import 'package:flutter/material.dart';

class AppTheme {
  // Colors — industrial amber on dark slate
  static const Color primary = Color(0xFFE8A020);      // amber
  static const Color primaryDark = Color(0xFFC47F0A);
  static const Color background = Color(0xFF1A1C1E);   // dark slate
  static const Color surface = Color(0xFF252830);
  static const Color surfaceAlt = Color(0xFF2E3138);
  static const Color onBackground = Color(0xFFF0EDE8); // warm white
  static const Color onSurface = Color(0xFFCDC8C0);
  static const Color success = Color(0xFF4CAF82);      // green
  static const Color error = Color(0xFFE05252);
  static const Color warning = Color(0xFFE8A020);

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    primaryColor: primary,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: primaryDark,
      surface: surface,
      error: error,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: onBackground,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: onBackground,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: onBackground, fontSize: 28, fontWeight: FontWeight.w800),
      headlineMedium: TextStyle(color: onBackground, fontSize: 22, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(color: onBackground, fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: onBackground, fontSize: 16, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: onSurface, fontSize: 16),
      bodyMedium: TextStyle(color: onSurface, fontSize: 14),
      labelLarge: TextStyle(color: primary, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1.0),
    ),
  );
}