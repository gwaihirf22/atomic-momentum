import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/entities/streak_warning_settings.dart';
import 'package:atomic_momentum/domain/services/streak_warning_planner.dart';
import '../../../helpers/test_data.dart';

void main() {
  // 2024-01-15 is a Monday
  final noon = DateTime(2024, 1, 15, 12);
  const fourHours = StreakWarningSettings.defaults;

  group('StreakWarningPlanner.plan', () {
    test('warns 4 hours before midnight while today is unfinished', () {
      final habit = TestData.createTestHabit(
        name: 'Read',
        target: 1,
        history: {DateTime(2024, 1, 13): 1, DateTime(2024, 1, 14): 1},
      ).refresh(noon);

      final warning = StreakWarningPlanner.plan(habit, fourHours, noon)!;

      expect(warning.at, DateTime(2024, 1, 15, 20));
      expect(warning.title, contains('Read'));
      expect(warning.body, 'Complete "Read" before midnight tonight to keep your 2-day streak.');
    });

    test('once today is done, warns about tomorrow instead', () {
      final habit = TestData.createTestHabit(
        target: 1,
        history: {DateTime(2024, 1, 14): 1, DateTime(2024, 1, 15): 1},
      ).refresh(noon);

      final warning = StreakWarningPlanner.plan(habit, fourHours, noon)!;

      expect(warning.at, DateTime(2024, 1, 16, 20));
      expect(warning.body, contains('2-day streak'));
    });

    test('honours a custom lead time', () {
      final habit = TestData.createTestHabit(target: 1, history: {DateTime(2024, 1, 14): 1}).refresh(noon);
      const oneHour = StreakWarningSettings(enabled: true, leadTime: Duration(hours: 1));

      expect(StreakWarningPlanner.plan(habit, oneHour, noon)!.at, DateTime(2024, 1, 15, 23));
    });

    test('a 1-day lead on a weekly habit warns the day before the week ends', () {
      // Monday-anchored week ends at midnight Sunday -> Monday 22nd
      final habit = TestData.createTestHabit(
        target: 1,
        resetFrequency: ResetFrequency.weekly,
        resetAnchorDate: DateTime(2024, 1, 15),
        history: {DateTime(2024, 1, 10): 1},
      ).refresh(noon);
      const oneDay = StreakWarningSettings(enabled: true, leadTime: Duration(hours: 24));

      final warning = StreakWarningPlanner.plan(habit, oneDay, noon)!;

      expect(warning.at, DateTime(2024, 1, 21));
      expect(warning.body, contains('1-week streak'));
    });

    test('returns null when warnings are turned off', () {
      final habit = TestData.createTestHabit(target: 1, history: {DateTime(2024, 1, 14): 1}).refresh(noon);
      const off = StreakWarningSettings(enabled: false, leadTime: Duration(hours: 4));

      expect(StreakWarningPlanner.plan(habit, off, noon), isNull);
    });

    test('returns null when there is no streak to lose', () {
      final habit = TestData.createTestHabit(target: 1).refresh(noon);
      expect(StreakWarningPlanner.plan(habit, fourHours, noon), isNull);
    });

    test('returns null once the warning time has passed', () {
      final late = DateTime(2024, 1, 15, 21);
      final habit = TestData.createTestHabit(target: 1, history: {DateTime(2024, 1, 14): 1}).refresh(late);

      expect(StreakWarningPlanner.plan(habit, fourHours, late), isNull);
    });
  });
}
