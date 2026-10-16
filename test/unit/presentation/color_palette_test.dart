import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/presentation/widgets/color_picker.dart';

void main() {
  test('the palette has 72 distinct colors in 12 families', () {
    expect(ColorPalette.families, hasLength(12));
    expect(ColorPalette.all, hasLength(72));
    expect(ColorPalette.all.map((c) => c.value).toSet(), hasLength(72));
  });

  test('shade 500 uses the predefined name, so existing colors are found', () {
    final blue = ColorPalette.all.firstWhere((c) => c.value == HabitColor.blue.value);
    expect(blue.name, 'Blue');
    expect(ColorPalette.resolve(HabitColor.teal.value), HabitColor.teal);
    expect(ColorPalette.all.firstWhere((c) => c.value == Colors.teal[700]!.value).name, 'Teal 700');
  });

  test('unknown colors resolve as Custom', () {
    final custom = ColorPalette.resolve(0xFF123456);
    expect(custom.name, 'Custom');
    expect(custom.hex, '#123456');
  });

  test('suggestions put recent colors first, then basics, without duplicates', () {
    final suggestions = ColorPalette.suggestions([Colors.teal[700]!.value, HabitColor.green.value, HabitColor.green.value]);

    expect(suggestions.first.name, 'Teal 700');
    expect(suggestions[1], HabitColor.green);
    expect(suggestions.map((c) => c.value).toSet().length, suggestions.length);
    expect(suggestions.map((c) => c.value), contains(HabitColor.blue.value));
  });
}
