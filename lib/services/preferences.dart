import 'package:shared_preferences/shared_preferences.dart';

class AppPrefs {
  static const _keyMoveRule = 'move_rule'; // easy, medium, hard
  static const _keyTubeCount = 'tube_count';
  static const _keyThemeMode = 'theme_mode'; // light, dark, system
  static const _keySound = 'sound_enabled';
  static const _keyHaptics = 'haptics_enabled';

  static Future<void> saveMoveRule(String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyMoveRule, value);
  }

  static Future<String?> loadMoveRule() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_keyMoveRule);
  }

  static Future<void> saveTubeCount(int value) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_keyTubeCount, value);
  }

  static Future<int?> loadTubeCount() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_keyTubeCount);
  }

  static Future<void> saveThemeMode(String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyThemeMode, value);
  }

  static Future<String?> loadThemeMode() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_keyThemeMode);
  }

  static Future<void> saveSoundEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keySound, value);
  }

  static Future<bool> loadSoundEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_keySound) ?? true;
  }

  static Future<void> saveHapticsEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyHaptics, value);
  }

  static Future<bool> loadHapticsEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_keyHaptics) ?? true;
  }
}
