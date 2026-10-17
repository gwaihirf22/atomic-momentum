import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/core/theme/app_palette.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/presentation/widgets/color_picker.dart';

void main() {
  const palettes = [AppPalette.light, AppPalette.sepia, AppPalette.dark];

  // Every color a user can give a habit or category
  final stored = {
    for (final c in HabitColor.predefinedColors) c.color,
    for (final c in ColorPalette.all) c.color,
    for (final c in Category.defaults) Color(c.colorValue),
  };

  group('text is readable (WCAG AA, 4.5:1)', () {
    for (final palette in palettes) {
      test(palette.theme.name, () {
        for (final (name, color) in [('text', palette.text), ('textSecondary', palette.textSecondary)]) {
          for (final (bgName, bg) in [('background', palette.background), ('surface', palette.surface)]) {
            expect(AppPalette.contrast(color, bg), greaterThanOrEqualTo(4.5), reason: '$name on $bgName');
          }
        }
        expect(AppPalette.contrast(palette.good, palette.goodTint), greaterThanOrEqualTo(4.5), reason: 'good');
        expect(AppPalette.contrast(palette.gold, palette.goldTint), greaterThanOrEqualTo(4.5), reason: 'gold');
        expect(AppPalette.contrast(palette.warning, palette.surface), greaterThanOrEqualTo(3), reason: 'warning');
        expect(AppPalette.contrast(palette.danger, palette.surface), greaterThanOrEqualTo(3), reason: 'danger');
        expect(AppPalette.contrast(palette.accent, palette.surface), greaterThanOrEqualTo(3), reason: 'accent');
      });
    }
  });

  group('every habit color shows up on cards (3:1 for graphics)', () {
    for (final palette in palettes) {
      test(palette.theme.name, () {
        for (final color in stored) {
          final drawn = palette.habitColor(color);
          expect(AppPalette.contrast(drawn, palette.surface), greaterThanOrEqualTo(3),
              reason: '${color.toARGB32().toRadixString(16)} drawn as ${drawn.toARGB32().toRadixString(16)}');
        }
      });
    }
  });

  test('colors that already show up are left alone in Light and Dark', () {
    // Indigo is readable on white and blue on dark, so they're drawn exactly as stored
    expect(AppPalette.light.habitColor(HabitColor.indigo.color), HabitColor.indigo.color);
    expect(AppPalette.dark.habitColor(HabitColor.blue.color), HabitColor.blue.color);
  });

  test('Light deepens pale colors and Dark lifts dark ones', () {
    final yellow = HabitColor.yellow.color;
    expect(AppPalette.light.habitColor(yellow).computeLuminance(), lessThan(yellow.computeLuminance()));
    final indigo = HabitColor.indigo.color;
    expect(AppPalette.dark.habitColor(indigo).computeLuminance(), greaterThan(indigo.computeLuminance()));
  });

  test('Sepia softens colors', () {
    for (final color in HabitColor.predefinedColors.map((c) => c.color)) {
      final original = HSLColor.fromColor(color);
      if (original.saturation < 0.2) continue;
      expect(HSLColor.fromColor(AppPalette.sepia.habitColor(color)).saturation, lessThan(original.saturation),
          reason: color.toARGB32().toRadixString(16));
    }
  });

  test('marks on a filled color stay readable', () {
    for (final palette in palettes) {
      for (final color in stored) {
        final fill = palette.habitColor(color);
        expect(AppPalette.contrast(palette.onColor(fill), fill), greaterThanOrEqualTo(3),
            reason: '${palette.theme.name}: on ${fill.toARGB32().toRadixString(16)}');
      }
    }
  });

  test('a tint sits on the surface, in the habit color', () {
    for (final palette in palettes) {
      final tint = palette.tint(HabitColor.blue.color);
      expect(tint.a, 1.0);
      expect(tint, isNot(palette.surface));
      expect(AppPalette.contrast(palette.text, tint), greaterThanOrEqualTo(4.5), reason: palette.theme.name);
    }
  });

  test('each theme has its own palette', () {
    for (final theme in AppTheme.values) {
      expect(AppPalette.forTheme(theme).theme, theme);
    }
    expect(AppPalette.sepia.brightness, Brightness.light);
    expect(AppPalette.dark.brightness, Brightness.dark);
  });

  testWidgets('outside the app theme, falls back by brightness', (tester) async {
    late AppPalette palette;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      home: Builder(builder: (context) {
        palette = AppPalette.of(context);
        return const SizedBox();
      }),
    ));
    expect(palette, AppPalette.dark);
  });
}
