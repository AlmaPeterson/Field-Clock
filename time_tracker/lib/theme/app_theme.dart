import 'package:flutter/material.dart';

class AppColors {
  // Accent options
  static const amber = Color(0xFFE8A020);
  static const blue = Color(0xFF4A90D9);
  static const green = Color(0xFF4CAF82);
  static const red = Color(0xFFE05252);
  static const purple = Color(0xFF9B6DD6);
  static const cyan = Color(0xFF00BCD4);

  static const Map<String, Color> accents = {
    'Amber': amber,
    'Blue': blue,
    'Green': green,
    'Red': red,
    'Purple': purple,
    'Cyan': cyan,
  };

  // Dark backgrounds
  static const darkBackground = Color(0xFF1A1C1E);
  static const darkSurface = Color(0xFF252830);
  static const darkSurfaceAlt = Color(0xFF2E3138);
  static const darkOnBackground = Color(0xFFF0EDE8);
  static const darkOnSurface = Color(0xFFCDC8C0);

  // Light backgrounds
  static const lightBackground = Color(0xFFF5F4F1);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceAlt = Color(0xFFEEECE8);
  static const lightOnBackground = Color(0xFF1A1C1E);
  static const lightOnSurface = Color(0xFF6B6864);

  // Shared
  static const success = Color(0xFF4CAF82);
  static const error = Color(0xFFE05252);
}

class AppTheme {
  final Color accent;
  final bool isDark;

  const AppTheme({
    this.accent = AppColors.amber,
    this.isDark = true,
  });

  Color get background =>
      isDark ? AppColors.darkBackground : AppColors.lightBackground;
  Color get surface =>
      isDark ? AppColors.darkSurface : AppColors.lightSurface;
  Color get surfaceAlt =>
      isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt;
  Color get onBackground =>
      isDark ? AppColors.darkOnBackground : AppColors.lightOnBackground;
  Color get onSurface =>
      isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface;
  Color get primary => accent;
  Color get primaryDark =>
      Color.fromARGB(255, (accent.red * 0.85).round(),
          (accent.green * 0.85).round(), (accent.blue * 0.85).round());
  Color get success => AppColors.success;
  Color get error => AppColors.error;

  ThemeData get themeData => ThemeData(
        brightness: isDark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: background,
        primaryColor: accent,
        colorScheme: ColorScheme(
          brightness: isDark ? Brightness.dark : Brightness.light,
          primary: accent,
          onPrimary: Colors.black,
          secondary: primaryDark,
          onSecondary: Colors.black,
          error: AppColors.error,
          onError: Colors.white,
          surface: surface,
          onSurface: onBackground,
        ),
        appBarTheme: AppBarTheme(
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
              borderRadius: BorderRadius.circular(12)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(
                vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        textTheme: TextTheme(
          headlineLarge: TextStyle(
              color: onBackground,
              fontSize: 28,
              fontWeight: FontWeight.w800),
          headlineMedium: TextStyle(
              color: onBackground,
              fontSize: 22,
              fontWeight: FontWeight.w700),
          titleLarge: TextStyle(
              color: onBackground,
              fontSize: 18,
              fontWeight: FontWeight.w600),
          titleMedium: TextStyle(
              color: onBackground,
              fontSize: 16,
              fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(color: onSurface, fontSize: 16),
          bodyMedium: TextStyle(color: onSurface, fontSize: 14),
          labelLarge: TextStyle(
              color: accent,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0),
        ),
        dividerColor: surfaceAlt,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceAlt,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: accent),
          ),
          labelStyle: TextStyle(color: onSurface),
          hintStyle: TextStyle(color: onSurface),
        ),
      );
}