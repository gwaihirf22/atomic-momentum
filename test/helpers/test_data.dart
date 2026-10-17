import 'package:flutter/material.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/entities/streak_data.dart';
import 'package:atomic_momentum/domain/entities/reminder_settings.dart';
import 'package:atomic_momentum/domain/entities/habit_metadata.dart';

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
    String? categoryId,
    DateTime? lastUpdatedDate,
    ResetFrequency? resetFrequency,
    Map<DateTime, int>? history,
    StreakData? streak,
    ReminderSettings? reminder,
    HabitMetadata? metadata,
    String units = '',
    DateTime? resetAnchorDate,
  }) {
    return Habit(
      id: id ?? 'test_habit_1',
      name: name ?? 'Test Habit',
      progress: progress ?? 5,
      target: target ?? 10,
      units: units,
      color: color ?? HabitColor.blue,
      categoryId: categoryId ?? BuiltInCategoryIds.body,
      lastUpdatedDate: lastUpdatedDate ?? testDate,
      resetFrequency: resetFrequency ?? ResetFrequency.daily,
      history: history ?? {},
      streak: streak ?? StreakData.empty(),
      reminder: reminder,
      metadata: metadata ?? HabitMetadata(
        createdDate: testDate,
        lastModifiedDate: testDate,
        version: 1,
        customFields: {},
      ),
      resetAnchorDate: resetAnchorDate,
    );
  }

  static List<Habit> createTestHabits(int count) {
    return List.generate(count, (index) => createTestHabit(
      id: 'test_habit_$index',
      name: 'Test Habit $index',
      progress: index % 10,
      target: 10,
      categoryId: BuiltInCategoryIds.all[index % BuiltInCategoryIds.all.length],
    ));
  }

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

  static ReminderSettings get morningReminder => ReminderSettings.daily(
    time: const TimeOfDay(hour: 8, minute: 0),
    customMessage: 'Good morning! Time for your habit.',
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
}
