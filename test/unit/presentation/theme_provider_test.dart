import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';

void main() {
  Future<ThemeProvider> load(Map<String, Object> saved) async {
    SharedPreferences.setMockInitialValues(saved);
    return ThemeProvider.fromPrefs(await SharedPreferences.getInstance());
  }

  test('follows the device by default', () async {
    expect((await load({})).themeMode, ThemeMode.system);
  });

  test('keeps the choice made with the old dark mode switch', () async {
    expect((await load({'isDarkMode': true})).themeMode, ThemeMode.dark);
    expect((await load({'isDarkMode': false})).themeMode, ThemeMode.light);
  });

  test('saves a new choice, which wins over the old switch', () async {
    final theme = await load({'isDarkMode': true});
    var notified = false;
    theme.addListener(() => notified = true);

    await theme.setThemeMode(ThemeMode.system);

    expect(notified, isTrue);
    expect(ThemeProvider.fromPrefs(await SharedPreferences.getInstance()).themeMode, ThemeMode.system);
  });
}
