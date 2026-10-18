import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/health_link.dart';
import 'package:atomic_momentum/domain/services/health_days.dart';
import '../../../helpers/test_data.dart';

/// Health samples into whole numbers per day, and which days to fill in.
void main() {
  DateTime oct(int day, [int hour = 0, int minute = 0]) => DateTime(2026, 10, day, hour, minute);
  HealthSpan span(DateTime start, DateTime end) => (start: start, end: end);

  group('HealthDays', () {
    test('overlapping spans count once', () {
      final watchAndPhone = [span(oct(18, 7), oct(18, 8)), span(oct(18, 7, 30), oct(18, 8, 30)), span(oct(18, 9), oct(18, 9, 10))];
      expect(HealthDays.unionMinutes(watchAndPhone, from: oct(18), to: oct(19)), 100);
    });

    test('minutes are split at midnight', () {
      final late = [span(oct(17, 23, 30), oct(18, 0, 20))];
      expect(HealthDays.minutesByDay(late, oct(17), oct(18)), {oct(17): 30, oct(18): 20});
    });

    test('sleep counts on the morning you wake, to the nearest hour', () {
      final night = [
        span(oct(17, 23), oct(18, 2)),
        span(oct(18, 1), oct(18, 5, 50)), // overlaps the first
        span(oct(18, 14), oct(18, 14, 20)), // a nap that afternoon
      ];
      expect(HealthDays.sleepHoursByDay(night, oct(18), oct(18)), {oct(18): 7}, reason: '6 h 50 m + 20 m nap');
      expect(HealthDays.sleepHoursByDay(night, oct(17), oct(17)), {oct(17): 0});
    });

    test('workouts count on the day they start; water in 250 ml glasses', () {
      expect(HealthDays.countByStartDay([oct(18, 7), oct(18, 18), oct(17, 23, 50)], oct(17), oct(18)), {oct(17): 1, oct(18): 2});
      expect(
        HealthDays.waterGlassesByDay([(at: oct(18, 9), liters: 0.5), (at: oct(18, 12), liters: 0.33)], oct(18), oct(18)),
        {oct(18): 3},
      );
    });
  });

  group('HealthMerge', () {
    final today = oct(18, 12);
    final linked = HealthLink(metric: HealthMetric.steps, linkedOn: oct(1));

    test('the higher number wins, and Health never lowers a day', () {
      final habit = withClock(Clock.fixed(today), () => TestData.createTestHabit(target: 8000)
          .copyWith(health: linked)
          .setDays({oct(17): 9000, oct(16): 2000}));
      final days = HealthMerge.daysToSet(habit, {oct(18): 4500, oct(17): 6000, oct(16): 7000}, today);
      expect(days, {oct(18): 4500, oct(16): 7000});
    });

    test('a week back at most, and never before linking', () {
      final habit = TestData.createTestHabit(target: 8000).copyWith(health: HealthLink(metric: HealthMetric.steps, linkedOn: oct(16)));
      final health = {for (var d = 1; d <= 18; d++) oct(d): 100};
      expect(HealthMerge.daysToSet(habit, health, today).keys.toSet(), {oct(16), oct(17), oct(18)});
      expect(HealthMerge.firstDay(habit.copyWith(health: linked), today), oct(12));
    });

    test('a period never goes past what it can hold', () {
      final habit = TestData.createTestHabit(target: 10).copyWith(health: linked);
      final days = HealthMerge.daysToSet(habit, {oct(18): 500}, today);
      expect(days, {oct(18): habit.maxPeriodTotal});
    });

    test('unlinked habits and habits being broken are left alone', () {
      expect(HealthMerge.daysToSet(TestData.createTestHabit(), {oct(18): 5}, today), isEmpty);
    });
  });
}
