import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/habit_schedule.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/services/streak_calculator.dart';

void main() {
  // 2024-01-15 is a Monday
  final mondayAnchor = DateTime(2024, 1, 15);
  final noon15th = DateTime(2024, 1, 15, 12);

  Map<DateTime, int> days(Map<int, int> dayOfJanuaryToAmount) => {
        for (final e in dayOfJanuaryToAmount.entries) DateTime(2024, 1, e.key): e.value,
      };

  group('StreakCalculator.calculate (daily)', () {
    calc(Map<DateTime, int> history, {DateTime? now, int target = 2}) => StreakCalculator.calculate(
          history: history,
          target: target,
          schedule: HabitSchedule(frequency: ResetFrequency.daily, anchor: mondayAnchor),
          now: now ?? noon15th,
        );

    test('is empty with no history', () {
      final streak = calc({});
      expect(streak.current, 0);
      expect(streak.longest, 0);
      expect(streak.history, isEmpty);
    });

    test('counts consecutive completed days including today', () {
      final streak = calc(days({13: 2, 14: 2, 15: 2}));
      expect(streak.current, 3);
      expect(streak.longest, 3);
    });

    test('an unfinished today does not break the streak', () {
      final streak = calc(days({13: 2, 14: 2, 15: 1}));
      expect(streak.current, 2);
    });

    test('one missed day bends the streak: it is kept but at risk', () {
      final streak = calc(days({12: 2, 13: 2}));
      expect(streak.current, 2);
      expect(streak.atRisk, isTrue);
    });

    test('completing today after a miss clears the risk', () {
      final streak = calc(days({12: 2, 13: 2, 15: 2}));
      expect(streak.current, 3);
      expect(streak.atRisk, isFalse);
    });

    test('a streak with no misses is not at risk', () {
      expect(calc(days({13: 2, 14: 2})).atRisk, isFalse);
    });

    test('quietly drops to 0 after two missed days in a row', () {
      final streak = calc(days({11: 2, 12: 2}));
      expect(streak.current, 0);
      expect(streak.atRisk, isFalse);
      expect(streak.longest, 2);
    });

    test('missing every other day never misses twice in a row', () {
      final streak = calc(days({11: 2, 13: 2, 15: 2}));
      expect(streak.current, 3);
    });

    test('a partially done day counts as a miss for the streak', () {
      final streak = calc(days({13: 2, 14: 1}));
      expect(streak.current, 1);
      expect(streak.atRisk, isTrue);

      expect(calc(days({12: 2, 13: 1, 14: 1})).current, 0);
    });

    test('filling in a missed day retroactively restores the streak', () {
      final broken = days({9: 2, 10: 2, 13: 2, 14: 2});
      expect(calc(broken).current, 2);

      // One missed day (the 11th) left is bridged
      final repaired = {...broken, DateTime(2024, 1, 12): 2};
      final streak = calc(repaired);
      expect(streak.current, 5);
      expect(streak.longest, 5);
    });

    test('runs join across single missed days', () {
      final streak = calc(days({1: 2, 2: 2, 4: 2, 5: 2}));
      expect(streak.current, 0);
      expect(streak.longest, 4);
      expect(streak.history.single.startDate, DateTime(2024, 1, 1));
      expect(streak.history.single.endDate, DateTime(2024, 1, 5));
    });

    test('longest tracks the best run and history lists every run', () {
      final streak = calc(days({1: 2, 2: 2, 3: 2, 4: 2, 8: 2, 9: 2, 14: 2}));

      expect(streak.current, 1);
      expect(streak.longest, 4);
      expect(streak.history, hasLength(3));
      expect(streak.history.first.startDate, DateTime(2024, 1, 1));
      expect(streak.history.first.endDate, DateTime(2024, 1, 4));
      expect(streak.history.first.length, 4);
      expect(streak.history.last.isActive, isTrue);
    });

    test('the last run is closed when the streak has expired', () {
      final streak = calc(days({10: 2, 11: 2}));
      expect(streak.current, 0);
      expect(streak.history.single.isActive, isFalse);
    });

    test('ignores entries dated in the future', () {
      final streak = calc(days({14: 2, 15: 2, 16: 2}));
      expect(streak.current, 2);
    });

    test('works across month and year boundaries', () {
      final streak = calc(
        {DateTime(2023, 12, 31): 2, DateTime(2024, 1, 1): 2},
        now: DateTime(2024, 1, 1, 9),
      );
      expect(streak.current, 2);
    });
  });

  group('StreakCalculator.calculate (weekly and monthly)', () {
    test('weekly streaks count weeks whose days add up to the target', () {
      // Thursday-anchored weeks: Jan 4-10, Jan 11-17
      final thursdayAnchor = DateTime(2024, 1, 4);
      final streak = StreakCalculator.calculate(
        history: days({4: 1, 6: 2, 11: 1, 12: 1, 16: 1}),
        target: 3,
        schedule: HabitSchedule(frequency: ResetFrequency.weekly, anchor: thursdayAnchor),
        now: DateTime(2024, 1, 17, 8),
      );

      expect(streak.current, 2);
    });

    test('weekly streak survives an unfinished current week', () {
      final streak = StreakCalculator.calculate(
        history: days({8: 3, 15: 1}),
        target: 3,
        schedule: HabitSchedule(frequency: ResetFrequency.weekly, anchor: mondayAnchor),
        now: DateTime(2024, 1, 17),
      );

      expect(streak.current, 1);
    });

    test('a weekly streak survives one missed week', () {
      final streak = StreakCalculator.calculate(
        history: days({1: 3, 15: 3}),
        target: 3,
        schedule: HabitSchedule(frequency: ResetFrequency.weekly, anchor: mondayAnchor),
        now: DateTime(2024, 1, 17),
      );

      expect(streak.current, 2);
      expect(streak.atRisk, isFalse);
    });

    test('monthly streaks respect the anchor day', () {
      // Months run from the 20th: Nov 20 - Dec 19, Dec 20 - Jan 19
      final streak = StreakCalculator.calculate(
        history: {DateTime(2023, 11, 25): 1, DateTime(2024, 1, 10): 1},
        target: 1,
        schedule: HabitSchedule(frequency: ResetFrequency.monthly, anchor: DateTime(2023, 1, 20)),
        now: DateTime(2024, 1, 15),
      );

      expect(streak.current, 2);
    });

    test('never habits have no streak', () {
      final streak = StreakCalculator.calculate(
        history: days({13: 5, 14: 5}),
        target: 1,
        schedule: HabitSchedule(frequency: ResetFrequency.never, anchor: mondayAnchor),
        now: noon15th,
      );

      expect(streak, equals(StreakCalculator.calculate(
        history: const {},
        target: 1,
        schedule: HabitSchedule(frequency: ResetFrequency.daily, anchor: mondayAnchor),
        now: noon15th,
      )));
    });
  });

  group('StreakCalculator.streakDeadline', () {
    deadline(Map<DateTime, int> history, {ResetFrequency frequency = ResetFrequency.daily}) =>
        StreakCalculator.streakDeadline(
          history: history,
          target: 1,
          schedule: HabitSchedule(frequency: frequency, anchor: mondayAnchor),
          now: noon15th,
        );

    test('is the end of tomorrow while today is unfinished (one more miss is allowed)', () {
      expect(deadline(days({14: 1})), DateTime(2024, 1, 17));
    });

    test('is the end of the day after tomorrow when today is already done', () {
      expect(deadline(days({14: 1, 15: 1})), DateTime(2024, 1, 18));
    });

    test('is the end of today after a miss', () {
      expect(deadline(days({13: 1})), DateTime(2024, 1, 16));
    });

    test('is null when there is no streak to lose', () {
      expect(deadline({}), isNull);
      expect(deadline(days({12: 1})), isNull);
    });

    test('is the end of next week for weekly habits', () {
      expect(deadline(days({8: 1}), frequency: ResetFrequency.weekly), DateTime(2024, 1, 29));
    });

    test('is null for never habits', () {
      expect(deadline(days({14: 1}), frequency: ResetFrequency.never), isNull);
    });
  });

  group('StreakCalculator with intervals and rest days', () {
    // 2026-10-16 is a Friday
    final fri16 = DateTime(2026, 10, 16);
    final monWedFri = HabitSchedule(
      frequency: ResetFrequency.daily,
      anchor: fri16,
      weekdays: [DateTime.monday, DateTime.wednesday, DateTime.friday],
    );

    test('every 2 days counts 2-day blocks', () {
      final every2 = HabitSchedule(frequency: ResetFrequency.daily, interval: 2, anchor: DateTime(2026, 10, 10));
      // Blocks: 10-11, 12-13, 14-15, 16-17; target 2 per block
      final streak = StreakCalculator.calculate(
        history: {DateTime(2026, 10, 10): 1, DateTime(2026, 10, 11): 1, DateTime(2026, 10, 13): 2, DateTime(2026, 10, 14): 2},
        target: 2,
        schedule: every2,
        now: DateTime(2026, 10, 16, 9),
      );
      expect(streak.current, 3);
    });

    test('a Mon/Wed/Fri streak survives the rest days in between', () {
      // Due Mon 12, Wed 14, Fri 16; Tue 13 / Thu 15 are rest days
      final streak = StreakCalculator.calculate(
        history: {DateTime(2026, 10, 12): 1, DateTime(2026, 10, 14): 1, DateTime(2026, 10, 16): 1},
        target: 1,
        schedule: monWedFri,
        now: DateTime(2026, 10, 18, 12), // Sunday, a rest day
      );
      expect(streak.current, 3);
      expect(streak.longest, 3);
    });

    test('one missed due day is bridged; logging on a rest day does not count', () {
      final streak = StreakCalculator.calculate(
        history: {DateTime(2026, 10, 12): 1, DateTime(2026, 10, 15): 1, DateTime(2026, 10, 16): 1},
        target: 1,
        schedule: monWedFri,
        now: DateTime(2026, 10, 16, 20),
      );
      // Wed 14 missed (bridged); Thu 15 is a rest day, so Mon 12 and Fri 16 count
      expect(streak.current, 2);
    });

    test('two missed due days end it, even with rest days between them', () {
      final streak = StreakCalculator.calculate(
        history: {DateTime(2026, 10, 9): 1},
        target: 1,
        schedule: monWedFri,
        now: DateTime(2026, 10, 16, 20), // Fri 16 still open; Mon 12 and Wed 14 missed
      );
      expect(streak.current, 0);
    });

    test('the deadline skips rest days', () {
      final history = {DateTime(2026, 10, 14): 1, DateTime(2026, 10, 16): 1};
      // Saturday: the next due days are Mon 19 and Wed 21, so missing both
      // ends the streak at midnight into Thu 22
      expect(
        StreakCalculator.streakDeadline(history: history, target: 1, schedule: monWedFri, now: DateTime(2026, 10, 17, 10)),
        DateTime(2026, 10, 22),
      );
      // Friday 16 already done: same
      expect(
        StreakCalculator.streakDeadline(history: history, target: 1, schedule: monWedFri, now: DateTime(2026, 10, 16, 21)),
        DateTime(2026, 10, 22),
      );
      // Fri 16 missed: the next due day, Monday, is the last chance
      expect(
        StreakCalculator.streakDeadline(
            history: {DateTime(2026, 10, 14): 1}, target: 1, schedule: monWedFri, now: DateTime(2026, 10, 17, 10)),
        DateTime(2026, 10, 20),
      );
    });
  });
}
