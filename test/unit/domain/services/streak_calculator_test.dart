import 'package:flutter_test/flutter_test.dart';
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
          frequency: ResetFrequency.daily,
          anchor: mondayAnchor,
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

    test('quietly drops to 0 once a whole day is missed', () {
      final streak = calc(days({12: 2, 13: 2}));
      expect(streak.current, 0);
      expect(streak.longest, 2);
    });

    test('a partially done day does not count as completed', () {
      final streak = calc(days({13: 2, 14: 1}));
      expect(streak.current, 0);
    });

    test('filling in a missed day retroactively restores the streak', () {
      final broken = days({10: 2, 11: 2, 13: 2, 14: 2});
      expect(calc(broken).current, 2);

      final repaired = {...broken, DateTime(2024, 1, 12): 2};
      final streak = calc(repaired);
      expect(streak.current, 5);
      expect(streak.longest, 5);
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
        frequency: ResetFrequency.weekly,
        anchor: thursdayAnchor,
        now: DateTime(2024, 1, 17, 8),
      );

      expect(streak.current, 2);
    });

    test('weekly streak survives an unfinished current week', () {
      final streak = StreakCalculator.calculate(
        history: days({8: 3, 15: 1}),
        target: 3,
        frequency: ResetFrequency.weekly,
        anchor: mondayAnchor,
        now: DateTime(2024, 1, 17),
      );

      expect(streak.current, 1);
    });

    test('monthly streaks respect the anchor day', () {
      // Months run from the 20th: Nov 20 - Dec 19, Dec 20 - Jan 19
      final streak = StreakCalculator.calculate(
        history: {DateTime(2023, 11, 25): 1, DateTime(2024, 1, 10): 1},
        target: 1,
        frequency: ResetFrequency.monthly,
        anchor: DateTime(2023, 1, 20),
        now: DateTime(2024, 1, 15),
      );

      expect(streak.current, 2);
    });

    test('never habits have no streak', () {
      final streak = StreakCalculator.calculate(
        history: days({13: 5, 14: 5}),
        target: 1,
        frequency: ResetFrequency.never,
        anchor: mondayAnchor,
        now: noon15th,
      );

      expect(streak, equals(StreakCalculator.calculate(
        history: const {},
        target: 1,
        frequency: ResetFrequency.daily,
        anchor: mondayAnchor,
        now: noon15th,
      )));
    });
  });

  group('StreakCalculator.streakDeadline', () {
    deadline(Map<DateTime, int> history, {ResetFrequency frequency = ResetFrequency.daily}) =>
        StreakCalculator.streakDeadline(
          history: history,
          target: 1,
          frequency: frequency,
          anchor: mondayAnchor,
          now: noon15th,
        );

    test('is the end of today when today is not done yet', () {
      expect(deadline(days({14: 1})), DateTime(2024, 1, 16));
    });

    test('is the end of tomorrow when today is already done', () {
      expect(deadline(days({14: 1, 15: 1})), DateTime(2024, 1, 17));
    });

    test('is null when there is no streak to lose', () {
      expect(deadline({}), isNull);
      expect(deadline(days({12: 1})), isNull);
    });

    test('is the end of the current week for weekly habits', () {
      expect(deadline(days({8: 1}), frequency: ResetFrequency.weekly), DateTime(2024, 1, 22));
    });

    test('is null for never habits', () {
      expect(deadline(days({14: 1}), frequency: ResetFrequency.never), isNull);
    });
  });
}
