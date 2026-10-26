import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Screens read habits, settings, quotes and Health through the world they
/// show (the providers above them, [WorldScope.healthSourceOf]), so a
/// tour's example world can never touch the person's own. Reaching past it
/// to the app-wide instances is allowed only where listed, each with why.
void main() {
  const guarded = r'(get|sl)<(SharedPreferences|AchievementStore|FreezeBank|HabitProvider|HealthSource|CategoryProvider|QuoteProvider|SettingsProvider)>';
  const allowed = {
    // Developer tools act on the person's own data (hidden in an example world)
    'lib/presentation/dev/year_of_use_tiles.dart',
    // Celebrations and the freeze bank (never in an example world)
    'lib/screens/ios_main_navigation.dart',
    // Where the world's Health and settings come from
    'lib/presentation/tour/world_scope.dart',
    // How-to's example world copies the person's settings (read only)
    'lib/screens/how_to_screen.dart',
    // Sync works on the person's own data, above the world switch
    'lib/presentation/sync/sync_host.dart',
  };

  test('screens never reach past their world to the person\'s data', () {
    final offenders = <String>[];
    for (final dir in ['lib/screens', 'lib/presentation']) {
      for (final file in Directory(dir).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart') || allowed.contains(file.path)) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (RegExp(guarded).hasMatch(lines[i]) && !lines[i].trimLeft().startsWith('//')) {
            offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
    }
    expect(offenders, isEmpty, reason: 'Read these through the world (providers, WorldScope) instead');
  });
}
