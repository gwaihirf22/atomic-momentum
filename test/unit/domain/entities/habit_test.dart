import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/services/momentum_calculator.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/entities/streak_data.dart';
import 'package:atomic_momentum/domain/entities/reminder_settings.dart';
import '../../../helpers/test_data.dart';

void main() {
  group('Habit', () {
    final testDate = DateTime(2024, 1, 15, 10, 30);
    final yesterday = testDate.subtract(const Duration(days: 1));

    group('constructor', () {
      test('should create Habit with all required parameters', () {
        final habit = TestData.createTestHabit();

        expect(habit.id, 'test_habit_1');
        expect(habit.name, 'Test Habit');
        expect(habit.progress, 5);
        expect(habit.target, 10);
        expect(habit.color, HabitColor.blue);
        expect(habit.categoryId, BuiltInCategoryIds.body);
        expect(habit.resetFrequency, ResetFrequency.daily);
        expect(habit.history, isEmpty);
        expect(habit.streak, StreakData.empty());
      });
    });

    group('create factory', () {
      test('generates unique ids even when created in quick succession', () {
        final ids = List.generate(200, (_) => Habit.create(
          name: 'Same instant',
          target: 1,
          color: HabitColor.blue,
          categoryId: BuiltInCategoryIds.body,
        ).id);

        expect(ids.toSet(), hasLength(200));
      });

      test('should create new habit with generated ID and default values', () {
        final habit = Habit.create(
          name: 'New Habit',
          target: 8,
          color: HabitColor.green,
          categoryId: BuiltInCategoryIds.mind,
        );

        expect(habit.id, startsWith('habit_'));
        expect(habit.name, 'New Habit');
        expect(habit.progress, 0);
        expect(habit.target, 8);
        expect(habit.color, HabitColor.green);
        expect(habit.categoryId, BuiltInCategoryIds.mind);
        expect(habit.resetFrequency, ResetFrequency.daily);
        expect(habit.history, isEmpty);
        expect(habit.streak.current, 0);
        expect(habit.reminder, isNull);
      });

      test('should create habit with optional parameters', () {
        final reminder = ReminderSettings.daily(time: const TimeOfDay(hour: 9, minute: 0));
        
        final habit = Habit.create(
          name: 'Complete Habit',
          target: 5,
          color: HabitColor.purple,
          categoryId: BuiltInCategoryIds.career,
          resetFrequency: ResetFrequency.weekly,
          reminder: reminder,
          icon: 'custom_icon',
        );

        expect(habit.resetFrequency, ResetFrequency.weekly);
        expect(habit.reminder, reminder);
        expect(habit.metadata.icon, 'custom_icon');
      });
    });

    group('computed properties', () {
      test('isCompleted should return true when progress >= target', () {
        final completedHabit = TestData.createTestHabit(progress: 10, target: 10);
        final overcompletedHabit = TestData.createTestHabit(progress: 15, target: 10);
        final incompleteHabit = TestData.createTestHabit(progress: 5, target: 10);

        expect(completedHabit.isCompleted, isTrue);
        expect(overcompletedHabit.isCompleted, isTrue);
        expect(incompleteHabit.isCompleted, isFalse);
      });

      test('progressPercentage should calculate correctly', () {
        final habit1 = TestData.createTestHabit(progress: 5, target: 10);
        final habit2 = TestData.createTestHabit(progress: 8, target: 10);
        final habit3 = TestData.createTestHabit(progress: 15, target: 10);
        final habit4 = TestData.createTestHabit(progress: 0, target: 0);

        expect(habit1.progressPercentage, 0.5);
        expect(habit2.progressPercentage, 0.8);
        expect(habit3.progressPercentage, 1.0); // Clamped to 1.0
        expect(habit4.progressPercentage, 0.0); // Handle zero target
      });

      test('hasReminder should return correct value', () {
        final withReminder = TestData.createTestHabit(
          reminder: ReminderSettings.daily(time: const TimeOfDay(hour: 8, minute: 0)),
        );
        final withDisabledReminder = TestData.createTestHabit(
          reminder: ReminderSettings.disabled(),
        );
        final withoutReminder = TestData.createTestHabit();

        expect(withReminder.hasReminder, isTrue);
        expect(withDisabledReminder.hasReminder, isFalse);
        expect(withoutReminder.hasReminder, isFalse);
      });
    });

    group('progress updates', () {
      test('updateProgress should update progress and history', () {
        final habit = TestData.createTestHabit(progress: 5);
        final updated = habit.updateProgress(8);

        expect(updated.progress, 8);
        expect(updated.lastUpdatedDate, isNot(habit.lastUpdatedDate));
        expect(updated.history, hasLength(1));
        expect(updated.metadata.lastModifiedDate, isNot(habit.metadata.lastModifiedDate));
      });

      test('updateProgress should update streak when completed', () {
        final habit = TestData.createTestHabit(progress: 5, target: 10);
        final updated = habit.updateProgress(10); // Complete the habit

        expect(updated.isCompleted, isTrue);
        expect(updated.streak.current, 1);
      });

      test('updateProgress should throw error for invalid progress', () {
        final habit = TestData.createTestHabit(target: 10);

        expect(() => habit.updateProgress(-1), throwsArgumentError);
        expect(() => habit.updateProgress(15), throwsArgumentError);
      });

      test('incrementProgress should increase progress correctly', () {
        final habit = TestData.createTestHabit(progress: 5, target: 10);
        
        final updated1 = habit.incrementProgress();
        expect(updated1.progress, 6);

        final updated2 = habit.incrementProgress(3);
        expect(updated2.progress, 8);

        // Should clamp to target
        final updated3 = habit.incrementProgress(10);
        expect(updated3.progress, 10);
      });

      test('decrementProgress should decrease progress correctly', () {
        final habit = TestData.createTestHabit(progress: 8, target: 10);
        
        final updated1 = habit.decrementProgress();
        expect(updated1.progress, 7);

        final updated2 = habit.decrementProgress(3);
        expect(updated2.progress, 5);

        // Should clamp to 0
        final updated3 = habit.decrementProgress(10);
        expect(updated3.progress, 0);
      });

      test('resetProgress should set progress to 0', () {
        final habit = TestData.createTestHabit(progress: 8);
        final reset = habit.resetProgress();

        expect(reset.progress, 0);
        expect(reset.lastUpdatedDate, isNot(habit.lastUpdatedDate));
      });
    });

    group('habit details updates', () {
      test('updateDetails should update specified fields', () {
        final habit = TestData.createTestHabit();
        final newReminder = ReminderSettings.daily(time: const TimeOfDay(hour: 10, minute: 0));
        
        final updated = habit.updateDetails(
          name: 'Updated Name',
          target: 15,
          color: HabitColor.red,
          categoryId: BuiltInCategoryIds.spirit,
          resetFrequency: ResetFrequency.weekly,
          reminder: newReminder,
          icon: 'new_icon',
        );

        expect(updated.name, 'Updated Name');
        expect(updated.target, 15);
        expect(updated.color, HabitColor.red);
        expect(updated.categoryId, BuiltInCategoryIds.spirit);
        expect(updated.resetFrequency, ResetFrequency.weekly);
        expect(updated.reminder, newReminder);
        expect(updated.metadata.icon, 'new_icon');
        expect(updated.metadata.version, habit.metadata.version + 1);
      });

      test('updateDetails should keep unchanged fields', () {
        final habit = TestData.createTestHabit();
        final updated = habit.updateDetails(name: 'New Name');

        expect(updated.name, 'New Name');
        expect(updated.target, habit.target); // Should remain same
        expect(updated.color, habit.color); // Should remain same
        expect(updated.categoryId, habit.categoryId); // Should remain same
      });
    });

    group('history methods', () {
      test('getProgressForDate should return correct progress', () {
        final history = {
          DateTime(2024, 1, 15): 8,
          DateTime(2024, 1, 14): 5,
        };
        final habit = TestData.createTestHabit(history: history);

        expect(habit.getProgressForDate(DateTime(2024, 1, 15)), 8);
        expect(habit.getProgressForDate(DateTime(2024, 1, 14)), 5);
        expect(habit.getProgressForDate(DateTime(2024, 1, 13)), 0); // Not in history
      });

      test('wasCompletedOnDate should check completion correctly', () {
        final history = {
          DateTime(2024, 1, 15): 10,
          DateTime(2024, 1, 14): 5,
        };
        final habit = TestData.createTestHabit(target: 10, history: history);

        expect(habit.wasCompletedOnDate(DateTime(2024, 1, 15)), isTrue);
        expect(habit.wasCompletedOnDate(DateTime(2024, 1, 14)), isFalse);
        expect(habit.wasCompletedOnDate(DateTime(2024, 1, 13)), isFalse);
      });

      test('getCompletedDates should return sorted completed dates', () {
        final history = {
          DateTime(2024, 1, 15): 10,
          DateTime(2024, 1, 14): 5,
          DateTime(2024, 1, 13): 12,
          DateTime(2024, 1, 12): 8,
        };
        final habit = TestData.createTestHabit(target: 10, history: history);

        final completedDates = habit.getCompletedDates();
        
        expect(completedDates, hasLength(2));
        expect(completedDates, [
          DateTime(2024, 1, 13),
          DateTime(2024, 1, 15),
        ]);
      });

      test('getHistoryForMonth should filter by month correctly', () {
        final history = {
          DateTime(2024, 1, 15): 8,
          DateTime(2024, 1, 10): 6,
          DateTime(2024, 2, 5): 7,
          DateTime(2023, 12, 25): 9,
        };
        final habit = TestData.createTestHabit(history: history);

        final januaryHistory = habit.getHistoryForMonth(2024, 1);
        
        expect(januaryHistory, hasLength(2));
        expect(januaryHistory[DateTime(2024, 1, 15)], 8);
        expect(januaryHistory[DateTime(2024, 1, 10)], 6);
      });
    });

    group('reset frequency', () {
      test('shouldReset should check reset timing correctly', () {
        final lastWeek = testDate.subtract(const Duration(days: 8));
        final habit = TestData.createTestHabit(
          lastUpdatedDate: lastWeek,
          resetFrequency: ResetFrequency.weekly,
        );

        expect(habit.shouldReset(testDate), isTrue);
      });

      test('shouldReset should return false for never frequency', () {
        final lastMonth = testDate.subtract(const Duration(days: 40));
        final habit = TestData.createTestHabit(
          lastUpdatedDate: lastMonth,
          resetFrequency: ResetFrequency.never,
        );

        expect(habit.shouldReset(testDate), isFalse);
      });
    });

    group('JSON serialization', () {
      test('should serialize to JSON correctly', () {
        final habit = TestData.createTestHabit(
          history: {testDate: 8, yesterday: 5},
          reminder: ReminderSettings.daily(time: const TimeOfDay(hour: 9, minute: 0)),
        );

        final json = habit.toJson();

        expect(json['id'], 'test_habit_1');
        expect(json['name'], 'Test Habit');
        expect(json['progress'], 5);
        expect(json['target'], 10);
        expect(json['color'], isA<Map<String, dynamic>>());
        expect(json['category'], 'body');
        expect(json['resetFrequency'], 'daily');
        expect(json['history'], isA<Map<String, dynamic>>());
        expect(json['streak'], isA<Map<String, dynamic>>());
        expect(json['reminder'], isA<Map<String, dynamic>>());
        expect(json['metadata'], isA<Map<String, dynamic>>());
      });

      test('should deserialize from JSON correctly', () {
        final json = TestData.habitJsonData;
        final habit = Habit.fromJson(json);

        expect(habit.id, 'test_habit_json');
        expect(habit.name, 'JSON Test Habit');
        expect(habit.progress, 7);
        expect(habit.target, 10);
        expect(habit.color.value, 0xFF2196F3);
        expect(habit.categoryId, BuiltInCategoryIds.body);
        expect(habit.resetFrequency, ResetFrequency.daily);
        expect(habit.history, hasLength(2));
        expect(habit.streak.current, 3);
        expect(habit.reminder, isNotNull);
        expect(habit.metadata.version, 1);
      });

      test('should handle null reminder in JSON', () {
        final json = Map<String, dynamic>.from(TestData.habitJsonData);
        json['reminder'] = null;

        final habit = Habit.fromJson(json);
        expect(habit.reminder, isNull);
      });

      test('should maintain equality after JSON round-trip', () {
        final original = TestData.createTestHabit(
          history: {testDate: 5},
          reminder: ReminderSettings.daily(time: const TimeOfDay(hour: 8, minute: 0)),
        );

        final json = original.toJson();
        final deserialized = Habit.fromJson(json);

        expect(deserialized, original);
      });
    });

    group('copyWith', () {
      test('should copy with new values', () {
        final original = TestData.createTestHabit();
        final newColor = HabitColor.red;
        
        final updated = original.copyWith(
          name: 'New Name',
          color: newColor,
          progress: 8,
        );

        expect(updated.name, 'New Name');
        expect(updated.color, newColor);
        expect(updated.progress, 8);
        expect(updated.target, original.target); // Should remain same
        expect(updated.id, original.id); // Should remain same
      });
    });

    group('equality', () {
      test('should be equal when all properties match', () {
        final habit1 = TestData.createTestHabit();
        final habit2 = TestData.createTestHabit();

        expect(habit1, habit2);
      });

      test('should not be equal when properties differ', () {
        final habit1 = TestData.createTestHabit(name: 'Habit 1');
        final habit2 = TestData.createTestHabit(name: 'Habit 2');

        expect(habit1, isNot(habit2));
      });
    });

    group('toString', () {
      test('should return formatted string', () {
        final habit = TestData.createTestHabit();
        final str = habit.toString();

        expect(str, contains('test_habit_1'));
        expect(str, contains('Test Habit'));
        expect(str, contains('5/10'));
      });
    });

    group('edge cases', () {
      test('should handle empty history', () {
        final habit = TestData.createTestHabit(history: {});
        
        expect(habit.getCompletedDates(), isEmpty);
        expect(habit.getHistoryForMonth(2024, 1), isEmpty);
        expect(habit.getProgressForDate(testDate), 0);
      });

      test('should handle zero target', () {
        final habit = TestData.createTestHabit(target: 0, progress: 0);
        
        expect(habit.progressPercentage, 0.0);
        expect(habit.isCompleted, isTrue); // 0 >= 0
      });
    });

    // These use real "now" because updateProgress and friends stamp today's date
    group('periods, history and streaks', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      DateTime daysAgo(int n) => DateTime(today.year, today.month, today.day - n);

      test('weekly progress adds up the days of the current week', () {
        // Anchor on today's weekday so the period runs today .. today+6
        final habit = TestData.createTestHabit(
          target: 5,
          progress: 0,
          resetFrequency: ResetFrequency.weekly,
          resetAnchorDate: today,
        ).updateProgress(2);

        expect(habit.progress, 2);
        expect(habit.history[today], 2);
        // Entries before the anchor weekday belong to last week
        expect(habit.setProgressForDate(daysAgo(1), 3).progress, 2);
      });

      test('updateProgress only logs the difference not covered by earlier days', () {
        final anchor = daysAgo(1);
        final habit = TestData.createTestHabit(
          target: 5,
          progress: 0,
          resetFrequency: ResetFrequency.weekly,
          resetAnchorDate: anchor,
          history: {anchor: 2},
        ).refresh();

        expect(habit.progress, 2);

        final updated = habit.updateProgress(3);
        expect(updated.history[today], 1);
        expect(updated.history[anchor], 2);
        expect(updated.progress, 3);
      });

      test('setProgressForDate repairs a broken streak retroactively', () {
        // Two days in a row missed (3 and 2 days ago) broke it
        final habit = TestData.createTestHabit(
          target: 1,
          history: {daysAgo(5): 1, daysAgo(4): 1, daysAgo(1): 1},
        ).refresh();
        expect(habit.streak.current, 1);

        // Filling in one leaves a single miss, which is bridged
        final repaired = habit.setProgressForDate(daysAgo(2), 1);
        expect(repaired.streak.current, 4);
        expect(repaired.streak.longest, 4);
      });

      test('setProgressForDate with 0 removes the entry and can break the streak', () {
        final habit = TestData.createTestHabit(
          target: 1,
          history: {daysAgo(2): 1, daysAgo(1): 1},
        ).refresh();
        expect(habit.streak.current, 2);

        final edited = habit.setProgressForDate(daysAgo(1), 0);
        expect(edited.history.containsKey(daysAgo(1)), isFalse);
        expect(edited.streak.current, 1);
        expect(edited.streak.atRisk, isTrue);

        expect(edited.setProgressForDate(daysAgo(2), 0).streak.current, 0);
      });

      test('setProgressForDate rejects future dates, negatives and over-target totals', () {
        final habit = TestData.createTestHabit(target: 3);

        expect(() => habit.setProgressForDate(today.add(const Duration(days: 1)), 1), throwsArgumentError);
        expect(() => habit.setProgressForDate(daysAgo(1), -1), throwsArgumentError);
        expect(() => habit.setProgressForDate(daysAgo(1), 4), throwsArgumentError);
      });

      test('setProgressForDate for today updates current progress', () {
        final habit = TestData.createTestHabit(target: 5, progress: 0);
        expect(habit.setProgressForDate(today, 4).progress, 4);
      });

      test('refresh drops progress to the new period and expires a missed streak', () {
        final habit = TestData.createTestHabit(
          target: 1,
          progress: 1,
          history: {daysAgo(4): 1, daysAgo(3): 1},
          streak: const StreakData(current: 2, longest: 2, history: []),
        );

        final refreshed = habit.refresh();
        expect(refreshed.progress, 0);
        expect(refreshed.streak.current, 0);
        expect(refreshed.streak.longest, 2);
        expect(refreshed.history, hasLength(2));
      });

      test('resetProgress clears only the current period', () {
        final habit = TestData.createTestHabit(
          target: 5,
          history: {daysAgo(1): 5},
        ).updateProgress(3);

        final reset = habit.resetProgress();
        expect(reset.progress, 0);
        expect(reset.history.containsKey(today), isFalse);
        expect(reset.history[daysAgo(1)], 5);
      });

      test('streakDeadline allows one more miss: the end of tomorrow while today is unfinished', () {
        final habit = TestData.createTestHabit(target: 1, history: {daysAgo(1): 1}).refresh();
        expect(habit.streakDeadline(), DateTime(today.year, today.month, today.day + 2));
        expect(habit.nextMissAt(), DateTime(today.year, today.month, today.day + 1));
      });

      test('streakDeadline after a miss is the end of today', () {
        final habit = TestData.createTestHabit(target: 1, history: {daysAgo(2): 1}).refresh();
        expect(habit.streak.atRisk, isTrue);
        expect(habit.streakDeadline(), DateTime(today.year, today.month, today.day + 1));
      });

      test('momentum builds from history, including days logged before the habit was created', () {
        final history = {for (var i = 1; i <= 10; i++) daysAgo(i): 1};
        final habit = TestData.createTestHabit(target: 1, history: history).refresh();

        expect(habit.momentum, MomentumCalculator.calculate(
          history: history,
          target: 1,
          schedule: habit.schedule,
          start: daysAgo(10),
          now: habit.lastUpdatedDate,
        ));
        expect(habit.momentum.score, greaterThan(20));
        expect(habit.momentum.isRising, isTrue);
        // Worked out once per habit
        expect(identical(habit.momentum, habit.momentum), isTrue);
      });

      test('a new habit has no momentum yet', () {
        final habit = Habit.create(name: 'New', target: 1, color: HabitColor.blue, categoryId: 'body');
        expect(habit.momentum.score, 0);
      });

      test('changing the target recomputes progress and streak', () {
        final habit = TestData.createTestHabit(
          target: 2,
          history: {daysAgo(1): 2, today: 2},
        ).refresh();
        expect(habit.streak.current, 2);

        final harder = habit.updateDetails(target: 3);
        expect(harder.streak.current, 0);
        expect(harder.isCompleted, isFalse);
      });
    });

    // table_calendar hands us days as DateTime.utc(y, m, d). West of UTC,
    // converting those to local time lands on the previous day.
    group('UTC calendar dates', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final threeDaysAgo = DateTime(today.year, today.month, today.day - 3);
      final threeDaysAgoUtc = DateTime.utc(threeDaysAgo.year, threeDaysAgo.month, threeDaysAgo.day);

      test('setProgressForDate writes to the same calendar day', () {
        final habit = TestData.createTestHabit(target: 8).setProgressForDate(threeDaysAgoUtc, 3);

        expect(habit.history[threeDaysAgo], 3);
        expect(habit.history, hasLength(1));
      });

      test('repeated edits accumulate on that day', () {
        var habit = TestData.createTestHabit(target: 8);
        for (var i = 1; i <= 3; i++) {
          habit = habit.setProgressForDate(threeDaysAgoUtc, habit.getProgressForDate(threeDaysAgoUtc) + 1);
        }
        expect(habit.getProgressForDate(threeDaysAgoUtc), 3);
      });

      test('completion and period totals read the same calendar day', () {
        final habit = TestData.createTestHabit(target: 8, history: {threeDaysAgo: 8});

        expect(habit.progressForPeriodContaining(threeDaysAgoUtc), 8);
        expect(habit.wasCompletedOnDate(threeDaysAgoUtc), isTrue);

        final undone = habit.setProgressForDate(threeDaysAgoUtc, 7);
        expect(undone.wasCompletedOnDate(threeDaysAgoUtc), isFalse);
      });
    });

    group('schedules', () {
      test('create keeps weekdays only where they apply', () {
        Habit make(ResetFrequency f, {int interval = 1}) => Habit.create(
              name: 'X',
              target: 1,
              color: HabitColor.blue,
              categoryId: BuiltInCategoryIds.body,
              resetFrequency: f,
              resetInterval: interval,
              scheduledWeekdays: const [1, 3, 5],
            );

        expect(make(ResetFrequency.daily).scheduledWeekdays, [1, 3, 5]);
        expect(make(ResetFrequency.daily, interval: 2).scheduledWeekdays, isNull);
        expect(make(ResetFrequency.weekly).scheduledWeekdays, isNull);
      });

      test('updateDetails can go back to every day by passing all seven days', () {
        final habit = TestData.createTestHabit().updateDetails(scheduledWeekdays: [1, 3, 5]);
        expect(habit.scheduledWeekdays, [1, 3, 5]);

        final everyDay = habit.updateDetails(scheduledWeekdays: [1, 2, 3, 4, 5, 6, 7]);
        expect(everyDay.scheduledWeekdays, isNull);
        expect(everyDay.isDueOn(DateTime(2026, 10, 17)), isTrue);
      });

      test('switching to weekly drops weekdays', () {
        final habit = TestData.createTestHabit().updateDetails(scheduledWeekdays: [1, 3, 5]);
        expect(habit.updateDetails(resetFrequency: ResetFrequency.weekly).scheduledWeekdays, isNull);
      });

      test('an every-2-days habit keeps progress across both days of a block', () {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final habit = TestData.createTestHabit(
          target: 4,
          resetAnchorDate: DateTime(today.year, today.month, today.day - 1),
          history: {DateTime(today.year, today.month, today.day - 1): 2},
        ).updateDetails(resetInterval: 2);

        expect(habit.progress, 2);
        expect(habit.updateProgress(3).history[today], 1);
      });
    });

    group('habit icon', () {
      final withIcon = TestData.createTestHabit().updateDetails(icon: 'water');

      test('an empty icon removes it', () {
        expect(withIcon.metadata.icon, 'water');
        expect(withIcon.updateDetails(icon: '').metadata.icon, isNull);
      });

      test('no icon argument keeps the current one', () {
        expect(withIcon.updateDetails(name: 'Hydrate').metadata.icon, 'water');
      });

      test('a habit without an icon round-trips through JSON', () {
        final none = withIcon.updateDetails(icon: '');
        expect(Habit.fromJson(none.toJson()).metadata.icon, isNull);
      });
    });

    group('category ids', () {
      test('an unknown category id is kept, not turned into Body', () {
        final habit = TestData.createTestHabit(categoryId: 'hobbies');
        expect(Habit.fromJson(habit.toJson()).categoryId, 'hobbies');
      });

      test('a missing category loads as blank (shown as Uncategorized)', () {
        final json = TestData.habitJsonData..remove('category');
        expect(Habit.fromJson(json).categoryId, '');
      });
    });

    group('reset anchor', () {
      test('create defaults the anchor to today', () {
        final habit = Habit.create(
          name: 'Weekly',
          target: 1,
          color: HabitColor.blue,
          categoryId: BuiltInCategoryIds.body,
          resetFrequency: ResetFrequency.weekly,
        );
        final now = DateTime.now();

        expect(habit.resetAnchor, DateTime(now.year, now.month, now.day));
      });

      test('create keeps a chosen anchor as a date only', () {
        final habit = Habit.create(
          name: 'Monthly',
          target: 1,
          color: HabitColor.blue,
          categoryId: BuiltInCategoryIds.body,
          resetFrequency: ResetFrequency.monthly,
          resetAnchor: DateTime(2024, 3, 20, 17, 45),
        );

        expect(habit.resetAnchor, DateTime(2024, 3, 20));
      });

      test('habits saved without an anchor fall back to their creation date', () {
        final habit = TestData.createTestHabit();
        expect(habit.resetAnchorDate, isNull);
        expect(habit.resetAnchor, habit.metadata.createdDate);
      });

      test('updateDetails can move the anchor', () {
        final habit = TestData.createTestHabit(resetFrequency: ResetFrequency.weekly);
        final moved = habit.updateDetails(resetAnchor: DateTime(2024, 1, 18, 9));

        expect(moved.resetAnchor, DateTime(2024, 1, 18));
      });

      test('the anchor survives a JSON round-trip', () {
        final habit = TestData.createTestHabit(resetAnchorDate: DateTime(2024, 1, 18));
        expect(Habit.fromJson(habit.toJson()).resetAnchorDate, DateTime(2024, 1, 18));
      });
    });
  });
}