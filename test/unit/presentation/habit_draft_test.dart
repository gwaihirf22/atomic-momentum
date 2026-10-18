import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/reminder_settings.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/entities/two_minute_version.dart';
import 'package:atomic_momentum/presentation/habit_form/habit_draft.dart';

/// The habit form's model, shared by the one-page form, Builder and Story.
void main() {
  const nine = TimeOfDay(hour: 9, minute: 0);

  HabitDraft newDraft() => HabitDraft.newHabit(categoryId: 'body', reminderTime: nine);

  Habit habit({
    ReminderSettings? reminder,
    TwoMinuteVersion? twoMinute,
    String? icon = 'water',
    List<int>? weekdays,
  }) =>
      Habit.create(
        name: 'Drink water',
        target: 8,
        units: 'glasses',
        color: HabitColor.teal,
        categoryId: 'mind',
        resetFrequency: ResetFrequency.daily,
        reminder: reminder,
        icon: icon,
        scheduledWeekdays: weekdays,
        twoMinute: twoMinute,
      );

  group('starts', () {
    test('a new habit: the given category, reminding smartly at the default time', () {
      final draft = newDraft();
      expect(draft.isEditing, isFalse);
      expect(draft.categoryId, 'body');
      expect(draft.reminderEnabled, isTrue);
      expect(draft.reminderMode, ReminderMode.smart);
      expect(draft.reminderTime, nine);
      expect(draft.frequency, ResetFrequency.daily);
      expect(draft.scheduleDays, HabitDraft.allDays);
      expect(draft.hasChanges, isFalse);
    });

    test('an edit: filled with what the habit has', () {
      final draft = HabitDraft.fromHabit(
        habit(
          reminder: ReminderSettings(
            time: const TimeOfDay(hour: 7, minute: 30),
            enabled: true,
            daysOfWeek: const [1, 3],
            customMessage: 'Sip!',
          ),
          twoMinute: const TwoMinuteVersion(description: 'One glass', minimum: 1, showOnCard: false),
          weekdays: [1, 3, 5],
        ),
        defaultReminderTime: nine,
      );
      expect(draft.name.text, 'Drink water');
      expect(draft.target.text, '8');
      expect(draft.units.text, 'glasses');
      expect(draft.color, HabitColor.teal);
      expect(draft.categoryId, 'mind');
      expect(draft.icon, 'water');
      expect(draft.scheduleDays, [1, 3, 5]);
      expect(draft.reminderMode, ReminderMode.custom);
      expect(draft.reminderTime, const TimeOfDay(hour: 7, minute: 30));
      expect(draft.reminderDays, [1, 3]);
      expect(draft.message.text, 'Sip!');
      expect(draft.tiny.text, 'One glass');
      expect(draft.tinyMinimum.text, '1');
      expect(draft.tinyShowOnCard, isFalse);
      expect(draft.hasChanges, isFalse);
    });

    test('an edit of a habit without a reminder starts with reminders off', () {
      final draft = HabitDraft.fromHabit(habit(), defaultReminderTime: nine);
      expect(draft.reminderEnabled, isFalse);
      expect(draft.reminderTime, nine);
    });
  });

  group('unsaved changes', () {
    test('typing or choosing counts; changing back does not', () {
      final draft = newDraft();
      var notified = 0;
      draft.addListener(() => notified++);

      draft.name.text = 'Read';
      expect(draft.hasChanges, isTrue);
      draft.name.text = '';
      expect(draft.hasChanges, isFalse);

      draft.edit(() => draft.color = HabitColor.green);
      expect(draft.hasChanges, isTrue);
      draft.edit(() => draft.color = HabitColor.blue);
      expect(draft.hasChanges, isFalse);
      expect(notified, 4, reason: 'text and edits both tell listeners');
    });
  });

  group('checks', () {
    test('name', () {
      expect(HabitDraft.validateName(''), 'Please enter a habit name');
      expect(HabitDraft.validateName(' a '), 'Habit name must be at least 2 characters');
      expect(HabitDraft.validateName('x' * 51), 'Habit name cannot exceed 50 characters');
      expect(HabitDraft.validateName('Read'), isNull);
    });

    test('target', () {
      expect(HabitDraft.validateTarget(''), 'Please enter a target number');
      expect(HabitDraft.validateTarget('0'), 'Target must be a positive number');
      expect(HabitDraft.validateTarget('two'), 'Target must be a positive number');
      expect(HabitDraft.validateTarget('1001'), 'Target cannot exceed 1,000');
      // Steps from Health go up to 100,000
      expect(HabitDraft.validateTarget('8000', most: 100000), isNull);
      expect(HabitDraft.validateTarget('100001', most: 100000), 'Target cannot exceed 100,000');
      expect(HabitDraft.validateTarget('8'), isNull);
    });

    test('units', () {
      expect(HabitDraft.validateUnits('x' * 21), 'Units cannot exceed 20 characters');
      expect(HabitDraft.validateUnits('glasses'), isNull);
    });

    test('the two-minute minimum is below the target, and only checked while it shows', () {
      final draft = newDraft()..target.text = '8';
      expect(draft.validateMinimum('8'), 'Enter a number from 1 to 7');
      expect(draft.validateMinimum('0'), 'Enter a number from 1 to 7');
      expect(draft.validateMinimum('3'), isNull);
      expect(draft.validateMinimum(''), isNull);

      draft.tinyMinimum.text = '9';
      expect(draft.minimumError, isNull, reason: 'no two-minute version, so no minimum field');
      draft.tiny.text = 'One glass';
      expect(draft.minimumError, 'Enter a number from 1 to 7');
    });

    test('isValid needs a name and a target', () {
      final draft = newDraft();
      expect(draft.isValid, isFalse);
      draft.name.text = 'Read';
      expect(draft.isValid, isFalse);
      draft.target.text = '10';
      expect(draft.isValid, isTrue);
    });
  });

  group('schedule', () {
    test('the last due day stays', () {
      final draft = newDraft();
      draft.edit(() => draft.scheduleDays = [3]);
      draft.toggleScheduleDay(3);
      expect(draft.scheduleDays, [3]);
      draft.toggleScheduleDay(1);
      expect(draft.scheduleDays, [1, 3]);
    });

    test('the start date matters for weekly habits and every few days', () {
      final draft = newDraft();
      expect(draft.startDateMatters, isFalse);
      draft.edit(() => draft.interval = 2);
      expect(draft.startDateMatters, isTrue);
      draft.edit(() {
        draft.interval = 1;
        draft.frequency = ResetFrequency.weekly;
      });
      expect(draft.startDateMatters, isTrue);
      draft.edit(() => draft.frequency = ResetFrequency.never);
      expect(draft.startDateMatters, isFalse);
    });
  });

  group('saves', () {
    test('a new habit with every value', () {
      final draft = newDraft()
        ..name.text = '  Read  '
        ..target.text = '10'
        ..units.text = 'pages'
        ..tiny.text = 'One page'
        ..tinyMinimum.text = '1';
      draft.edit(() {
        draft.icon = 'book';
        draft.color = HabitColor.teal;
        draft.scheduleDays = [1, 2, 3, 4, 5];
      });

      final params = draft.toCreateParams();
      expect(params.name, 'Read');
      expect(params.target, 10);
      expect(params.units, 'pages');
      expect(params.icon, 'book');
      expect(params.color, HabitColor.teal);
      expect(params.categoryId, 'body');
      expect(params.scheduledWeekdays, [1, 2, 3, 4, 5]);
      expect(params.twoMinute, const TwoMinuteVersion(description: 'One page', minimum: 1));
      expect(params.reminder!.isSmart, isTrue);
      expect(params.reminder!.time, nine);
    });

    test('no reminder for a new habit with reminders off', () {
      final draft = newDraft();
      draft.edit(() => draft.reminderEnabled = false);
      expect(draft.reminder, isNull);
    });

    test('custom days with none chosen is no reminder', () {
      final draft = newDraft();
      draft.edit(() {
        draft.reminderMode = ReminderMode.custom;
        draft.reminderDays = [];
      });
      expect(draft.reminder, isNull);
    });

    test('habits that never reset have no two-minute version, and an interval of 1', () {
      final draft = newDraft()
        ..name.text = 'Read 20 books'
        ..target.text = '20'
        ..tiny.text = 'One page';
      draft.edit(() {
        draft.frequency = ResetFrequency.never;
        draft.interval = 3;
      });
      final params = draft.toCreateParams();
      expect(params.twoMinute, isNull);
      expect(params.resetInterval, 1);
    });

    test('an edit: removing the icon, the two-minute version, and the reminder', () {
      final draft = HabitDraft.fromHabit(
        habit(
          reminder: ReminderSettings.smart(time: nine),
          twoMinute: const TwoMinuteVersion(description: 'One glass'),
        ),
        defaultReminderTime: nine,
      );
      draft.tiny.text = '';
      draft.edit(() {
        draft.icon = null;
        draft.reminderEnabled = false;
      });

      final params = draft.toUpdateParams();
      expect(params.icon, '', reason: "'' removes the icon");
      expect(params.twoMinute, isNull);
      expect(params.removeTwoMinute, isTrue);
      // Null would mean "unchanged" and leave the old reminder firing
      expect(params.reminder, isNotNull);
      expect(params.reminder!.enabled, isFalse);
    });

    test('an edit keeping its two-minute version does not remove it', () {
      final draft = HabitDraft.fromHabit(
        habit(twoMinute: const TwoMinuteVersion(description: 'One glass')),
        defaultReminderTime: nine,
      );
      expect(draft.toUpdateParams().removeTwoMinute, isFalse);
      expect(draft.toUpdateParams().twoMinute!.description, 'One glass');
    });
  });
}
