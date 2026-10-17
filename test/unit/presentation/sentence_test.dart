import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/habit_schedule.dart';
import 'package:atomic_momentum/domain/entities/reminder_settings.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/presentation/habit_form/sentence.dart';

/// The words of the Story sentence.
void main() {
  group('name', () {
    test('a capital that only starts the sentence is dropped', () {
      expect(HabitSentence.name('Drink water'), 'drink water');
      expect(HabitSentence.name('  Read  '), 'read');
    });

    test('capitals that are part of a word stay', () {
      expect(HabitSentence.name('TV off by 10'), 'TV off by 10');
      expect(HabitSentence.name('iPad down'), 'iPad down');
      expect(HabitSentence.name('5k run'), '5k run');
      expect(HabitSentence.name('A'), 'A');
    });
  });

  group('amount', () {
    test('with units', () {
      expect(HabitSentence.amount(8, 'glasses'), '8 glasses');
      expect(HabitSentence.amount(1, 'session'), '1 session');
    });

    test('without units, in words', () {
      expect(HabitSentence.amount(1, ''), 'once');
      expect(HabitSentence.amount(2, ' '), 'twice');
      expect(HabitSentence.amount(5, ''), '5 times');
    });

    test('nothing without a valid target', () {
      expect(HabitSentence.amount(null, 'glasses'), '');
      expect(HabitSentence.amount(0, 'glasses'), '');
    });
  });

  group('schedule', () {
    final anchor = DateTime(2026, 10, 15);
    String say(ResetFrequency frequency, {int interval = 1, List<int>? days}) => HabitSentence.schedule(
        HabitSchedule(frequency: frequency, interval: interval, anchor: anchor, weekdays: days));

    test('daily', () {
      expect(say(ResetFrequency.daily), 'every day');
      expect(say(ResetFrequency.daily, days: [1, 2, 3, 4, 5, 6, 7]), 'every day');
      expect(say(ResetFrequency.daily, days: [5, 1, 3]), 'on Mon, Wed and Fri');
      expect(say(ResetFrequency.daily, days: [2]), 'on Tue');
      expect(say(ResetFrequency.daily, days: [1, 2, 3, 4, 5]), 'on weekdays');
      expect(say(ResetFrequency.daily, days: [6, 7]), 'on weekends');
      expect(say(ResetFrequency.daily, interval: 2), 'every 2 days');
    });

    test('weekly, monthly and never', () {
      expect(say(ResetFrequency.weekly), 'each week');
      expect(say(ResetFrequency.weekly, interval: 2), 'every 2 weeks');
      expect(say(ResetFrequency.monthly), 'each month');
      expect(say(ResetFrequency.monthly, interval: 3), 'every 3 months');
      expect(say(ResetFrequency.never), 'in total');
    });
  });

  group('reminder', () {
    String say({bool enabled = true, ReminderMode mode = ReminderMode.smart, List<int> days = const []}) =>
        HabitSentence.reminder(
          enabled: enabled,
          mode: mode,
          time: const TimeOfDay(hour: 9, minute: 0),
          days: days,
          formatTime: (t) => '${t.hour}:00 AM',
        );

    test('smart, or custom on every day, is just the time', () {
      expect(say(), 'reminded at 9:00 AM');
      expect(say(mode: ReminderMode.custom, days: [1, 2, 3, 4, 5, 6, 7]), 'reminded at 9:00 AM');
    });

    test('custom days are named', () {
      expect(say(mode: ReminderMode.custom, days: [4, 1]), 'reminded at 9:00 AM on Mon and Thu');
    });

    test('off, or custom with no days, is no reminder', () {
      expect(say(enabled: false), 'with no reminder');
      expect(say(mode: ReminderMode.custom), 'with no reminder');
    });
  });
}
