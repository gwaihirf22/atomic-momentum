import 'dart:math';

import 'package:flutter/material.dart' show TimeOfDay;

import '../../domain/entities/category.dart';
import '../../domain/entities/habit_color.dart';
import '../../domain/entities/habit_goal.dart';
import '../../domain/entities/reminder_settings.dart';
import '../../domain/entities/reset_frequency.dart';
import '../../domain/entities/two_minute_version.dart';
import '../../domain/usecases/create_habit_usecase.dart';
import '../dev/year_persona.dart';

/// The tours' example habits: someone who has used the app well for
/// [length] days, ending [today], so heatmaps are full and every kind of
/// habit is there (built daily, on some weekdays, weekly, monthly; one being
/// broken; one added later; freezes, a vacation week, notes, a quote).
///
/// Pure and the same for the same [today]: decisions come from dice seeded
/// per habit and day. The last days are scripted, so "today" always looks
/// the way the tours expect: Drink water at 5 of 8, Read not started,
/// Meditate missed yesterday ("Don't miss twice"), Social media clean.
class DemoPersona implements Persona {
  /// The last day of use.
  final DateTime today;

  DemoPersona(DateTime today) : today = DateTime(today.year, today.month, today.day);

  static const length = 200;

  static const water = 'Drink water';
  static const read = 'Read';
  static const meditate = 'Meditate';
  static const gym = 'Gym';
  static const callMum = 'Call Mum';
  static const budget = 'Budget review';
  static const social = 'Social media';
  static const journal = 'Journal';

  /// Every example habit, in the order they're added.
  static const names = [water, read, meditate, gym, callMum, budget, social, journal];

  /// Journal comes later: Calendar shows it grayed ("Added …") before then.
  static const journalAdded = 160;

  /// A week away in vacation mode (inclusive).
  static const vacationFrom = 110;
  static const vacationTo = 116;

  /// Days Meditate was frozen.
  static const meditateFrozen = [40, 95, 150];

  /// The scripted end: everything kept from here, but for today's state.
  static const scriptedFrom = length - 10;

  static const readQuote = 'epictetus-make-it-a-habit';

  /// Drink water's total so far today.
  static const waterToday = 5;

  DateTime get start => DateTime(today.year, today.month, today.day - (length - 1));
  DateTime date(int day) => DateTime(start.year, start.month, start.day + day);

  /// Gym's days: today's weekday and two more, spread through the week.
  late final List<int> gymDays = [
    for (final offset in const [0, 2, 4]) (today.weekday - 1 + offset) % 7 + 1,
  ]..sort();

  late final Map<String, CreateHabitParams> habits = {
    water: _habit(water, target: 8, units: 'glasses', color: HabitColor.blue, categoryId: BuiltInCategoryIds.body,
        twoMinute: const TwoMinuteVersion(description: 'Drink one glass', minimum: 1)),
    read: _habit(read, target: 20, units: 'pages', color: HabitColor.orange, categoryId: BuiltInCategoryIds.mind,
        reminderAt: const TimeOfDay(hour: 20, minute: 0),
        twoMinute: const TwoMinuteVersion(description: 'Read one page')),
    meditate: _habit(meditate, target: 10, units: 'minutes', color: HabitColor.deepPurple,
        categoryId: BuiltInCategoryIds.spirit, reminderAt: const TimeOfDay(hour: 7, minute: 0),
        twoMinute: const TwoMinuteVersion(description: 'Take three slow breaths')),
    gym: _habit(gym, target: 1, units: 'session', color: HabitColor.red, categoryId: BuiltInCategoryIds.body,
        weekdays: gymDays, reminderAt: const TimeOfDay(hour: 6, minute: 30)),
    callMum: _habit(callMum, target: 1, units: 'call', color: HabitColor.pink, categoryId: BuiltInCategoryIds.social,
        frequency: ResetFrequency.weekly),
    budget: _habit(budget, target: 1, color: HabitColor.teal, categoryId: BuiltInCategoryIds.career,
        frequency: ResetFrequency.monthly, anchor: DateTime(start.year, start.month, 1)),
    social: _habit(social, target: 30, units: 'minutes', color: HabitColor.indigo, categoryId: BuiltInCategoryIds.mind,
        goal: HabitGoal.limit, reminder: ReminderSettings.disabled()),
    journal: _habit(journal, target: 1, units: 'entry', color: HabitColor.brown, categoryId: BuiltInCategoryIds.creative,
        reminderAt: const TimeOfDay(hour: 21, minute: 30)),
  };

