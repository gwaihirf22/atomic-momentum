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
