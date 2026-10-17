import 'package:clock/clock.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/habit_goal.dart';
import 'package:atomic_momentum/domain/entities/habit_metadata.dart';
import 'package:atomic_momentum/domain/entities/habit_notify.dart';
import 'package:atomic_momentum/domain/entities/reminder_settings.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/entities/streak_data.dart';
import 'package:atomic_momentum/domain/entities/streak_warning_settings.dart';
import 'package:atomic_momentum/domain/services/habit_stats.dart';
import 'package:atomic_momentum/domain/services/recent_periods.dart';
import 'package:atomic_momentum/domain/services/reminder_planner.dart';
import 'package:atomic_momentum/domain/services/streak_warning_planner.dart';

/// Habits being broken: doing nothing keeps the day, slips can break it.
void main() {
  // Monday 2024-03-04, 2 PM; the habit was made 10 days before
  final now = DateTime(2024, 3, 4, 14);
  DateTime daysAgo(int n) => DateTime(2024, 3, 4 - n);

  Habit habit({
    HabitGoal goal = HabitGoal.quit,
    int limit = 0,
    ResetFrequency frequency = ResetFrequency.daily,
    Map<DateTime, int> slips = const {},
    DateTime? created,
    ReminderSettings? reminder,
    HabitNotify notify = HabitNotify.standard,
  }) =>
      withClock(
        Clock.fixed(now),
        () => Habit(
          id: 'smoke',
          name: 'Smoking',
          progress: 0,
          target: limit,
          color: HabitColor.red,
          categoryId: BuiltInCategoryIds.body,
          lastUpdatedDate: now,
          resetFrequency: frequency,
          history: slips,
          streak: StreakData.empty(),
          reminder: reminder,
          metadata: HabitMetadata(
              createdDate: created ?? daysAgo(10), lastModifiedDate: now, version: 1, customFields: const {}),
          resetAnchorDate: DateTime(2024, 1, 1), // a Monday
          goal: goal,
          notify: notify,
        ).refresh(now),
      );

  group('quit', () {
    test('every day without a slip counts, today included', () {
      final h = habit();
      expect(h.streak.current, 11, reason: '10 days ago through today');
      expect(h.streak.atRisk, isFalse);
      expect(h.isCompleted, isTrue);
      expect(h.wasCompletedOnDate(daysAgo(3)), isTrue);
      expect(h.fractionDoneOn(daysAgo(3)), 1.0);
      expect(h.isTwoMinuteOn(daysAgo(3)), isFalse);
    });

    test('days before it was tracked are not counted', () {
      final h = habit();
      expect(h.wasCompletedOnDate(daysAgo(11)), isFalse);
    });

    test('one slip puts the streak at risk; two days in a row end it', () {
      final once = habit(slips: {daysAgo(1): 1});
      expect(once.streak.atRisk, isTrue);
      expect(once.streak.current, 10, reason: '"never miss twice": one slipped day is bridged');
      expect(once.wasCompletedOnDate(daysAgo(1)), isFalse);
      expect(once.fractionDoneOn(daysAgo(1)), 0.0);

      final twice = habit(slips: {daysAgo(2): 1, daysAgo(1): 3});
      expect(twice.streak.current, 1, reason: 'only today since');
      expect(twice.streak.longest, 8);
    });

    test('a slip today after one yesterday ends the streak at once', () {
      final h = habit(slips: {daysAgo(1): 1, daysAgo(0): 1});
      expect(h.streak.current, 0);
      expect(h.streak.longest, 9);
    });

    test('a slip today alone is the first miss: still a streak, now at risk', () {
      final h = habit(slips: {daysAgo(0): 1});
      expect(h.streak.current, 10);
      expect(h.streak.atRisk, isTrue);
    });

    test('a slip today shows straight away', () {
      final h = habit(slips: {daysAgo(0): 1});
      expect(h.isCompleted, isFalse);
      expect(h.progress, 1);
      expect(h.progressPercentage, 0.0);
    });

    test('momentum grows with clean days and drops with slips', () {
      final clean = habit();
      final slipping = habit(slips: {daysAgo(1): 1, daysAgo(3): 1, daysAgo(5): 1});
      expect(clean.momentum.score, greaterThan(0));
      expect(slipping.momentum.score, lessThan(clean.momentum.score));
    });
  });

  group('limit', () {
    test('at or under the limit keeps the day; over it is a slip', () {
      final h = habit(goal: HabitGoal.limit, limit: 2, slips: {daysAgo(2): 2, daysAgo(1): 3, daysAgo(0): 1});
      expect(h.wasCompletedOnDate(daysAgo(2)), isTrue);
      expect(h.wasCompletedOnDate(daysAgo(1)), isFalse);
      expect(h.isCompleted, isTrue, reason: '1 of 2 so far today');
      expect(h.streak.atRisk, isTrue);
    });

    test('a weekly limit adds up the week', () {
      final h = habit(
        goal: HabitGoal.limit,
        limit: 3,
        frequency: ResetFrequency.weekly,
        created: DateTime(2024, 2, 5),
        slips: {daysAgo(8): 2, daysAgo(9): 2, daysAgo(1): 1},
      );
      expect(h.wasCompletedOnDate(daysAgo(8)), isFalse, reason: 'that week had 4');
      expect(h.wasCompletedOnDate(daysAgo(1)), isTrue);
    });
  });

  group('recent periods and stats', () {
    test('kept days are done, slipped days are missed', () {
      final marks = recentPeriods(habit(slips: {daysAgo(2): 1}), now).map((p) => p.mark).toList();
      expect(marks, [
        PeriodMark.done,
        PeriodMark.done,
        PeriodMark.done,
        PeriodMark.done,
        PeriodMark.missed,
        PeriodMark.done,
        PeriodMark.done, // today, kept so far
      ]);
    });

    test('stats count clean days', () {
      final stats = HabitStats.of(habit(slips: {daysAgo(2): 1}), now);
      expect(stats.due, 11);
      expect(stats.kept, 10);
      expect(stats.keptWithTwoMinute, 0);
    });
  });

  group('notifications', () {
    final checkIn = ReminderSettings(time: const TimeOfDay(hour: 21, minute: 0), enabled: true, daysOfWeek: const [1, 2, 3, 4, 5, 6, 7]);

    test('a check-in every day, even when the day is clean, with a check-in message', () {
      final planned = ReminderPlanner.plan(habit(reminder: checkIn), now: now);
      expect(planned, hasLength(ReminderPlanner.horizonDays));
      expect(planned.first.at, DateTime(2024, 3, 4, 21));
      expect(planned.first.body, ReminderPlanner.checkInBody);
    });

    test('smart mode checks in every day too', () {
      final planned = ReminderPlanner.plan(
          habit(reminder: ReminderSettings.smart(time: const TimeOfDay(hour: 21, minute: 0)), frequency: ResetFrequency.weekly),
          now: now);
      expect(planned, hasLength(ReminderPlanner.horizonDays));
    });

    test('no streak warnings for a habit being broken, nor where turned off', () {
      const settings = StreakWarningSettings(enabled: true, leadTime: Duration(hours: 4), remindBeforeFirstMiss: true);
      expect(StreakWarningPlanner.plan(habit(slips: {daysAgo(1): 1}), settings, now), isEmpty);
      expect(StreakWarningPlanner.maxPending([habit()], settings), 0);
    });

    test('a habit being built gets no warnings when they are turned off for it', () {
      const settings = StreakWarningSettings(enabled: true, leadTime: Duration(hours: 4), remindBeforeFirstMiss: true);
      final built = withClock(
        Clock.fixed(now),
        () => Habit.create(
          name: 'Read',
          target: 1,
          color: HabitColor.teal,
          categoryId: BuiltInCategoryIds.mind,
          notify: const HabitNotify(streakWarnings: false),
        ).setProgressForDate(daysAgo(1), 1),
      );
      expect(StreakWarningPlanner.plan(built, settings, now), isEmpty);
      expect(StreakWarningPlanner.maxPending([built], settings), 0);
    });
  });
}
