import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/services/health_sync_service.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/health_link.dart';

import '../../../helpers/fake_health_source.dart';

/// The bookkeeping behind Health: what the app wrote, what Health said.
void main() {
  late SharedPreferences prefs;
  late FakeHealthSource health;
  late HealthSyncService sync;
  final morning = DateTime(2026, 10, 14, 9);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    health = FakeHealthSource();
    sync = HealthSyncService(source: () => health, prefs: prefs);
  });

  Habit water({Map<DateTime, int> history = const {}}) => Habit.create(
        name: 'Water',
        target: 8,
        units: 'glasses',
        color: HabitColor.blue,
        categoryId: BuiltInCategoryIds.body,
      ).copyWith(
        history: history,
        health: HealthLink(metric: HealthMetric.water, logToHealth: true, linkedOn: DateTime(2026, 10, 1)),
      );

  test('what the app wrote is kept a week; unreadable records are ignored', () async {
    final today = DateTime(2026, 10, 14);
    await withClock(Clock.fixed(morning), () async {
      final before = water();
      final after = before.copyWith(history: {today: 2});
      expect(await sync.logChange(before, after), isNull);
      expect(jsonDecode(prefs.getString(HealthSyncService.writesKey)!) as List, hasLength(1));
    });
    // Nine days on, the record is gone when the next write saves
    await withClock(Clock.fixed(morning.add(const Duration(days: 9))), () async {
      final day = DateTime(2026, 10, 23);
      final h = water();
      await sync.logChange(h, h.copyWith(history: {day: 1}));
      final kept = jsonDecode(prefs.getString(HealthSyncService.writesKey)!) as List;
      expect(kept, hasLength(1), reason: 'the old one dropped');
    });
    await prefs.setString(HealthSyncService.writesKey, '{not json');
    await withClock(Clock.fixed(morning), () async {
      final h = water(history: {DateTime(2026, 10, 14): 2});
      expect(await sync.logChange(h, h.copyWith(history: {DateTime(2026, 10, 14): 1})),
          'That came from Apple Health. Change it there.', reason: 'nothing of its own to take back');
    });
  });

  test("yesterday's water can't be taken back after midnight, and says so", () async {
    final yesterday = DateTime(2026, 10, 13);
    await withClock(Clock.fixed(DateTime(2026, 10, 13, 21)), () async {
      final h = water();
      await sync.logChange(h, h.copyWith(history: {yesterday: 2}));
    });
    await withClock(Clock.fixed(morning), () async {
      // − only ever mirrors today: a past day's change isn't taken back
      final h = water(history: {yesterday: 2});
      expect(await sync.logChange(h, h.copyWith(history: {yesterday: 0})), isNull);
      expect(health.removed, isEmpty);
    });
  });

  test('changing what a habit is linked to keeps when it was linked', () {
    final link = HealthLink(metric: HealthMetric.water, linkedOn: DateTime(2026, 10, 1));
    expect(link.copyWith(metric: HealthMetric.mindfulMinutes).linkedOn, DateTime(2026, 10, 1));
  });

  test("a sync whose read fails still counts as a sync, and there's no floor from it", () async {
    await withClock(Clock.fixed(morning), () async {
      final h = water();
      final changes = await sync.changes([h]);
      expect(changes, isEmpty);
      expect(sync.lastSync, morning);
      expect(sync.floorOn(h, DateTime(2026, 10, 14)), 0);
    });
  });
}
