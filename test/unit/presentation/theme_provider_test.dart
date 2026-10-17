import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/theme/app_palette.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';

void main() {
  Future<ThemeProvider> load(Map<String, Object> saved) async {
    SharedPreferences.setMockInitialValues(saved);
    return ThemeProvider.fromPrefs(await SharedPreferences.getInstance());
  }

  test('follows the device by default, with Light by day', () async {
    final theme = await load({});
    expect(theme.appearance, Appearance.system);
    expect(theme.dayTheme, AppTheme.light);
  });

  test('keeps the choice made with the old dark mode switch', () async {
    expect((await load({'isDarkMode': true})).appearance, Appearance.dark);
    expect((await load({'isDarkMode': false})).appearance, Appearance.light);
  });

  test('keeps choices saved before Sepia existed', () async {
    // Earlier versions saved ThemeMode names under the same key
    expect((await load({'themeMode': 'system'})).appearance, Appearance.system);
    expect((await load({'themeMode': 'light'})).appearance, Appearance.light);
    expect((await load({'themeMode': 'dark'})).appearance, Appearance.dark);
  });

  test('an unknown saved value falls back safely', () async {
    final theme = await load({'themeMode': 'neon', 'dayTheme': 'dark'});
    expect(theme.appearance, Appearance.system);
    // Dark isn't a day theme
    expect(theme.dayTheme, AppTheme.light);
  });

  test('saves a new choice, which wins over the old switch', () async {
    final theme = await load({'isDarkMode': true});
    var notified = false;
    theme.addListener(() => notified = true);

    await theme.setAppearance(Appearance.sepia);

    expect(notified, isTrue);
    expect(ThemeProvider.fromPrefs(await SharedPreferences.getInstance()).appearance, Appearance.sepia);
  });

  test('saves the day theme', () async {
    final theme = await load({});
    await theme.setDayTheme(AppTheme.sepia);
    expect(ThemeProvider.fromPrefs(await SharedPreferences.getInstance()).dayTheme, AppTheme.sepia);
  });

  group('resolves the theme to draw', () {
    Future<AppTheme> themeFor(WidgetTester tester, ThemeProvider provider, Brightness device) async {
      late AppTheme theme;
      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(platformBrightness: device),
        child: Builder(builder: (context) {
          theme = provider.themeIn(context);
          return const SizedBox();
        }),
      ));
      return theme;
    }

    testWidgets('System: the day theme in light mode, Dark at night', (tester) async {
      final provider = ThemeProvider(Appearance.system);
      expect(await themeFor(tester, provider, Brightness.light), AppTheme.light);
      expect(await themeFor(tester, provider, Brightness.dark), AppTheme.dark);

      final sepiaByDay = ThemeProvider(Appearance.system, null, AppTheme.sepia);
      expect(await themeFor(tester, sepiaByDay, Brightness.light), AppTheme.sepia);
      expect(await themeFor(tester, sepiaByDay, Brightness.dark), AppTheme.dark);
    });

    testWidgets('a chosen theme ignores the device', (tester) async {
      for (final (appearance, theme) in [
        (Appearance.light, AppTheme.light),
        (Appearance.sepia, AppTheme.sepia),
        (Appearance.dark, AppTheme.dark),
      ]) {
        for (final device in Brightness.values) {
          expect(await themeFor(tester, ThemeProvider(appearance), device), theme, reason: '$appearance on $device');
        }
      }
    });
  });
}
