import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/habit_goal.dart';
import 'package:atomic_momentum/domain/entities/habit_metadata.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/entities/streak_data.dart';

void main() {
  // 2024-01-17 is a Wednesday
  final now = DateTime(2024, 1, 17, 12);
  DateTime jan(int day) => DateTime(2024, 1, day);

  Habit habit({ResetFrequency frequency = ResetFrequency.daily, HabitGoal goal = HabitGoal.build, DateTime? anchor}) => Habit(
        id: 'h',
        name: 'Read',
        progress: 0,
        target: goal == HabitGoal.quit ? 0 : 1,
        color: HabitColor.teal,
        categoryId: BuiltInCategoryIds.mind,
        lastUpdatedDate: now,
        resetFrequency: frequency,
        history: const {},
        streak: StreakData.empty(),
        metadata: HabitMetadata(createdDate: jan(17), lastModifiedDate: jan(17), version: 1, customFields: const {}),
        resetAnchorDate: anchor,
        goal: goal,
      );

  T at<T>(T Function() body) => withClock(Clock.fixed(now), body);

  test('startedOn: from the day it counts from', () {
    final h = habit();
    expect(h.startedOn(jan(16)), isFalse);
    expect(h.startedOn(DateTime(2024, 1, 17, 8)), isTrue);
  });

  test('startFrom moves the start earlier; the days between count as missed', () {
    final started = at(() => habit().startFrom(jan(10)));
    expect(started.trackedFrom, jan(10));
    expect(started.startedOn(jan(10)), isTrue);
    expect(started.wasCompletedOnDate(jan(12)), isFalse);
  });

  test('a habit being broken: the days since count as clean', () {
    final started = at(() => habit(goal: HabitGoal.quit).startFrom(jan(10)).refresh(now));
    expect(started.wasCompletedOnDate(jan(12)), isTrue);
    expect(started.streak.current, greaterThanOrEqualTo(7));
  });

  test('weeks keep their boundaries: the reset day is pinned', () {
    // An older habit with no reset day of its own falls back to the day it was made
    final weekly = habit(frequency: ResetFrequency.weekly);
    expect(weekly.schedule.periodStart(jan(20)), jan(17));
    final started = at(() => weekly.startFrom(jan(5)));
    expect(started.resetAnchorDate, jan(17));
    expect(started.schedule.periodStart(jan(20)), jan(17));
  });

  test('not later than it already counts from, and not in the future', () {
    expect(() => at(() => habit().startFrom(jan(17))), throwsArgumentError);
    expect(() => at(() => habit().startFrom(jan(20))), throwsArgumentError);
  });

  test('a log before the start moves it there for good: clearing the log keeps it', () {
    final logged = at(() => habit().setProgressForDate(jan(12), 1));
    expect(logged.trackedFrom, jan(12));
    final cleared = at(() => logged.setProgressForDate(jan(12), 0));
    expect(cleared.trackedFrom, jan(12));
    expect(cleared.startedOn(jan(12)), isTrue);

    final viaDays = at(() => habit().setDays({jan(14): 1, jan(11): 1}).setDays({jan(14): 0, jan(11): 0}));
    expect(viaDays.trackedFrom, jan(11));
    final viaTiny = at(() => habit().setTwoMinuteForDate(jan(13), true).setTwoMinuteForDate(jan(13), false));
    expect(viaTiny.trackedFrom, jan(13));
  });
}
