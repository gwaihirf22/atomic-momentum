import 'dart:convert';
import 'dart:isolate';
import 'package:clock/clock.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/datasources/shared_preferences_datasource.dart';
import '../../data/models/habit_model.dart';
import '../../data/repositories/quote_repository_impl.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/reset_frequency.dart';
import '../../domain/services/achievements.dart';
import '../services/achievement_store.dart';
import '../services/freeze_bank.dart';
import 'year_persona.dart';

/// Settings → Developer → "Load a year of use" (debug builds only): the
/// [YearPersona]'s year, ending today, put in place of the person's habits
/// so a mature app can be looked over by hand. Their own data is kept aside
/// and "Put my habits back" restores it exactly.
///
/// The year is built straight onto the habits (each action as the app would
/// make it, at its moment), with no notifications or saves on the way; the
/// year simulation checks it comes out the same as the year lived through
/// the app.
class YearOfUse {
  const YearOfUse._();

  /// Where the person's own data waits while a year is loaded.
  static const backupKey = 'dev_backup_v1';

  /// What a year replaces, and so what's kept aside.
  static const keys = [
    SharedPreferencesDataSource.habitsKey,
    AchievementStore.key,
    FreezeBank.key,
    QuoteRepositoryImpl.mineKey,
    QuoteRepositoryImpl.savedKey,
    QuoteRepositoryImpl.chosenTodayKey,
  ];

  /// The id the persona's own quote gets in a built year.
  static const myQuoteId = 'mine-year-of-use';

  /// The year whose last day is [now]'s day.
  static YearPersona personaEnding(DateTime now) => YearPersona(DateTime(now.year, now.month, now.day - (YearPersona.length - 1)));

  /// The persona's habits after every visit up to [until].
  static List<Habit> build(YearPersona persona, DateTime until) {
    final habits = <String, Habit>{};
    for (final day in persona.days) {
      for (final visit in day.visits) {
        final at = visit.on(day.date);
        if (at.isAfter(until)) break;
        withClock(Clock.fixed(at), () {
          for (final action in visit.actions) {
            _apply(habits, action, at);
          }
        });
      }
    }
    return withClock(Clock.fixed(until), () => [for (final h in habits.values) h.refresh(until)]);
  }

  static void _apply(Map<String, Habit> habits, PersonaAction action, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    Habit of(String name) => habits[name]!;
    void set(String name, Habit h) => habits[name] = h;
    switch (action) {
      case CreateHabit(:final params):
        set(
          params.name,
          Habit.create(
            name: params.name.trim(),
            target: params.target,
            units: params.units,
            color: params.color,
            categoryId: params.categoryId,
            resetFrequency: params.resetFrequency ?? ResetFrequency.daily,
            reminder: params.reminder,
            icon: params.icon,
            resetAnchor: params.resetAnchor,
            resetInterval: params.resetInterval,
            scheduledWeekdays: params.scheduledWeekdays,
            twoMinute: params.twoMinute,
            goal: params.goal,
            notify: params.notify,
          ),
        );
      case SetTotal(:final habit, :final total):
        set(habit, of(habit).updateProgress(total));
      case LogOn(:final habit, :final day, :final amount):
        set(habit, of(habit).setProgressForDate(day, amount));
      case TwoMinuteTap(:final habit):
        set(habit, of(habit).setTwoMinuteForDate(today, true));
      case HoldToFinish(:final habit, :final undo):
        final h = of(habit);
        final before = h.periodDays(now);
        var after = h.isCompleted ? h.setDays({for (final d in before.keys) d: 0}) : h.updateProgress(h.target);
        if (undo) after = after.setDays(before);
        set(habit, after);
      case DayNote(:final habit, :final text):
        set(habit, of(habit).setDayNote(today, text));
      case StartFrom(:final habit, :final day):
        set(habit, of(habit).startFrom(day));
      case CountFrom(:final habit, :final day, :final clearEarlier):
        set(habit, (clearEarlier ? of(habit).clearBefore(day) : of(habit)).countFrom(day));
      case EditHabit(:final habit, :final params):
        set(
          habit,
          of(habit).updateDetails(
            name: params.name,
            target: params.target,
            units: params.units,
            color: params.color,
            categoryId: params.categoryId,
            resetFrequency: params.resetFrequency,
            reminder: params.reminder,
            icon: params.icon,
            resetAnchor: params.resetAnchor,
            resetInterval: params.resetInterval,
            scheduledWeekdays: params.scheduledWeekdays,
            twoMinute: params.twoMinute,
            removeTwoMinute: params.removeTwoMinute,
            notify: params.notify,
          ),
        );
      case DeleteHabit(:final habit):
        habits.remove(habit);
      case KeepQuote(:final habit, :final quoteId):
        set(habit, of(habit).addQuote(quoteId));
      case KeepMyQuote(:final habit):
        set(habit, of(habit).addQuote(myQuoteId));
      case DeleteMyQuote():
        for (final entry in habits.entries.toList()) {
          habits[entry.key] = entry.value.removeQuote(myQuoteId);
        }
      case FreezeDay(:final habit, :final day):
        final h = habits[habit];
        if (h != null && h.whyNoFreeze(day, now) == null) set(habit, h.freeze(day));
      case VacationMode(:final on):
        for (final entry in habits.entries.toList()) {
          habits[entry.key] = on ? entry.value.startPause(today) : entry.value.endPause(today);
        }
      // Settings, own quotes and "Another quote" are left as the person has them
      case AddMyQuote() || AnotherQuote() || ChangeSetting():
        break;
    }
  }

