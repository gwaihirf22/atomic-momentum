import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/habit_goal.dart';
import 'package:atomic_momentum/domain/entities/reminder_settings.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/services/reminder_planner.dart';
import '../../../helpers/test_data.dart';

void main() {
  // 2026-10-12 is a Monday
  final monday = DateTime(2026, 10, 12);
  final eightAm = DateTime(2026, 10, 12, 8);
  const nine = TimeOfDay(hour: 9, minute: 0);

  Habit habit({
    ResetFrequency frequency = ResetFrequency.daily,
    int interval = 1,
    List<int>? weekdays,
    DateTime? anchor,
    int target = 1,
    String units = '',
    Map<DateTime, int>? history,
    ReminderSettings? reminder,
  }) =>
      TestData.createTestHabit(
        name: 'Run',
        target: target,
        units: units,
        resetFrequency: frequency,
        history: history ?? {},
        reminder: reminder ?? ReminderSettings.smart(time: nine),
        resetAnchorDate: anchor ?? monday,
      ).copyWith(resetInterval: interval, scheduledWeekdays: weekdays);

  List<DateTime> days(Habit h, {DateTime? now, int horizon = ReminderPlanner.horizonDays}) => [
        for (final r in ReminderPlanner.plan(h, now: now ?? eightAm, horizon: horizon))
          DateTime(r.at.year, r.at.month, r.at.day),
      ];

  DateTime oct(int day) => DateTime(2026, 10, day);

  group('smart reminders', () {
    test('a daily habit is reminded every day at its time, for two weeks', () {
      final planned = ReminderPlanner.plan(habit(), now: eightAm);
      expect(planned, hasLength(14));
      expect(planned.first.at, DateTime(2026, 10, 12, 9));
      expect(planned.last.at, DateTime(2026, 10, 25, 9));
    });

    test("today's reminder is skipped once its time has passed", () {
      expect(days(habit(), now: DateTime(2026, 10, 12, 10)).first, oct(13));
    });

    test('rest days get no reminder', () {
      expect(days(habit(weekdays: [1, 3, 5])), [oct(12), oct(14), oct(16), oct(19), oct(21), oct(23)]);
    });

    test("finishing today drops today's reminder", () {
      expect(days(habit(history: {monday: 1})).first, oct(13));
    });

    test('every 2 days: the day before it is due (each block\'s first day)', () {
      expect(days(habit(interval: 2)).take(3), [oct(12), oct(14), oct(16)]);
    });

    test('weekly, due Sunday: Thursday and Saturday', () {
      expect(days(habit(frequency: ResetFrequency.weekly)), [oct(15), oct(17), oct(22), oct(24)]);
    });

    test("a week that's already done goes quiet until next week", () {
      final done = habit(frequency: ResetFrequency.weekly, target: 3, history: {monday: 3});
      expect(days(done), [oct(22), oct(24)]);
    });

    test('every 2 weeks: 3 days and 1 day before it is due', () {
      expect(days(habit(frequency: ResetFrequency.weekly, interval: 2)), [oct(22), oct(24)]);
    });

    test('monthly: 7, 3 and 1 day before it is due', () {
      final monthly = habit(frequency: ResetFrequency.monthly, anchor: DateTime(2026, 10, 1));
      expect(days(monthly, horizon: 30), [oct(24), oct(28), oct(30)]);
    });

    test('monthly on the 31st counts down to the clamped month end', () {
      final monthly = habit(frequency: ResetFrequency.monthly, anchor: DateTime(2026, 1, 31));
      // Jan 31 - Feb 27 (the next period starts Feb 28, the 31st clamped)
      expect(days(monthly, now: DateTime(2026, 2, 10, 8), horizon: 20),
          [DateTime(2026, 2, 20), DateTime(2026, 2, 24), DateTime(2026, 2, 26)]);
    });

    test('habits that never reset are reminded daily until the total is reached', () {
      final lifetime = habit(frequency: ResetFrequency.never, target: 5, history: {oct(1): 2});
      expect(days(lifetime), hasLength(14));
      expect(days(habit(frequency: ResetFrequency.never, target: 5, history: {oct(1): 5})), isEmpty);
    });

    test('a turned-off reminder plans nothing', () {
      final off = habit(reminder: ReminderSettings.smart(time: nine).copyWith(enabled: false));
      expect(ReminderPlanner.plan(off, now: eightAm), isEmpty);
      expect(ReminderPlanner.plan(habit().copyWith(), now: eightAm), isNotEmpty);
    });
  });

  test("a habit being built gets the Log button; one being broken never does (it would log a slip)", () {
    expect(ReminderPlanner.plan(habit(), now: eightAm).every((r) => r.canLog), isTrue);
    final smoking = Habit.create(
      name: 'Smoking',
      target: 0,
      units: '',
      color: HabitColor.blue,
      categoryId: BuiltInCategoryIds.body,
      goal: HabitGoal.quit,
      reminder: ReminderSettings.smart(time: nine),
    );
    final checkIns = ReminderPlanner.plan(smoking, now: eightAm);
    expect(checkIns, isNotEmpty);
    expect(checkIns.any((r) => r.canLog), isFalse);
  });

  test('custom reminders fire on the chosen weekdays', () {
    const tueThu = ReminderSettings(time: nine, enabled: true, daysOfWeek: [2, 4]);
    expect(days(habit(reminder: tueThu)), [oct(13), oct(15), oct(20), oct(22)]);
  });

  group('notification text', () {
    PlannedReminder first(Habit h) => ReminderPlanner.plan(h, now: eightAm).first;

    test('a daily habit shows how much is left today', () {
      expect(first(habit(target: 8, units: 'glasses')).body, '0 of 8 glasses today');
      expect(first(habit(target: 8, units: 'glasses', history: {monday: 3})).body, '3 of 8 glasses today. Keep going!');
      expect(first(habit()).title, 'Run');
    });

    test('a countdown says when it is due', () {
      final weekly =
          ReminderPlanner.plan(habit(frequency: ResetFrequency.weekly, target: 3, units: 'runs'), now: eightAm);
      expect(weekly[0].body, '0 of 3 runs this week. Due Sunday');
      expect(weekly[1].body, '0 of 3 runs this week. Due tomorrow');
    });

    test('a custom message replaces the generated text', () {
      final custom = ReminderSettings.smart(time: nine, customMessage: 'Lace up!');
      expect(first(habit(reminder: custom)).body, 'Lace up!');
    });
  });

  group('describeSmart', () {
    String describe(Habit h) => ReminderPlanner.describeSmart(h.schedule, now: eightAm);

    test('describes each kind of schedule', () {
      expect(describe(habit()), 'Every day');
      expect(describe(habit(weekdays: [1, 3, 5])), 'On each due day (Mon, Wed, Fri)');
      expect(describe(habit(interval: 2)), "1 day before it's due");
      expect(describe(habit(frequency: ResetFrequency.weekly)), "3 days and 1 day before it's due (Thu and Sat)");
      expect(describe(habit(frequency: ResetFrequency.weekly, interval: 2)), "3 days and 1 day before it's due");
      expect(describe(habit(frequency: ResetFrequency.monthly)), "7, 3 and 1 day before it's due");
      expect(describe(habit(frequency: ResetFrequency.never)), "Every day until it's done");
    });
  });

  test('countdown nudges grow with the length of the period', () {
    expect(ReminderPlanner.countdownOffsets(1), [0]);
    expect(ReminderPlanner.countdownOffsets(3), [1]);
    expect(ReminderPlanner.countdownOffsets(7), [3, 1]);
    expect(ReminderPlanner.countdownOffsets(21), [3, 1]);
    expect(ReminderPlanner.countdownOffsets(30), [7, 3, 1]);
  });

  group('ReminderSettings', () {
    test('saves its mode; reminders saved before modes existed load as custom', () {
      final smart = ReminderSettings.smart(time: nine);
      expect(ReminderSettings.fromJson(smart.toJson()), smart);

      final old = smart.toJson()..remove('mode');
      expect(ReminderSettings.fromJson(old).mode, ReminderMode.custom);
    });
  });
}
