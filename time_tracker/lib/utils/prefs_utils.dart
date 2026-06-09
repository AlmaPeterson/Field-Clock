import 'package:shared_preferences/shared_preferences.dart';

class PrefsUtils {
  static const String _keyWorkerName = 'worker_name';

  // Gets the saved worker name, defaults to empty string if not found
  static Future<String> getWorkerName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyWorkerName) ?? '';
  }

  // Sets the worker name
  static Future<bool> setWorkerName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setString(_keyWorkerName, name);
  }
}