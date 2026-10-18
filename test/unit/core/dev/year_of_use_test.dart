import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/dev/year_of_use.dart';
import 'package:atomic_momentum/core/dev/year_persona.dart';
import 'package:atomic_momentum/core/services/achievement_store.dart';
import 'package:atomic_momentum/data/datasources/shared_preferences_datasource.dart';

void main() {
  final now = DateTime(2026, 10, 18, 10, 30);

  test('the persona plans the same year every time', () {
    String plan(YearPersona p) => [for (final d in p.days) '${d.date}: ${d.visits.map((v) => '${v.hour}:${v.minute} ${v.actions}').join(' | ')}'].join('\n');
    expect(plan(YearPersona(DateTime(2026, 10, 19))), plan(YearPersona(DateTime(2026, 10, 19))));
    expect(YearPersona(DateTime(2026, 10, 19)).days, hasLength(YearPersona.length));
  });

  test('a year ends today, with nothing after now', () {
    final habits = YearOfUse.build(YearOfUse.personaEnding(now), now);
    expect(habits.map((h) => h.name), containsAll([YearPersona.water, YearPersona.smoking, YearPersona.journal]));
    expect(habits.map((h) => h.name), isNot(contains(YearPersona.spanish)), reason: 'deleted in the summer');
    for (final h in habits) {
      expect(h.history.keys.every((d) => !d.isAfter(now)), isTrue, reason: h.name);
      expect(h.lastUpdatedDate.isAfter(now), isFalse, reason: h.name);
    }
    final water = habits.firstWhere((h) => h.name == YearPersona.water);
    expect(water.history.length, greaterThan(250));
  });

  group('load and put back', () {
    late SharedPreferences prefs;
    final mine = {
      SharedPreferencesDataSource.habitsKey: '[]',
      AchievementStore.key: ['streak_7_x'],
      'themeMode': 'dark',
    };

    setUp(() async {
      SharedPreferences.setMockInitialValues(Map<String, Object>.from(mine));
      prefs = await SharedPreferences.getInstance();
    });

    Map<String, Object?> stored() => {for (final k in prefs.getKeys()) k: prefs.get(k)};

    test('loads a year, filing its achievements as seen', () async {
      await withClock(Clock.fixed(now), () => YearOfUse.load(prefs, now));
      final habits = jsonDecode(prefs.getString(SharedPreferencesDataSource.habitsKey)!) as List;
      expect(habits.length, greaterThan(8));
      expect(prefs.getStringList(AchievementStore.key)!.length, greaterThan(10));
      expect(prefs.getString('themeMode'), 'dark', reason: 'settings are left alone');
      expect(YearOfUse.hasBackup(prefs), isTrue);
    });

    test('putting back restores exactly what was there', () async {
      final before = stored();
      await withClock(Clock.fixed(now), () => YearOfUse.load(prefs, now));
      // Loading again keeps the first backup, not the loaded year
      await withClock(Clock.fixed(now), () => YearOfUse.load(prefs, now));
      await YearOfUse.restore(prefs);
      expect(stored(), before);
      expect(YearOfUse.hasBackup(prefs), isFalse);
    });

    test('with nothing loaded there is nothing to put back', () async {
      final before = stored();
      await YearOfUse.restore(prefs);
      expect(stored(), before);
    });
  });
}
