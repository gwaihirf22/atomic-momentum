import 'package:flutter/material.dart';
import '../../lib/domain/entities/habit.dart';
import '../../lib/domain/entities/habit_category.dart';
import '../../lib/domain/entities/habit_color.dart';
import '../../lib/domain/entities/reset_frequency.dart';
import '../../lib/domain/entities/streak_data.dart';
import '../../lib/domain/entities/reminder_settings.dart';
import '../../lib/domain/entities/habit_metadata.dart';

class TestData {
  static DateTime get testDate => DateTime(2024, 1, 15, 10, 30);
  static DateTime get yesterday => testDate.subtract(const Duration(days: 1));
  static DateTime get tomorrow => testDate.add(const Duration(days: 1));

  static Habit createTestHabit({
    String? id,
    String? name,
    int? progress,
    int? target,
    HabitColor? color,
    HabitCategory? category,
    DateTime? lastUpdatedDate,
    ResetFrequency? resetFrequency,
    Map<DateTime, int>? history,
    StreakData? streak,
    ReminderSettings? reminder,
    HabitMetadata? metadata,
  }) {
    return Habit(
      id: id ?? 'test_habit_1',
      name: name ?? 'Test Habit',
      progress: progress ?? 5,
      target: target ?? 10,
      color: color ?? HabitColor.blue,
      category: category ?? HabitCategory.body,
      lastUpdatedDate: lastUpdatedDate ?? testDate,
      resetFrequency: resetFrequency ?? ResetFrequency.daily,
      history: history ?? {},
      streak: streak ?? StreakData.empty(),
      reminder: reminder,
      metadata: metadata ?? HabitMetadata.create(),
    );
  }

  static List<Habit> createTestHabits(int count) {
    return List.generate(count, (index) => createTestHabit(
      id: 'test_habit_$index',
      name: 'Test Habit $index',
      progress: index % 10,
      target: 10,
      category: HabitCategory.values[index % HabitCategory.values.length],
    ));
  }

  static Habit get waterHabit => createTestHabit(
    id: 'water_habit',
    name: 'Drink Water',
    progress: 6,
    target: 8,
    color: HabitColor.blue,
    category: HabitCategory.body,
  );

  static Habit get exerciseHabit => createTestHabit(
    id: 'exercise_habit',
    name: 'Exercise',
    progress: 1,
    target: 1,
    color: HabitColor.orange,
    category: HabitCategory.body,
  );

  static Habit get readingHabit => createTestHabit(
    id: 'reading_habit',
    name: 'Read',
    progress: 30,
    target: 30,
    color: HabitColor.green,
    category: HabitCategory.mind,
    reminder: ReminderSettings.daily(
      time: const TimeOfDay(hour: 20, minute: 0),
      customMessage: 'Time to read!',
    ),
  );

  static StreakData get sampleStreak => StreakData(
    current: 5,
    longest: 12,
    lastUpdateDate: testDate,
    history: [
      StreakPeriod(
        startDate: testDate.subtract(const Duration(days: 4)),
        endDate: null,
        length: 5,
      ),
    ],
  );

  static Map<DateTime, int> get sampleHistory => {
    testDate: 8,
    yesterday: 6,
    testDate.subtract(const Duration(days: 2)): 4,
    testDate.subtract(const Duration(days: 3)): 7,
    testDate.subtract(const Duration(days: 4)): 8,
  };

  static ReminderSettings get morningReminder => ReminderSettings.daily(
    time: const TimeOfDay(hour: 8, minute: 0),
    customMessage: 'Good morning! Time for your habit.',
  );

  static ReminderSettings get weekdayReminder => ReminderSettings.weekdays(
    time: const TimeOfDay(hour: 17, minute: 30),
    customMessage: 'Weekday reminder!',
  );

  static HabitMetadata get sampleMetadata => HabitMetadata(
    createdDate: testDate.subtract(const Duration(days: 30)),
    lastModifiedDate: testDate,
    version: 2,
    icon: 'water_drop',
    customFields: {'notes': 'Test habit for water tracking'},
  );

  // JSON test data
  static Map<String, dynamic> get habitJsonData => {
    'id': 'test_habit_json',
    'name': 'JSON Test Habit',
    'progress': 7,
    'target': 10,
    'color': {
      'value': 0xFF2196F3,
      'hex': '#2196F3',
      'name': 'Blue',
    },
    'category': 'body',
    'lastUpdatedDate': testDate.toIso8601String(),
    'resetFrequency': 'daily',
    'history': {
      testDate.toIso8601String(): 7,
      yesterday.toIso8601String(): 5,
    },
    'streak': {
      'current': 3,
      'longest': 8,
      'lastUpdateDate': testDate.toIso8601String(),
      'history': [
        {
          'startDate': testDate.subtract(const Duration(days: 2)).toIso8601String(),
          'endDate': null,
          'length': 3,
        }
      ],
    },
    'reminder': {
      'time': '08:00',
      'enabled': true,
      'daysOfWeek': [1, 2, 3, 4, 5],
      'customMessage': 'Morning reminder',
    },
    'metadata': {
      'createdDate': testDate.subtract(const Duration(days: 10)).toIso8601String(),
      'lastModifiedDate': testDate.toIso8601String(),
      'version': 1,
      'icon': 'test_icon',
      'customFields': {},
    },
  };

  // Invalid data for testing error cases
  static Map<String, dynamic> get invalidHabitJsonData => {
    'id': '', // Invalid empty ID
    'name': '', // Invalid empty name
    'progress': -1, // Invalid negative progress
    'target': 0, // Invalid zero target
    'color': {
      'value': 'invalid', // Invalid color value
      'hex': 'not_a_color',
      'name': '',
    },
    'category': 'invalid_category',
    'lastUpdatedDate': 'invalid_date',
    'resetFrequency': 'invalid_frequency',
    'history': 'not_a_map',
    'streak': 'not_an_object',
    'reminder': 'not_an_object',
    'metadata': 'not_an_object',
  };
}