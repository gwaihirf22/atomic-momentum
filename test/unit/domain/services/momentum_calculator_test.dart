import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/habit_schedule.dart';
import 'package:atomic_momentum/domain/entities/momentum.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/services/momentum_calculator.dart';

void main() {
  // 2026-01-05 is a Monday
  final start = DateTime(2026, 1, 5);
  final daily = HabitSchedule(frequency: ResetFrequency.daily, anchor: start);

  DateTime day(int offset) => DateTime(start.year, start.month, start.day + offset);

  /// Every day from the start for [count] days, logged with [amount].
  Map<DateTime, int> everyDay(int count, {int amount = 1, Set<int> skip = const {}}) => {
        for (var i = 0; i < count; i++)
          if (!skip.contains(i)) day(i): amount,
      };

  Momentum calc(
    Map<DateTime, int> history, {
    required DateTime now,
    int target = 1,
    HabitSchedule? schedule,
    DateTime? from,
  }) =>
      MomentumCalculator.calculate(
        history: history,
        target: target,
        schedule: schedule ?? daily,
        start: from ?? start,
        now: now,
      );

  group('daily habits', () {
    test('steady practice reaches about 80 in 66 days, about 16 after a week', () {
      // Evening of the last day, with that day done
      expect(calc(everyDay(66), now: day(65).add(const Duration(hours: 20))).score, closeTo(80, 1));
      expect(calc(everyDay(7), now: day(6).add(const Duration(hours: 20))).score, closeTo(16, 1));
    });

    test('a partly done day counts in proportion', () {
      // 3 of 4 every day for a long time converges on 75
      final score = calc(everyDay(400, amount: 3), target: 4, now: day(399).add(const Duration(hours: 1))).score;
      expect(score, closeTo(75, 1));
    });

    test('one miss costs only a couple of points', () {
      final steady = calc(everyDay(66), now: day(66).add(const Duration(hours: 9))).score;
      // Day 66 is unfinished today; compare with day 65 missed instead
      final missed = calc(everyDay(66, skip: {65}), now: day(66).add(const Duration(hours: 9))).score;
      expect(steady - missed, inInclusiveRange(1, 3));
    });

    test('an unfinished today never lowers the score; finishing it raises it at once', () {
      final history = everyDay(10);
      final morning = day(10).add(const Duration(hours: 8));
      final last = calc(history, now: day(9).add(const Duration(hours: 23))).score;

      expect(calc(history, now: morning).score, last);
      expect(calc({...history, day(10): 1}, now: morning).score, greaterThan(last));
    });

    test('a partly done today is not counted until the day ends', () {
      final history = {...everyDay(10), day(10): 1};
      final morning = day(10).add(const Duration(hours: 8));
      expect(calc(history, target: 2, now: morning).score,
          calc(everyDay(10), target: 2, now: morning).score);
    });

    test('trend rises while building and falls after a week off', () {
      final building = calc(everyDay(20), now: day(19).add(const Duration(hours: 20)));
      expect(building.trend, greaterThan(1));
      expect(building.isRising, isTrue);

      final weekOff = calc(everyDay(40), now: day(47).add(const Duration(hours: 9)));
      expect(weekOff.trend, lessThan(-1));
      expect(weekOff.isFalling, isTrue);
    });

    test('history before the start date is ignored', () {
      final history = {DateTime(2025, 12, 1): 1, ...everyDay(5)};
      final now = day(4).add(const Duration(hours: 20));
      expect(calc(history, now: now).score, calc(everyDay(5), now: now).score);
    });

    test('a new habit with nothing logged has no momentum', () {
      expect(calc({}, now: day(0).add(const Duration(hours: 12))).score, 0);
    });
  });

  group('other schedules', () {
    test('rest days are ignored: Mon/Wed/Fri reaches about 80 in about 66 days', () {
      final monWedFri = HabitSchedule(
        frequency: ResetFrequency.daily,
        anchor: start,
        weekdays: [DateTime.monday, DateTime.wednesday, DateTime.friday],
      );
      final history = {
        for (var i = 0; i < 66; i++)
          if (monWedFri.isDueOn(day(i))) day(i): 1,
      };
      // 29 due days (Mon/Wed/Fri) in the 66 days
      expect(calc(history, schedule: monWedFri, now: day(65).add(const Duration(hours: 12))).score,
          closeTo(80, 3));
    });

    test('weekly reaches about 80 in about 9-10 weeks', () {
      final weekly = HabitSchedule(frequency: ResetFrequency.weekly, anchor: start);
      final history = {for (var w = 0; w < 10; w++) day(w * 7): 1};
      final score = calc(history, schedule: weekly, now: day(69).add(const Duration(hours: 12))).score;
      expect(score, inInclusiveRange(78, 84));
    });

    test('monthly uses at least 8 periods to build', () {
      final monthly = HabitSchedule(frequency: ResetFrequency.monthly, anchor: start);
      // 8 periods: 1 - 0.2^(1/8)
      expect(MomentumCalculator.smoothing(monthly), closeTo(0.1822, 0.001));
      final history = {for (var m = 0; m < 8; m++) DateTime(2026, 1 + m, 5): 1};
      final score = calc(history, schedule: monthly, now: DateTime(2026, 8, 20)).score;
      expect(score, closeTo(80, 1));
    });

    test('habits that never reset, or have no target, have no momentum', () {
      final never = HabitSchedule(frequency: ResetFrequency.never, anchor: start);
      expect(calc(everyDay(10), schedule: never, now: day(9)), Momentum.none);
      expect(calc(everyDay(10), target: 0, now: day(9)), Momentum.none);
    });
  });
}