  CreateHabitParams _habit(
    String name, {
    required int target,
    String units = '',
    required HabitColor color,
    required String categoryId,
    ResetFrequency frequency = ResetFrequency.daily,
    List<int>? weekdays,
    DateTime? anchor,
    HabitGoal goal = HabitGoal.build,
    TwoMinuteVersion? twoMinute,
    TimeOfDay reminderAt = const TimeOfDay(hour: 9, minute: 0),
    ReminderSettings? reminder,
  }) =>
      CreateHabitParams(
        name: name,
        target: target,
        units: units,
        color: color,
        categoryId: categoryId,
        resetFrequency: frequency,
        scheduledWeekdays: weekdays,
        resetAnchor: anchor ?? date(name == journal ? journalAdded : 0),
        goal: goal,
        twoMinute: twoMinute,
        reminder: reminder ?? ReminderSettings.smart(time: reminderAt),
      );

  @override
  late final List<PersonaDay> days = [for (var i = 0; i < length; i++) _plan(i)];

  Random _dice(String habit, int day) {
    var hash = 0x811c9dc5;
    for (final unit in 'demo/$habit/$day'.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return Random(hash);
  }

  bool _onVacation(int i) => i >= vacationFrom && i <= vacationTo;

  PersonaDay _plan(int i) {
    final day = date(i);
    if (i == length - 1) return _today(i, day);
    final morning = <PersonaAction>[];
    final evening = <PersonaAction>[];

    if (i == 0) {
      for (final name in names) {
        if (name != journal) morning.add(CreateHabit(habits[name]!));
      }
      morning.add(const KeepQuote(read, readQuote));
    }
    if (i == journalAdded) morning.add(CreateHabit(habits[journal]!));

    if (_onVacation(i)) {
      return PersonaDay(i, day, [
        if (i == vacationFrom) const PersonaVisit(7, 30, [VacationMode(true)]),
        if (i == vacationTo) const PersonaVisit(21, 0, [VacationMode(false)]),
      ]);
    }
    if (meditateFrozen.contains(i)) morning.add(FreezeDay(meditate, day));

    final scripted = i >= scriptedFrom;
    // Daily habits: mostly kept, sometimes small, now and then missed
    for (final (habit, keep) in [(water, 0.88), (read, 0.86), (meditate, 0.8), (journal, 0.78)]) {
      if (habit == journal && i < journalAdded) continue;
      if (habit == meditate && meditateFrozen.contains(i)) continue;
      final target = habits[habit]!.target;
      // Yesterday Meditate was missed: today it's "Don't miss twice"
      if (scripted) {
        if (!(habit == meditate && i == length - 2)) evening.add(SetTotal(habit, target));
        continue;
      }
      final roll = _dice(habit, i).nextDouble();
      if (roll < keep) {
        evening.add(SetTotal(habit, target));
      } else if (roll < keep + 0.06 && habits[habit]!.twoMinute != null) {
        evening.add(TwoMinuteTap(habit));
      } else if (roll < keep + 0.09 && target > 1) {
        evening.add(SetTotal(habit, target ~/ 2));
      }
    }
    if (i % 9 == 4) evening.add(DayNote(read, _notes[(i ~/ 9) % _notes.length]));

    // Gym on its days
    if (gymDays.contains(day.weekday) && (scripted || _dice(gym, i).nextDouble() < 0.85)) {
      morning.add(const SetTotal(gym, 1));
    }

    // A call some day each week (its weeks start on day 0's weekday):
    // always last week, not yet this week
    final week = i ~/ 7, weekDay = i % 7, thisWeek = (length - 1) ~/ 7;
    final callDice = _dice(callMum, week);
    final call = week == thisWeek - 1
        ? weekDay == 3
        : week < thisWeek && callDice.nextDouble() < 0.88 && weekDay == callDice.nextInt(7);
    if (call) evening.add(const SetTotal(callMum, 1));

    // The budget early each month
    if (day.day == 3 && _dice(budget, day.month).nextDouble() < 0.92) evening.add(const SetTotal(budget, 1));

    // Social media: under the limit most days, over it now and then
    final socialDice = _dice(social, i);
    final over = !scripted && socialDice.nextDouble() < 0.07;
    evening.add(SetTotal(social, over ? 40 + socialDice.nextInt(30) : 8 + socialDice.nextInt(20)));

    return PersonaDay(i, day, [
      if (morning.isNotEmpty) PersonaVisit(7, 30, morning),
      PersonaVisit(20, 30, evening),
    ]);
  }

  /// Today, as the tours expect it, logged just after midnight so it's in
  /// place whatever the time: water half done, Social media clean so far.
  PersonaDay _today(int i, DateTime day) => PersonaDay(i, day, const [
        PersonaVisit(0, 1, [SetTotal(water, waterToday), SetTotal(social, 12)]),
      ]);

  static const _notes = [
    'Good chapter.',
    'Read on the train.',
    'Tired but did it.',
    'Finished the book!',
    'Ten pages before bed.',
  ];
}
