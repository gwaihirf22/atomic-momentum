import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/habit_schedule.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/entities/two_minute_version.dart';
import 'package:atomic_momentum/domain/services/momentum_calculator.dart';

/// The one-pass series must match the score computed afresh at each time.
void main() {
  // 2026-01-05 is a Monday
  final start = DateTime(2026, 1, 5);
  DateTime day(int offset, [int hour = 0, int minute = 0]) =>
      DateTime(start.year, start.month, start.day + offset, hour, minute);

  final schedules = {
    'daily': HabitSchedule(frequency: ResetFrequency.daily, anchor: start),
    'Mon/Wed/Fri': HabitSchedule(frequency: ResetFrequency.daily, anchor: start, weekdays: const {1, 3, 5}),
    'every 2 days': HabitSchedule(frequency: ResetFrequency.daily, interval: 2, anchor: start),
    'weekly': HabitSchedule(frequency: ResetFrequency.weekly, anchor: start),
    'monthly': HabitSchedule(frequency: ResetFrequency.monthly, anchor: start),
  };

  for (final MapEntry(key: name, value: schedule) in schedules.entries) {
    for (final kind in ['build', 'break']) {
      test('$name, $kind: matches the score at every moment', () {
        final random = math.Random(name.hashCode ^ kind.hashCode);
        final history = <DateTime, int>{
          for (var i = 0; i < 150; i++)
            if (random.nextDouble() < 0.7) day(i): random.nextInt(5),
        };
        final twoMinute = TwoMinuteLog(
          days: {for (var i = 0; i < 150; i++) if (random.nextDouble() < 0.1) day(i)},
          minimum: kind == 'build' ? 2 : null,
        );
        final breakLimit = kind == 'break' ? 1 : null;
        final times = [
          for (var i = -3; i < 160; i++) ...[day(i, 9), day(i, 23, 59)],
        ];

        final series = MomentumCalculator.series(
          history: history,
          target: 4,
          schedule: schedule,
          start: start,
          at: times,
          twoMinute: breakLimit == null ? twoMinute : TwoMinuteLog.none,
          breakLimit: breakLimit,
        );
        for (var i = 0; i < times.length; i++) {
          final at = times[i];
          final fresh = MomentumCalculator.calculate(
            history: {
              for (final entry in history.entries)
                if (!entry.key.isAfter(at)) entry.key: entry.value,
            },
            target: 4,
            schedule: schedule,
            start: start,
            now: at,
            twoMinute: breakLimit == null ? twoMinute : TwoMinuteLog.none,
            breakLimit: breakLimit,
          ).score;
          expect(series[i], closeTo(fresh, 1e-9), reason: '$at');
        }
      });
    }
  }

  test('a habit that never resets has no momentum to chart', () {
    final never = HabitSchedule(frequency: ResetFrequency.never, anchor: start);
    expect(
      MomentumCalculator.series(history: {day(1): 3}, target: 1, schedule: never, start: start, at: [day(2)]),
      [0.0],
    );
  });

  test('a year of days for a habit is quick', () {
    final daily = schedules['daily']!;
    final history = {for (var i = 0; i < 365; i++) day(i): 1};
    final times = [for (var i = 0; i < 365; i++) day(i, 23, 59)];
    final watch = Stopwatch()..start();
    for (var n = 0; n < 20; n++) {
      MomentumCalculator.series(history: history, target: 1, schedule: daily, start: start, at: times);
    }
    expect(watch.elapsedMilliseconds, lessThan(2000), reason: '20 habits × a year');
  });
}
