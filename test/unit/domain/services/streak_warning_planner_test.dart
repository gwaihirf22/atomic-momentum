import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/entities/streak_warning_settings.dart';
import 'package:atomic_momentum/domain/services/streak_warning_planner.dart';
import '../../../helpers/test_data.dart';

void main() {
  // 2024-01-15 is a Monday
  final noon = DateTime(2024, 1, 15, 12);
  const fourHours = StreakWarningSettings.defaults;
  const withFirstMiss = StreakWarningSettings(
    enabled: true,
    leadTime: Duration(hours: 4),
    remindBeforeFirstMiss: true,
  );

  group('StreakWarningPlanner.plan', () {
    test('by default warns only before the second miss, which would end the streak', () {
      // Today unfinished: missing it is one miss; the streak ends if tomorrow is missed too
      final habit = TestData.createTestHabit(
        name: 'Read',
        target: 1,
        history: {DateTime(2024, 1, 13): 1, DateTime(2024, 1, 14): 1},
      ).refresh(noon);

      final warning = StreakWarningPlanner.plan(habit, fourHours, noon).single;

      expect(warning.kind, StreakWarningKind.secondMiss);
      expect(warning.at, DateTime(2024, 1, 16, 20));
      expect(warning.title, "Don't miss twice: Read");
      expect(warning.body, 'Complete "Read" before midnight tonight to keep your 2 day streak.');
    });

    test('after a miss, warns 4 hours before midnight tonight', () {
      final habit = TestData.createTestHabit(
        name: 'Read',
        target: 1,
        history: {DateTime(2024, 1, 13): 1},
      ).refresh(noon);

      final warning = StreakWarningPlanner.plan(habit, fourHours, noon).single;

      expect(warning.at, DateTime(2024, 1, 15, 20));
      expect(warning.body, 'Complete "Read" before midnight tonight to keep your 1 day streak.');
    });

    test('once today is done, the warning moves a day later', () {
      final habit = TestData.createTestHabit(
        target: 1,
        history: {DateTime(2024, 1, 14): 1, DateTime(2024, 1, 15): 1},
      ).refresh(noon);

      final warning = StreakWarningPlanner.plan(habit, fourHours, noon).single;

      expect(warning.at, DateTime(2024, 1, 17, 20));
      expect(warning.body, contains('2 day streak'));
    });

    test('honours a custom lead time', () {
      final habit = TestData.createTestHabit(target: 1, history: {DateTime(2024, 1, 13): 1}).refresh(noon);
      const oneHour = StreakWarningSettings(enabled: true, leadTime: Duration(hours: 1));

      expect(StreakWarningPlanner.plan(habit, oneHour, noon).single.at, DateTime(2024, 1, 15, 23));
    });

    test('a 1-day lead on a weekly habit warns the day before its last chance ends', () {
      // Monday-anchored weeks; the week of the 8th was missed, so this week is
      // the last chance and ends at midnight Sunday -> Monday 22nd
      final habit = TestData.createTestHabit(
        target: 1,
        resetFrequency: ResetFrequency.weekly,
        resetAnchorDate: DateTime(2024, 1, 15),
        history: {DateTime(2024, 1, 3): 1},
      ).refresh(noon);
      const oneDay = StreakWarningSettings(enabled: true, leadTime: Duration(hours: 24));

      final warning = StreakWarningPlanner.plan(habit, oneDay, noon).single;

      expect(warning.at, DateTime(2024, 1, 21));
      expect(warning.body, contains('1 week streak'));
    });

    test('nothing when warnings are turned off', () {
      final habit = TestData.createTestHabit(target: 1, history: {DateTime(2024, 1, 13): 1}).refresh(noon);
      const off = StreakWarningSettings(enabled: false, leadTime: Duration(hours: 4), remindBeforeFirstMiss: true);

      expect(StreakWarningPlanner.plan(habit, off, noon), isEmpty);
    });

    test('nothing when there is no streak to lose', () {
      final habit = TestData.createTestHabit(target: 1).refresh(noon);
      expect(StreakWarningPlanner.plan(habit, withFirstMiss, noon), isEmpty);
    });

    test('nothing once the warning time has passed', () {
      final late = DateTime(2024, 1, 15, 21);
      final habit = TestData.createTestHabit(target: 1, history: {DateTime(2024, 1, 13): 1}).refresh(late);

      expect(StreakWarningPlanner.plan(habit, fourHours, late), isEmpty);
    });
  });

  group('remind before a first miss', () {
    test('adds a gentle nudge before today ends, soonest first', () {
      final habit = TestData.createTestHabit(
        name: 'Read',
        target: 1,
        history: {DateTime(2024, 1, 13): 1, DateTime(2024, 1, 14): 1},
      ).refresh(noon);

      final warnings = StreakWarningPlanner.plan(habit, withFirstMiss, noon);

      expect(warnings.map((w) => w.kind), [StreakWarningKind.firstMiss, StreakWarningKind.secondMiss]);
      expect(warnings.first.at, DateTime(2024, 1, 15, 20));
      expect(warnings.first.title, 'Keep Read going');
      expect(warnings.first.body, 'Complete "Read" before midnight tonight to keep your momentum.');
      expect(warnings.last.at, DateTime(2024, 1, 16, 20));
    });

    test('with today done, the nudge is for tomorrow', () {
      final habit = TestData.createTestHabit(
        target: 1,
        history: {DateTime(2024, 1, 14): 1, DateTime(2024, 1, 15): 1},
      ).refresh(noon);

      final warnings = StreakWarningPlanner.plan(habit, withFirstMiss, noon);
      expect(warnings.map((w) => w.at), [DateTime(2024, 1, 16, 20), DateTime(2024, 1, 17, 20)]);
    });

    test('after a miss there is only the "don\'t miss twice" warning', () {
      final habit = TestData.createTestHabit(target: 1, history: {DateTime(2024, 1, 13): 1}).refresh(noon);

      final warning = StreakWarningPlanner.plan(habit, withFirstMiss, noon).single;
      expect(warning.kind, StreakWarningKind.secondMiss);
    });
  });
}
