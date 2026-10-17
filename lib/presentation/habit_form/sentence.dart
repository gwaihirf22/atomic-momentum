import 'package:flutter/material.dart' show TimeOfDay;
import '../../domain/entities/habit_schedule.dart';
import '../../domain/entities/reminder_settings.dart';
import '../../domain/entities/reset_frequency.dart';
import 'habit_draft.dart';

/// A habit's parts in words, for the Story sentence ("I will drink water 8
/// glasses every day, reminded at 9:00 AM") and Builder's previews.
class HabitSentence {
  const HabitSentence._();

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// The name as it reads after "I will": a leading capital is dropped when
  /// it only starts a sentence ("Drink water" → "drink water"), not when
  /// it's part of a word ("TV off" stays).
  static String name(String raw) {
    final text = raw.trim();
    if (text.length < 2) return text;
    final first = text[0];
    final second = text[1];
    final startsSentence =
        first != first.toLowerCase() && second == second.toLowerCase() && second != second.toUpperCase();
    return startsSentence ? first.toLowerCase() + text.substring(1) : text;
  }

  /// "8 glasses", "1 session", "once", "twice", "5 times"; empty when
  /// there's no valid target yet.
  static String amount(int? target, String units) {
    if (target == null || target < 1) return '';
    final unit = units.trim();
    if (unit.isNotEmpty) return '$target $unit';
    return switch (target) {
      1 => 'once',
      2 => 'twice',
      _ => '$target times',
    };
  }

  /// "every day", "on weekdays", "on Mon, Wed and Fri", "every 2 days",
  /// "each week", "every 2 weeks", "each month", "in total".
  static String schedule(HabitSchedule schedule) {
    final n = schedule.interval;
    switch (schedule.frequency) {
      case ResetFrequency.never:
        return 'in total';
      case ResetFrequency.weekly:
        return n == 1 ? 'each week' : 'every $n weeks';
      case ResetFrequency.monthly:
        return n == 1 ? 'each month' : 'every $n months';
      case ResetFrequency.daily:
        if (n > 1) return 'every $n days';
        final days = schedule.weekdays;
        if (days == null || days.length == 7) return 'every day';
        return 'on ${dayList(days.toList()..sort())}';
    }
  }

  /// "weekdays", "weekends", or the days listed: "Mon, Wed and Fri".
  static String dayList(List<int> days) {
    if (days.length == 5 && days.every((d) => d <= 5)) return 'weekdays';
    if (days.length == 2 && days.every((d) => d >= 6)) return 'weekends';
    final names = [for (final d in days) _dayNames[d - 1]];
    if (names.length == 1) return names.single;
    return '${names.take(names.length - 1).join(', ')} and ${names.last}';
  }

  /// "reminded at 9:00 AM", "reminded at 9:00 AM on Mon and Thu", or
  /// "with no reminder". [formatTime] writes the time the device's way.
  static String reminder({
    required bool enabled,
    required ReminderMode mode,
    required TimeOfDay time,
    required List<int> days,
    required String Function(TimeOfDay) formatTime,
  }) {
    final custom = mode == ReminderMode.custom;
    if (!enabled || (custom && days.isEmpty)) return 'with no reminder';
    final at = 'reminded at ${formatTime(time)}';
    if (!custom || days.length == 7) return at;
    return '$at on ${dayList(List.of(days)..sort())}';
  }

  /// The draft's amount and schedule: "8 glasses every day".
  static String howOften(HabitDraft draft) {
    final amount = HabitSentence.amount(draft.enteredTarget, draft.units.text);
    final when = schedule(draft.schedule);
    return amount.isEmpty ? when : '$amount $when';
  }

  /// The draft's reminder, in words.
  static String reminderOf(HabitDraft draft, String Function(TimeOfDay) formatTime) => reminder(
        enabled: draft.reminderEnabled,
        mode: draft.reminderMode,
        time: draft.reminderTime,
        days: draft.reminderDays,
        formatTime: formatTime,
      );
}
