import 'package:shared_preferences/shared_preferences.dart';

class AppPrefs {
  static const _keepSignedInKey = 'keep_signed_in';

  static Future<bool> keepSignedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keepSignedInKey) ?? true;
  }

  static Future<void> setKeepSignedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keepSignedInKey, value);
  }
}

