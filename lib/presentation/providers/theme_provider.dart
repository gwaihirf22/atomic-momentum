import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_palette.dart';

/// What the Appearance setting can be. System (the default, as iOS apps do)
/// follows the device: the chosen day theme in light mode, Dark at night.
enum Appearance { system, light, sepia, dark }

/// The Appearance setting and the palette it gives.
class ThemeProvider extends ChangeNotifier {
  /// Holds an [Appearance] name; earlier versions saved ThemeMode names here
  /// (system, light, dark), which are the same names.
  static const _modeKey = 'themeMode';

  /// Which light theme System uses by day.
  static const _dayThemeKey = 'dayTheme';

  /// Saved by earlier versions, which only had a light/dark switch.
  static const _legacyDarkKey = 'isDarkMode';

  /// The themes System can use by day.
  static const dayThemes = [AppTheme.light, AppTheme.sepia];

  final SharedPreferences? _prefs;
  Appearance _appearance;
  AppTheme _dayTheme;

  /// Under System, days are Sepia until the person picks Light.
  static const defaultDayTheme = AppTheme.sepia;

  ThemeProvider(this._appearance, [this._prefs, this._dayTheme = defaultDayTheme]);

  /// Reads the saved choice. An old dark/light switch keeps its value;
  /// people who never chose follow the device, Sepia by day.
  factory ThemeProvider.fromPrefs(SharedPreferences prefs) {
    final saved = prefs.getString(_modeKey);
    final appearance = Appearance.values.where((a) => a.name == saved).firstOrNull ??
        switch (prefs.getBool(_legacyDarkKey)) {
          true => Appearance.dark,
          false => Appearance.light,
          null => Appearance.system,
        };
    final savedDay = prefs.getString(_dayThemeKey);
    final dayTheme = dayThemes.where((t) => t.name == savedDay).firstOrNull ?? defaultDayTheme;
    return ThemeProvider(appearance, prefs, dayTheme);
  }

  Appearance get appearance => _appearance;

  /// The light theme System uses by day: Light or Sepia.
  AppTheme get dayTheme => _dayTheme;

  /// The theme to draw, resolving System from the device setting.
  AppTheme themeIn(BuildContext context) => switch (_appearance) {
        Appearance.light => AppTheme.light,
        Appearance.sepia => AppTheme.sepia,
        Appearance.dark => AppTheme.dark,
        Appearance.system =>
          MediaQuery.platformBrightnessOf(context) == Brightness.dark ? AppTheme.dark : _dayTheme,
      };

  AppPalette paletteIn(BuildContext context) => AppPalette.forTheme(themeIn(context));

  Future<void> setAppearance(Appearance appearance) async {
    if (_appearance == appearance) return;
    _appearance = appearance;
    notifyListeners();
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, appearance.name);
  }

  Future<void> setDayTheme(AppTheme theme) async {
    assert(dayThemes.contains(theme));
    if (_dayTheme == theme) return;
    _dayTheme = theme;
    notifyListeners();
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_dayThemeKey, theme.name);
  }
}
