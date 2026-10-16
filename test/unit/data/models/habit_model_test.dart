import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/data/models/habit_model.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import '../../../helpers/test_data.dart';

void main() {
  group('HabitModel persistence', () {
    test('round-trips units and reset anchor through JSON', () {
      final habit = TestData.createTestHabit(
        units: 'glasses',
        resetFrequency: ResetFrequency.weekly,
        resetAnchorDate: DateTime(2024, 1, 18),
      );

      final restored = HabitModel.fromJson(HabitModel.fromDomain(habit).toJson()).toDomain();

      expect(restored.units, 'glasses');
      expect(restored.resetAnchorDate, DateTime(2024, 1, 18));
      expect(restored, habit);
    });

    test('round-trips the repeat interval and weekdays', () {
      final habit = TestData.createTestHabit().copyWith(resetInterval: 2, scheduledWeekdays: [1, 3, 5]);

      final restored = HabitModel.fromJson(HabitModel.fromDomain(habit).toJson()).toDomain();

      expect(restored.resetInterval, 2);
      expect(restored.scheduledWeekdays, [1, 3, 5]);
      expect(restored, habit);
    });

    test('older JSON without schedule fields means every day, interval 1', () {
      final json = HabitModel.fromDomain(TestData.createTestHabit()).toJson()
        ..remove('resetInterval')
        ..remove('scheduledWeekdays');

      final restored = HabitModel.fromJson(json);

      expect(restored.resetInterval, 1);
      expect(restored.scheduledWeekdays, isNull);
      expect(restored.schedule.hasRestDays, isFalse);
    });

    test('a habit saved without a category still loads, as Uncategorized', () {
      final json = HabitModel.fromDomain(TestData.createTestHabit()).toJson()..remove('category');

      final restored = HabitModel.fromJson(json);

      expect(restored.categoryId, '');
      expect(restored.name, 'Test Habit');
    });

    test('compact storage JSON keeps history older than 90 days', () {
      final longAgo = DateTime.now().subtract(const Duration(days: 400));
      final day = DateTime(longAgo.year, longAgo.month, longAgo.day);
      final habit = TestData.createTestHabit(history: {day: 3});

      final restored = HabitModel.fromJson(HabitModel.fromDomain(habit).toCompactJson());

      expect(restored.history[day], 3);
    });

    test('loads JSON saved before units and anchor existed', () {
      final json = HabitModel.fromDomain(TestData.createTestHabit()).toJson()
        ..remove('units')
        ..remove('resetAnchor');

      final restored = HabitModel.fromJson(json);

      expect(restored.units, '');
      expect(restored.resetAnchorDate, isNull);
      expect(restored.resetAnchor, restored.metadata.createdDate);
    });
  });
}
