import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light, dark, or following the device (the default, as iOS apps do).
class ThemeProvider extends ChangeNotifier {
  static const _modeKey = 'themeMode';

  /// Saved by earlier versions, which only had a light/dark switch.
  static const _legacyDarkKey = 'isDarkMode';

  final SharedPreferences? _prefs;
  ThemeMode _themeMode;

  ThemeProvider(this._themeMode, [this._prefs]);

  /// Reads the saved choice. An old dark/light switch keeps its value;
  /// people who never chose follow the device.
  factory ThemeProvider.fromPrefs(SharedPreferences prefs) {
    final saved = prefs.getString(_modeKey);
    final mode = ThemeMode.values.where((m) => m.name == saved).firstOrNull ??
        switch (prefs.getBool(_legacyDarkKey)) {
          true => ThemeMode.dark,
          false => ThemeMode.light,
          null => ThemeMode.system,
        };
    return ThemeProvider(mode, prefs);
  }

  ThemeMode get themeMode => _themeMode;

  /// Whether to draw dark, resolving System from the device setting.
  bool isDarkIn(BuildContext context) =>
      _themeMode == ThemeMode.dark ||
      (_themeMode == ThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);
  }
}
