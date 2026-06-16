import 'package:shared_preferences/shared_preferences.dart';

class PrefsUtils {
  static const String _keyWorkerName = 'worker_name';
  static const String _keyHourlyRate = 'hourly_rate';
  static const String _keyRounding = 'rounding';
  static const String _keyShowEarnings = 'show_earnings';

  static Future<String> getWorkerName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyWorkerName) ?? '';
  }

  static Future<bool> setWorkerName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setString(_keyWorkerName, name);
  }

  static Future<double> getHourlyRate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyHourlyRate) ?? 0.0;
  }

  static Future<bool> setHourlyRate(double rate) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setDouble(_keyHourlyRate, rate);
  }

  static Future<String> getRounding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRounding) ?? '15';
  }

  static Future<bool> setRounding(String rounding) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setString(_keyRounding, rounding);
  }

  static Future<bool> getShowEarnings() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyShowEarnings) ?? false;
  }

  static Future<bool> setShowEarnings(bool show) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setBool(_keyShowEarnings, show);
  }
}
