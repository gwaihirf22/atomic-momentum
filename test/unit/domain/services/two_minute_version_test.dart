import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/core/validation/habit_validator.dart';
import 'package:atomic_momentum/data/models/habit_model.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/habit_schedule.dart';
import 'package:atomic_momentum/domain/entities/reminder_settings.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/entities/streak_warning_settings.dart';
import 'package:atomic_momentum/domain/entities/two_minute_version.dart';
import 'package:atomic_momentum/domain/services/momentum_calculator.dart';
import 'package:atomic_momentum/domain/services/reminder_planner.dart';
import 'package:atomic_momentum/domain/services/streak_calculator.dart';
import 'package:atomic_momentum/domain/services/streak_warning_planner.dart';
import '../../../helpers/test_data.dart';

void main() {
  // 2024-01-15 is a Monday
  final monday = DateTime(2024, 1, 15);
  final noon = DateTime(2024, 1, 15, 12);
  DateTime jan(int day) => DateTime(2024, 1, day);

  const shoes = TwoMinuteVersion(description: 'Put on running shoes');

  final daily = HabitSchedule(frequency: ResetFrequency.daily, anchor: monday);

  group('streaks', () {
    test('a two-minute day keeps the streak and grows it', () {
      final streak = StreakCalculator.calculate(
        history: {jan(13): 2},
        target: 2,
        schedule: daily,
        now: noon,
        twoMinute: TwoMinuteLog(days: {jan(14)}),
      );
      expect(streak.current, 2);
      expect(streak.atRisk, isFalse);
    });

    test('without it, the same day is a miss', () {
      final streak = StreakCalculator.calculate(history: {jan(13): 2}, target: 2, schedule: daily, now: noon);
      expect(streak.atRisk, isTrue);
    });

    test('a two-minute tap today clears "Don\'t miss twice"', () {
      final streak = StreakCalculator.calculate(
        history: {jan(12): 2, jan(13): 2},
        target: 2,
        schedule: daily,
        now: noon,
        twoMinute: TwoMinuteLog(days: {jan(15)}),
      );
      expect(streak.current, 3);
      expect(streak.atRisk, isFalse);
    });

    test('a two-minute tap on a rest day does nothing', () {
      final monWedFri = HabitSchedule(frequency: ResetFrequency.daily, anchor: monday, weekdays: const [1, 3, 5]);
      final history = {jan(10): 1, jan(12): 1};
      final without = StreakCalculator.calculate(history: history, target: 1, schedule: monWedFri, now: noon);
      final withRestDayTap = StreakCalculator.calculate(
        history: history,
        target: 1,
        schedule: monWedFri,
        now: noon,
        twoMinute: TwoMinuteLog(days: {jan(13)}),
      );
      expect(withRestDayTap, without);
    });

    test('reaching the two-minute amount counts by itself', () {
      final streak = StreakCalculator.calculate(
        history: {jan(13): 1, jan(14): 1},
        target: 8,
        schedule: daily,
        now: noon,
        twoMinute: const TwoMinuteLog(minimum: 1),
      );
      expect(streak.current, 2);
    });

    test('one tap keeps a whole week', () {
      final weekly = HabitSchedule(frequency: ResetFrequency.weekly, anchor: monday);
      final history = {jan(2): 3};
      final kept = StreakCalculator.calculate(
        history: history,
        target: 3,
        schedule: weekly,
        now: noon,
        twoMinute: TwoMinuteLog(days: {jan(10)}),
      );
      expect(kept.current, 2);
      expect(kept.atRisk, isFalse);

      final missed = StreakCalculator.calculate(history: history, target: 3, schedule: weekly, now: noon);
      expect(missed.atRisk, isTrue);
    });

    test('a two-minute tap today moves the streak deadline a day later', () {
      final history = {jan(13): 1, jan(14): 1};
      final before = StreakCalculator.streakDeadline(history: history, target: 1, schedule: daily, now: noon);
      final after = StreakCalculator.streakDeadline(
        history: history,
        target: 1,
        schedule: daily,
        now: noon,
        twoMinute: TwoMinuteLog(days: {jan(15)}),
      );
      expect(before, jan(17));
      expect(after, jan(18));
    });
  });

  group('momentum', () {
    final start = DateTime(2023, 6, 1);
    final now = DateTime(2024, 1, 15, 12);

    Set<DateTime> everyDaySince(DateTime from, DateTime until) => {
          for (var d = from; d.isBefore(until); d = DateTime(d.year, d.month, d.day + 1)) d,
        };

    test('two-minute days alone settle around half', () {
      final score = MomentumCalculator.calculate(
        history: const {},
        target: 1,
        schedule: daily,
        start: start,
        now: now,
        twoMinute: TwoMinuteLog(days: everyDaySince(start, monday)),
      ).score;
      expect(score, closeTo(50, 2));
    });

    test('logged progress above half counts more than the two-minute version', () {
      final tinyOnly = MomentumCalculator.calculate(
        history: const {},
        target: 4,
        schedule: daily,
        start: jan(10),
        now: noon,
        twoMinute: TwoMinuteLog(days: {jan(14)}),
      ).score;
      final threeOfFour = MomentumCalculator.calculate(
        history: {jan(14): 3},
        target: 4,
        schedule: daily,
        start: jan(10),
        now: noon,
        twoMinute: TwoMinuteLog(days: {jan(14)}),
      ).score;
      expect(threeOfFour, greaterThan(tinyOnly));
      expect(tinyOnly, greaterThan(0));
    });

    test('a two-minute tap today never lowers a high score', () {
      final history = {for (final d in everyDaySince(start, monday)) d: 1};
      double score(TwoMinuteLog log) => MomentumCalculator.calculate(
            history: history,
            target: 1,
            schedule: daily,
            start: start,
            now: noon,
            twoMinute: log,
          ).score;
      expect(score(TwoMinuteLog(days: {monday})), score(TwoMinuteLog.none));
    });

    test('a two-minute tap today raises a low score at once', () {
      double score(TwoMinuteLog log) => MomentumCalculator.calculate(
            history: const {},
            target: 1,
            schedule: daily,
            start: jan(10),
            now: noon,
            twoMinute: log,
          ).score;
      expect(score(TwoMinuteLog(days: {monday})), greaterThan(score(TwoMinuteLog.none)));
    });

    test('a two-minute day that has ended holds a high score where it was; a miss lowers it', () {
      // Every day done until yesterday (a Sunday); yesterday kept small, missed or done
      final sunday = jan(14);
      final before = {for (final d in everyDaySince(start, sunday)) d: 1};
      double scoreAt(DateTime at, {Map<DateTime, int>? history, TwoMinuteLog log = TwoMinuteLog.none}) =>
          MomentumCalculator.calculate(
            history: history ?? before,
            target: 1,
            schedule: daily,
            start: start,
            now: at,
            twoMinute: log,
          ).score;
      final saturdayNight = DateTime(2024, 1, 13, 23, 59);
      final high = scoreAt(saturdayNight);
      expect(high, greaterThan(80));

      final tiny = scoreAt(noon, log: TwoMinuteLog(days: {sunday}));
      final missed = scoreAt(noon);
      final done = scoreAt(noon, history: {...before, sunday: 1});
      expect(tiny, closeTo(high, 0.001), reason: 'held');
      expect(missed, lessThan(high));
      expect(done, greaterThan(high));
    });

    test('below half, a two-minute day that has ended lifts the score toward half', () {
      final sunday = jan(14);
      double score(TwoMinuteLog log) => MomentumCalculator.calculate(
            history: {jan(10): 1},
            target: 1,
            schedule: daily,
            start: jan(10),
            now: noon,
            twoMinute: log,
          ).score;
      expect(score(TwoMinuteLog(days: {sunday})), greaterThan(score(TwoMinuteLog.none)));
    });
  });

  group('Habit', () {
    Habit habit({int target = 1, Map<DateTime, int>? history, TwoMinuteVersion? tiny = shoes}) =>
        TestData.createTestHabit(name: 'Run', target: target, history: history ?? {})
            .copyWith(twoMinute: tiny)
            .refresh(noon);

    test('marking the two-minute version keeps the day; unmarking undoes it', () {
      final marked = habit(history: {jan(14): 1}).setTwoMinuteForDate(monday, true).refresh(noon);
      expect(marked.twoMinuteDays, {monday});
      expect(marked.isTwoMinuteOn(monday), isTrue);
      expect(marked.wasKeptOnDate(monday), isTrue);
      expect(marked.wasCompletedOnDate(monday), isFalse);
      expect(marked.streak.current, 2);

      final unmarked = marked.setTwoMinuteForDate(monday, false).refresh(noon);
      expect(unmarked.twoMinuteDays, isEmpty);
      expect(unmarked.streak.current, 1);
    });

    test('a completed day is not a two-minute day', () {
      final done = habit(history: {monday: 1}).setTwoMinuteForDate(monday, true);
      expect(done.isTwoMinuteOn(monday), isFalse);
      expect(done.usedTwoMinuteButtonOn(monday), isTrue);
    });

    test('the two-minute amount marks the day by itself', () {
      final water = habit(target: 8, history: {monday: 1}, tiny: const TwoMinuteVersion(description: 'One glass', minimum: 1));
      expect(water.twoMinuteReachedByAmountOn(monday), isTrue);
      expect(water.isTwoMinuteOn(monday), isTrue);
      expect(water.fractionDoneOn(monday), 0.5);
    });

    test('a two-minute day fills at least half a ring', () {
      final tiny = habit(target: 4).setTwoMinuteForDate(monday, true);
      expect(tiny.fractionDoneOn(monday), 0.5);
      final more = habit(target: 4, history: {monday: 3}).setTwoMinuteForDate(monday, true);
      expect(more.fractionDoneOn(monday), 0.75);
    });

    test('future days cannot be marked', () {
      expect(() => habit().setTwoMinuteForDate(DateTime.now().add(const Duration(days: 2)), true),
          throwsArgumentError);
    });

    test('saves and loads the version and its days; older habits load without them', () {
      final marked = habit(tiny: const TwoMinuteVersion(description: 'One glass', minimum: 1, showOnCard: false))
          .setTwoMinuteForDate(jan(14), true);

      final viaEntity = Habit.fromJson(marked.toJson());
      expect(viaEntity.twoMinute, marked.twoMinute);
      expect(viaEntity.twoMinuteDays, {jan(14)});

      final viaModel = HabitModel.fromJson(HabitModel.fromDomain(marked).toCompactJson()).toDomain();
      expect(viaModel.twoMinute, marked.twoMinute);
      expect(viaModel.twoMinuteDays, {jan(14)});
      expect(marked.toJson()['twoMinuteDays'], ['2024-01-14']);

      final old = HabitModel.fromDomain(habit(tiny: null)).toCompactJson()
        ..remove('twoMinute')
        ..remove('twoMinuteDays');
      final loaded = HabitModel.fromJson(old);
      expect(loaded.twoMinute, isNull);
      expect(loaded.twoMinuteDays, isEmpty);
    });

    test('updateDetails can set, keep and remove the version', () {
      final plain = habit(tiny: null);
      final set = plain.updateDetails(twoMinute: shoes);
      expect(set.twoMinute, shoes);
      expect(set.updateDetails(name: 'Jog').twoMinute, shoes);
      expect(set.updateDetails(removeTwoMinute: true).twoMinute, isNull);
    });
  });

  group('validation', () {
    List<String> errors(TwoMinuteVersion tiny, {int target = 8}) =>
        HabitValidator.validate(TestData.createTestHabit(target: target, progress: 0).copyWith(twoMinute: tiny)).errors;

    test('the description is required and at most 40 characters', () {
      expect(errors(shoes), isEmpty);
      expect(errors(const TwoMinuteVersion(description: '  ')), isNotEmpty);
      expect(errors(TwoMinuteVersion(description: 'x' * 41)), isNotEmpty);
    });

    test('the minimum is at least 1 and below the target', () {
      expect(errors(const TwoMinuteVersion(description: 'One glass', minimum: 1)), isEmpty);
      expect(errors(const TwoMinuteVersion(description: 'One glass', minimum: 0)), isNotEmpty);
      expect(errors(const TwoMinuteVersion(description: 'One glass', minimum: 8)), isNotEmpty);
    });
  });

  group('notifications', () {
    test("a two-minute tap drops that day's reminder", () {
      final eightAm = DateTime(2024, 1, 15, 8);
      final run = TestData.createTestHabit(
        name: 'Run',
        target: 1,
        reminder: ReminderSettings.smart(time: const TimeOfDay(hour: 9, minute: 0)),
      ).copyWith(twoMinute: shoes, twoMinuteDays: {monday});

      final first = ReminderPlanner.plan(run, now: eightAm).first;
      expect(first.at, DateTime(2024, 1, 16, 9));
    });

    test('no streak warning after a two-minute tap rescues a streak at risk', () {
      final atRisk = TestData.createTestHabit(name: 'Run', target: 1, history: {jan(13): 1})
          .copyWith(twoMinute: shoes)
          .refresh(noon);
      final warning = StreakWarningPlanner.plan(atRisk, StreakWarningSettings.defaults, noon).single;
      expect(warning.at, DateTime(2024, 1, 15, 20));

      final rescued = atRisk.copyWith(twoMinuteDays: {monday}).refresh(noon);
      final next = StreakWarningPlanner.plan(rescued, StreakWarningSettings.defaults, noon).single;
      expect(next.at.isAfter(DateTime(2024, 1, 16)), isTrue);
    });

    test('the warning suggests the two-minute version', () {
      final habit = TestData.createTestHabit(name: 'Run', target: 1, history: {jan(13): 1})
          .copyWith(twoMinute: shoes)
          .refresh(noon);
      final warning = StreakWarningPlanner.plan(habit, StreakWarningSettings.defaults, noon).single;
      expect(warning.body, endsWith('Short on time? Even 2 minutes counts: Put on running shoes.'));
    });
  });
}
