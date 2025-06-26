import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../../lib/domain/entities/habit.dart';
import '../../../../lib/domain/entities/habit_category.dart';
import '../../../../lib/domain/entities/habit_color.dart';
import '../../../../lib/domain/entities/reset_frequency.dart';
import '../../../../lib/domain/entities/streak_data.dart';
import '../../../../lib/domain/entities/reminder_settings.dart';
import '../../../../lib/domain/entities/habit_metadata.dart';
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
        expect(habit.category, HabitCategory.body);
        expect(habit.resetFrequency, ResetFrequency.daily);
        expect(habit.history, isEmpty);
        expect(habit.streak, StreakData.empty());
      });
    });

    group('create factory', () {
      test('should create new habit with generated ID and default values', () {
        final habit = Habit.create(
          name: 'New Habit',
          target: 8,
          color: HabitColor.green,
          category: HabitCategory.mind,
        );

        expect(habit.id, startsWith('habit_'));
        expect(habit.name, 'New Habit');
        expect(habit.progress, 0);
        expect(habit.target, 8);
        expect(habit.color, HabitColor.green);
        expect(habit.category, HabitCategory.mind);
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
          category: HabitCategory.career,
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
          category: HabitCategory.spirit,
          resetFrequency: ResetFrequency.weekly,
          reminder: newReminder,
          icon: 'new_icon',
        );

        expect(updated.name, 'Updated Name');
        expect(updated.target, 15);
        expect(updated.color, HabitColor.red);
        expect(updated.category, HabitCategory.spirit);
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
        expect(updated.category, habit.category); // Should remain same
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
        expect(habit.category, HabitCategory.body);
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
  });
}