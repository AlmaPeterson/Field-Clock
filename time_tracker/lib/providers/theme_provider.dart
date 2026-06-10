import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  AppTheme _theme = const AppTheme();

  AppTheme get theme => _theme;
  bool get isDark => _theme.isDark;
  Color get accent => _theme.accent;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('theme_dark') ?? true;
    final accentName = prefs.getString('theme_accent') ?? 'Amber';
    final accent =
        AppColors.accents[accentName] ?? AppColors.amber;
    _theme = AppTheme(accent: accent, isDark: isDark);
    notifyListeners();
  }

  Future<void> setDark(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('theme_dark', value);
    _theme = AppTheme(accent: _theme.accent, isDark: value);
    notifyListeners();
  }

  Future<void> setAccent(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_accent', name);
    final color = AppColors.accents[name] ?? AppColors.amber;
    _theme = AppTheme(accent: color, isDark: _theme.isDark);
    notifyListeners();
  }
}