  static bool hasBackup(SharedPreferences prefs) => prefs.containsKey(backupKey);

  /// Keeps the person's data aside (once: loading again keeps the first
  /// copy) and puts a year ending [now] in its place. Its achievements are
  /// filed as seen, so there's no flood of celebrations.
  static Future<void> load(SharedPreferences prefs, DateTime now) async {
    if (!hasBackup(prefs)) {
      await prefs.setString(backupKey, jsonEncode({for (final key in keys) key: _read(prefs, key)}));
    }
    // A year takes a few seconds to build: off the main thread, so the app
    // keeps drawing
    final year = await Isolate.run(() => _stored(now));
    await prefs.setString(SharedPreferencesDataSource.habitsKey, year.habits);
    await prefs.setStringList(AchievementStore.key, year.seen);
    // A fresh bank: three freezes, the year's milestones filed as earned
    for (final key in [FreezeBank.key, QuoteRepositoryImpl.mineKey, QuoteRepositoryImpl.savedKey, QuoteRepositoryImpl.chosenTodayKey]) {
      await prefs.remove(key);
    }
  }

  /// The year ending [now] as stored: the habits' JSON, and its
  /// achievements' ids (all filed as seen).
  static ({String habits, List<String> seen}) _stored(DateTime now) {
    final habits = build(personaEnding(now), now);
    return (
      habits: jsonEncode([for (final h in habits) HabitModel.fromDomain(h).toCompactJson()]),
      seen: [for (final a in Achievements.earned(habits, now)) a.id]..sort(),
    );
  }

  /// Puts the person's own data back as it was, and forgets the backup.
  static Future<void> restore(SharedPreferences prefs) async {
    final saved = prefs.getString(backupKey);
    if (saved == null) return;
    final values = (jsonDecode(saved) as Map<String, dynamic>);
    for (final key in keys) {
      final value = values[key];
      if (value == null) {
        await prefs.remove(key);
      } else if (value is String) {
        await prefs.setString(key, value);
      } else if (value is List) {
        await prefs.setStringList(key, value.cast<String>());
      }
    }
    await prefs.remove(backupKey);
  }

  /// A key's value as stored (a string or a list of strings), or null.
  static Object? _read(SharedPreferences prefs, String key) => prefs.get(key);
}
