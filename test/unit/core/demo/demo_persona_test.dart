import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/core/demo/demo_persona.dart';
import 'package:atomic_momentum/core/dev/year_of_use.dart';
import 'package:atomic_momentum/data/models/habit_model.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';

void main() {
  // Different weekdays, month ends and both clock changes
  final todays = [
    DateTime(2026, 10, 19, 9, 15),
    DateTime(2026, 11, 1, 23, 50),
    DateTime(2027, 2, 28, 0, 30),
    DateTime(2027, 3, 14, 13),
    DateTime(2027, 7, 4, 18, 5),
  ];

  List<Habit> build(DateTime now) => YearOfUse.build(DemoPersona(now), now, deferStreaks: true);
  Habit named(List<Habit> habits, String name) => habits.firstWhere((h) => h.name == name);
  DateTime day(DateTime t) => DateTime(t.year, t.month, t.day);

  test('the same day plans the same example habits', () {
    String plan(DemoPersona p) =>
        [for (final d in p.days) '${d.date}: ${d.visits.map((v) => '${v.hour}:${v.minute} ${v.actions}').join(' | ')}'].join('\n');
    expect(plan(DemoPersona(todays.first)), plan(DemoPersona(todays.first)));
    expect(DemoPersona(todays.first).days, hasLength(DemoPersona.length));
  });

  for (final now in todays) {
    group('ending ${now.toIso8601String().substring(0, 16)}', () {
      late final habits = build(now);
      final today = day(now);

      test('every example habit, every kind, nothing after now', () {
        expect(habits.map((h) => h.name), DemoPersona.names);
        expect(habits.map((h) => h.resetFrequency).toSet(),
            containsAll([ResetFrequency.daily, ResetFrequency.weekly, ResetFrequency.monthly]));
        expect(habits.where((h) => h.isBreak), hasLength(1));
        expect(habits.where((h) => h.scheduledWeekdays != null), isNotEmpty);
        for (final h in habits) {
          expect(h.history.keys.every((d) => !d.isAfter(now)), isTrue, reason: h.name);
        }
      });

      test('half a year and more of history, ending today', () {
        final water = named(habits, DemoPersona.water);
        final first = water.history.keys.reduce((a, b) => a.isBefore(b) ? a : b);
        expect(today.difference(first).inDays, greaterThanOrEqualTo(180));
        expect(water.history.length, greaterThan(150));
      });

      test("today as the tours expect it", () {
        final water = named(habits, DemoPersona.water);
        expect(water.progressForPeriodContaining(today), DemoPersona.waterToday);
        expect(water.target, 8);
        expect(named(habits, DemoPersona.read).progressForPeriodContaining(today), 0);
        expect(named(habits, DemoPersona.read).streak.current, greaterThanOrEqualTo(9));
        final meditate = named(habits, DemoPersona.meditate);
        expect(meditate.streak.atRisk, isTrue, reason: "missed yesterday: Don't miss twice");
        expect(meditate.frozenDays, hasLength(DemoPersona.meditateFrozen.length));
        final social = named(habits, DemoPersona.social);
        expect(social.wasCompletedOnDate(today), isTrue, reason: 'clean today');
        final gym = named(habits, DemoPersona.gym);
        expect(gym.scheduledWeekdays, contains(today.weekday), reason: 'due today, so the card shows');
        expect(named(habits, DemoPersona.callMum).progressForPeriodContaining(today), 0, reason: 'not yet this week');
      });

      test('looks well practised: strong momentum, a vacation week, Journal added later', () {
        final average = habits.map((h) => h.momentum.score).reduce((a, b) => a + b) / habits.length;
        expect(average, greaterThan(60));
        expect(named(habits, DemoPersona.read).momentum.score, greaterThan(80));
        expect(named(habits, DemoPersona.water).pauses, isNotEmpty);
        final journal = named(habits, DemoPersona.journal);
        expect(journal.trackedFrom, DemoPersona(now).date(DemoPersona.journalAdded));
      });
    });
  }

  test('working out streaks once at the end builds exactly the same habits', () {
    for (final now in todays) {
      final plain = YearOfUse.build(DemoPersona(now), now);
      final deferred = YearOfUse.build(DemoPersona(now), now, deferStreaks: true);
      // Everything but the ids (made from a running count) and when it was written
      String stored(List<Habit> habits) =>
          jsonEncode([for (final h in habits) HabitModel.fromDomain(h).toJson()
            ..remove('id')
            ..remove('_serializedAt')]);
      expect(stored(deferred), stored(plain), reason: '$now');
      expect([for (final h in deferred) h.streak], [for (final h in plain) h.streak], reason: '$now');
    }
  });

  test('builds quickly enough to overlap the launch intro', () {
    // The fastest of three, so a busy machine doesn't fail it; a debug VM in
    // a test, where the app builds it in an isolate during the intro
    var fastest = 1 << 30;
    for (var i = 0; i < 3; i++) {
      final watch = Stopwatch()..start();
      build(todays.first);
      if (watch.elapsedMilliseconds < fastest) fastest = watch.elapsedMilliseconds;
    }
    expect(fastest, lessThan(500));
  });
}
