import 'package:flutter/material.dart' show TimeOfDay;
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/reminder_settings.dart';
import '../../domain/repositories/habit_repository.dart';
import '../logging/log.dart';

/// Set once smart reminders have been switched on for existing habits.
const smartRemindersDefaultedKey = 'smartRemindersDefaulted';

/// Gives every habit that has never had a reminder a smart one at [time].
/// Runs once: afterwards a reminder someone turns off stays off (it's saved
/// as disabled, not removed). Returns how many habits got a reminder.
Future<int> enableSmartRemindersOnce({
  required HabitRepository repository,
  required SharedPreferences prefs,
  required TimeOfDay time,
}) async {
  if (prefs.getBool(smartRemindersDefaultedKey) ?? false) return 0;
  var count = 0;
  try {
    for (final habit in await repository.getHabits()) {
      if (habit.reminder != null) continue;
      await repository.saveHabit(habit.copyWith(reminder: ReminderSettings.smart(time: time)));
      count++;
    }
    await prefs.setBool(smartRemindersDefaultedKey, true);
  } catch (e) {
    // Try again next launch
    logWarning('Could not switch on smart reminders: $e');
  }
  return count;
}
