import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Screens and widgets take every color from the palette (AppPalette.of), so
/// a theme is just a palette. A hardcoded color, or a choice made with a
/// light/dark bool, would look wrong in at least one of Light, Sepia and Dark.
void main() {
  // The color picker's families are stored colors offered to the user (shown
  // through the palette), and its rainbow and hue wheel show raw hues on purpose
  const allowed = {'lib/presentation/widgets/color_picker.dart'};

  final banned = {
    r'\bisDark\b': 'a light/dark bool',
    r'\bIOSColors\.': 'IOSColors',
    r'\bCupertinoColors\.': "Cupertino's light/dark colors",
    r'\bCupertinoDynamicColor\b': "Cupertino's light/dark colors",
    r'\bColor\(0x': 'a hardcoded color',
    r'\bColors\.(?!transparent\b)': "a Material color",
  };

  test('screens and widgets take their colors from the palette', () {
    final offenders = <String>[];
    for (final dir in ['lib/screens', 'lib/presentation']) {
      for (final file in Directory(dir).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart') || allowed.contains(file.path)) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          for (final entry in banned.entries) {
            if (RegExp(entry.key).hasMatch(lines[i])) offenders.add('${file.path}:${i + 1} uses ${entry.value}');
          }
        }
      }
    }
    expect(offenders, isEmpty, reason: 'Use AppPalette.of(context) (lib/core/theme/app_palette.dart)');
  });
}
