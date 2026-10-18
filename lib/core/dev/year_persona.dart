import 'dart:math';
import 'package:flutter/material.dart' show TimeOfDay;
import '../../domain/entities/category.dart';
import '../../domain/entities/habit_color.dart';
import '../../domain/entities/habit_goal.dart';
import '../../domain/entities/quiet_hours.dart';
import '../../domain/entities/quote.dart';
import '../../domain/entities/reminder_settings.dart';
import '../../domain/entities/reset_frequency.dart';
import '../../domain/entities/two_minute_version.dart';
import '../../domain/usecases/create_habit_usecase.dart';
import '../../domain/usecases/update_habit_usecase.dart';

/// A year of someone using the app, scripted day by day: which habits they
/// add, when they open the app and what they do there. The same year drives
/// the year simulation (test/simulation/year/), the year on a device
/// (integration_test/) and Settings → Developer → "Load a year of use".
///
/// Pure and the same every time: decisions come from a seeded [Random] per
/// habit and day, never from the clock or the app's state. It says what the
/// person does, not what should come of it; working that out is the
/// simulation's job.
class YearPersona {
  /// Day 0 (date-only).
  final DateTime start;

  YearPersona(DateTime start) : start = DateTime(start.year, start.month, start.day);

  static const length = 365;

  /// The persona's habits, by name.
  static const water = 'Drink water';
  static const read = 'Read';
  static const gym = 'Gym';
  static const run = 'Run';
  static const callMum = 'Call Mum';
  static const budget = 'Budget review';
  static const books = 'Finish 12 books';
  static const smoking = 'Smoking';
  static const social = 'Social media';
  static const meditate = 'Meditate';
  static const journal = 'Journal';
  static const spanish = 'Spanish';

  /// Days (from [start]) when things happen.
  static const quietHoursOn = 14;
  static const dayStartsAt4 = 30;
  static const myQuoteAdded = 30;
  static const warnTwoHoursBefore = 75;
  static const meditateAdded = 75;
  static const meditateStartsEarlier = 78;
  static const meditateFrom = 61;
  static const readSlump = 100; // two misses in a row: the streak ends
  static const readReminderMoved = 120;
  static const journalAdded = 130;
  static const journalCountsFrom = 150;
  static const journalFrom = 145;
  static const smokingSlip = 140;
  static const sundayWeeks = 168;
  static const waterTargetUp = 170;
  static const runEveryTwoDays = 200;
  static const stoicOff = 200;
  static const stoicOn = 210;
  static const inspireHidden = 230;
  static const inspireShown = 260;
  static const spanishDeleted = 265;
  static const holidayFrom = 290;
  static const holidayTo = 303; // inclusive
  static const myQuoteDeleted = 330;

  /// The quote from the library kept with Read.
  static const readQuote = 'epictetus-make-it-a-habit';

  static const myQuoteText = 'Small steps, every day, add up to a different life.';
  static const myQuoteAuthor = 'Me';

  DateTime date(int day) => DateTime(start.year, start.month, start.day + day);

  bool isHoliday(int day) => day >= holidayFrom && day <= holidayTo;

  /// The whole year, day 0 first.
  late final List<PersonaDay> days = () {
    final year = <PersonaDay>[];
    for (var i = 0; i < length; i++) {
      year.add(_plan(i, year.isEmpty ? null : year.last));
    }
    return year;
  }();

  /// What every habit is when it's added (later edits are actions).
  late final Map<String, CreateHabitParams> habits = {
    water: _habit(water, target: 8, units: 'glasses', color: HabitColor.blue, categoryId: BuiltInCategoryIds.body,
        twoMinute: const TwoMinuteVersion(description: 'Drink one glass', minimum: 1)),
    read: _habit(read, target: 20, units: 'pages', color: HabitColor.orange, categoryId: BuiltInCategoryIds.mind,
        reminderAt: const TimeOfDay(hour: 20, minute: 0),
        twoMinute: const TwoMinuteVersion(description: 'Read one page')),
    gym: _habit(gym, target: 1, units: 'session', color: HabitColor.red, categoryId: BuiltInCategoryIds.body,
        weekdays: const [DateTime.monday, DateTime.wednesday, DateTime.friday],
        reminder: const ReminderSettings(
          time: TimeOfDay(hour: 6, minute: 30),
          enabled: true,
          daysOfWeek: [DateTime.monday, DateTime.wednesday, DateTime.friday],
        )),
    run: _habit(run, target: 5, units: 'km', color: HabitColor.green, categoryId: BuiltInCategoryIds.body, interval: 3),
    callMum: _habit(callMum, target: 1, units: 'call', color: HabitColor.pink, categoryId: BuiltInCategoryIds.social,
        frequency: ResetFrequency.weekly, anchor: _onOrBefore(DateTime.sunday)),
    budget: _habit(budget, target: 1, color: HabitColor.teal, categoryId: BuiltInCategoryIds.career,
        frequency: ResetFrequency.monthly, anchor: _last31st()),
    books: _habit(books, target: 12, units: 'books', color: HabitColor.purple, categoryId: BuiltInCategoryIds.mind,
        frequency: ResetFrequency.never, reminder: ReminderSettings.disabled()),
    smoking: _habit(smoking, target: 0, color: HabitColor.blueGrey, categoryId: BuiltInCategoryIds.body,
        goal: HabitGoal.quit, reminderAt: const TimeOfDay(hour: 21, minute: 0)),
    social: _habit(social, target: 30, units: 'minutes', color: HabitColor.indigo, categoryId: BuiltInCategoryIds.mind,
        goal: HabitGoal.limit, reminder: ReminderSettings.disabled()),
    meditate: _habit(meditate, target: 10, units: 'minutes', color: HabitColor.deepPurple,
        categoryId: BuiltInCategoryIds.spirit, reminderAt: const TimeOfDay(hour: 7, minute: 0),
        twoMinute: const TwoMinuteVersion(description: 'Take three slow breaths')),
    // 22:30 is in quiet hours: it comes at 21:45 instead
    journal: _habit(journal, target: 1, units: 'entry', color: HabitColor.brown, categoryId: BuiltInCategoryIds.creative,
        reminderAt: const TimeOfDay(hour: 22, minute: 30)),
    spanish: _habit(spanish, target: 15, units: 'minutes', color: HabitColor.amber, categoryId: BuiltInCategoryIds.career,
        reminderAt: const TimeOfDay(hour: 19, minute: 0)),
  };

  /// The day each habit is added.
  static const addedOn = {meditate: meditateAdded, journal: journalAdded};

  CreateHabitParams _habit(
    String name, {
    required int target,
    String units = '',
    required HabitColor color,
    required String categoryId,
    ResetFrequency frequency = ResetFrequency.daily,
    int interval = 1,
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
        resetInterval: interval,
        scheduledWeekdays: weekdays,
        resetAnchor: anchor ?? date(addedOn[name] ?? 0),
        goal: goal,
        twoMinute: twoMinute,
        reminder: reminder ?? ReminderSettings.smart(time: reminderAt),
      );

  DateTime _onOrBefore(int weekday) {
    var d = start;
    while (d.weekday != weekday) {
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return d;
  }

  /// The latest 31st before [start], so the budget's month ends with the
  /// calendar month and short months clamp it.
  DateTime _last31st() {
    for (var back = 1;; back++) {
      final month = DateTime(start.year, start.month - back);
      if (DateTime(month.year, month.month + 1, 0).day == 31) return DateTime(month.year, month.month, 31);
    }
  }

  // ------------------------------------------------------------- planning

  Random _dice(String habit, int day) {
    var hash = 0x811c9dc5;
    for (final unit in '$habit/$day'.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return Random(hash);
  }

  bool _added(String habit, int day) =>
      day >= (addedOn[habit] ?? 0) && !(habit == spanish && day >= spanishDeleted);

  PersonaDay _plan(int i, PersonaDay? yesterday) {
    final day = date(i);
    if (isHoliday(i)) return PersonaDay(i, day, const []);
    final dice = _dice('day', i);
    final morningVisit = i == 0 || dice.nextDouble() > 0.15;
    final eveningVisit = i == 0 || dice.nextDouble() > 0.05;
    final forgotYesterday = yesterday != null && !isHoliday(i - 1) && !yesterday.visits.any((v) => v.hour >= 20);

    final morning = <PersonaAction>[];
    final midday = <PersonaAction>[];
    final evening = <PersonaAction>[];

    // Setting things up, and the year's changes
    if (i == 0) {
      for (final entry in habits.entries) {
        if (!addedOn.containsKey(entry.key)) morning.add(CreateHabit(entry.value));
      }
      morning.add(const KeepQuote(read, readQuote));
    }
    for (final entry in addedOn.entries) {
      if (entry.value == i) morning.add(CreateHabit(habits[entry.key]!));
    }
    morning.addAll(switch (i) {
      quietHoursOn => [const ChangeSetting(QuietHoursSetting(QuietHours(enabled: true)))],
      dayStartsAt4 => [
          const ChangeSetting(DayStartSetting(TimeOfDay(hour: 4, minute: 0))),
          const AddMyQuote(myQuoteText, myQuoteAuthor),
          const KeepMyQuote(read),
        ],
      warnTwoHoursBefore => [const ChangeSetting(WarningLeadSetting(Duration(hours: 2)))],
      meditateStartsEarlier => [
          StartFrom(meditate, date(meditateFrom)),
          // Then fills in the days since, most of them
          for (var d = meditateFrom; d < meditateStartsEarlier; d++)
            if (_dice(meditate, d).nextDouble() < 0.7) LogOn(meditate, date(d), 10),
        ],
      readReminderMoved => [
          EditHabit(read, UpdateHabitParams(reminder: ReminderSettings.smart(time: const TimeOfDay(hour: 21, minute: 0))),
              'reminder at 21:00'),
        ],
      journalCountsFrom => [CountFrom(journal, date(journalFrom), clearEarlier: true)],
      sundayWeeks => [const ChangeSetting(WeekStartSetting(DateTime.sunday))],
      waterTargetUp => [const EditHabit(water, UpdateHabitParams(target: 10), 'target 8 → 10 glasses')],
      runEveryTwoDays => [
          const EditHabit(run, UpdateHabitParams(resetInterval: 2), 'every 3 days → every 2 days'),
          const ChangeSetting(QuoteSourceSetting(QuoteFamily.stoic, false)),
        ],
      stoicOn => [const ChangeSetting(QuoteSourceSetting(QuoteFamily.stoic, true))],
      inspireHidden => [const ChangeSetting(InspireTabSetting(false))],
      inspireShown => [const ChangeSetting(InspireTabSetting(true))],
      spanishDeleted => [const DeleteHabit(spanish)],
      myQuoteDeleted => [const DeleteMyQuote()],
      _ => const <PersonaAction>[],
    });
    if (i > 0 && dice.nextDouble() < 0.12) morning.add(const AnotherQuote());

    // Forgot to log last night: fills in yesterday from Calendar
    if (forgotYesterday && eveningVisit) {
      for (final habit in [water, read, spanish, meditate, journal]) {
        if (!_added(habit, i - 1) || !_added(habit, i)) continue;
        final target = _target(habit, i - 1);
        if (_dailyOutcome(habit, i - 1) == _Outcome.full) morning.add(LogOn(habit, date(i - 1), target));
      }
    }

    // Gym, first thing on its days
    if (const [DateTime.monday, DateTime.wednesday, DateTime.friday].contains(day.weekday)) {
      final roll = _dice(gym, i).nextDouble();
      if (roll < 0.7) {
        morning.add(const SetTotal(gym, 1));
      } else if (roll < 0.8) {
        // Holds the ring to finish, then thinks better of it and does it later
        morning.add(const HoldToFinish(gym, undo: true));
        evening.add(const HoldToFinish(gym));
      }
    } else if (day.weekday == DateTime.tuesday && _dice(gym, i).nextDouble() < 0.1) {
      // An extra session on a rest day
      morning.add(const SetTotal(gym, 1));
    }

    // Habits done day by day
    for (final habit in [water, read, meditate, journal, spanish]) {
      if (!_added(habit, i)) continue;
      if (habit == journal && i < journalCountsFrom && i % 3 != 0) continue;
      final target = _target(habit, i);
      switch (_dailyOutcome(habit, i)) {
        case _Outcome.full:
          if (habit == water) midday.add(const SetTotal(water, 3));
          evening.add(SetTotal(habit, target));
        case _Outcome.over:
          evening.add(SetTotal(habit, target + 2));
        case _Outcome.partial:
          if (target > 1) evening.add(SetTotal(habit, target ~/ 2));
        case _Outcome.twoMinute:
          evening.add(TwoMinuteTap(habit));
        case _Outcome.miss:
          break;
      }
    }
    if (i % 7 == 6 && _added(read, i)) evening.add(DayNote(read, 'Week ${i ~/ 7 + 1}: ${_notes[i % _notes.length]}'));

    // Every few days: a run some day in each period
    final runLength = i < runEveryTwoDays ? 3 : 2;
    final runFrom = i < runEveryTwoDays ? 0 : runEveryTwoDays;
    final runPeriod = (i - runFrom) ~/ runLength;
    final runDice = _dice(run, runFrom * 1000 + runPeriod);
    if (runDice.nextDouble() < 0.85 && (i - runFrom) % runLength == runDice.nextInt(runLength)) {
      evening.add(const SetTotal(run, 5));
    }

    // Weekly: a call some day in each week (sometimes the last)
    final week = _daysBetween(habits[callMum]!.resetAnchor!, day) ~/ 7;
    final callDice = _dice(callMum, week);
    if (callDice.nextDouble() < 0.85 && _daysBetween(habits[callMum]!.resetAnchor!, day) % 7 == callDice.nextInt(7)) {
      evening.add(const SetTotal(callMum, 1));
    }

    // Monthly: the budget early in the month, or on its last day
    final budgetDice = _dice(budget, day.year * 12 + day.month);
    final budgetDay = budgetDice.nextDouble() < 0.2 ? DateTime(day.year, day.month + 1, 0).day : 3;
    if (budgetDice.nextDouble() < 0.9 && day.day == budgetDay) evening.add(const SetTotal(budget, 1));

    // A book now and then (a habit that never resets: the total so far)
    final booksDone = _booksBy(i);
    if (booksDone > _booksBy(i - 1)) evening.add(SetTotal(books, booksDone));

    // Habits being broken
    if (i == smokingSlip || i == 20) morning.add(const SetTotal(smoking, 1));
    if (i == smokingSlip + 40) morning.add(LogOn(smoking, date(i - 1), 1)); // a slip owned up to the next day
    final socialDice = _dice(social, i);
    evening.add(SetTotal(social, socialDice.nextDouble() < 0.12 ? 40 + socialDice.nextInt(30) : 10 + socialDice.nextInt(19)));

    // Midday's log waits for the evening when there's no look at lunch
    final middayVisit = midday.isNotEmpty && dice.nextDouble() < 0.6;
    final visits = <PersonaVisit>[
      if (morningVisit || morning.isNotEmpty) PersonaVisit(7, 30, morning),
      if (middayVisit) PersonaVisit(12, 30, midday),
      if (eveningVisit) PersonaVisit(21, 0, [if (!middayVisit) ...midday, ...evening]),
    ];
    return PersonaDay(i, day, visits);
  }

  static const _notes = ['Good chapter.', 'Slow week.', 'Finished a book!', 'Read on the train.', 'Tired but did it.'];

  int _target(String habit, int day) => habit == water && day >= waterTargetUp ? 10 : habits[habit]!.target;

  int _booksBy(int day) => day < 0 ? 0 : (day + 10) ~/ 31;

  _Outcome _dailyOutcome(String habit, int day) {
    if (habit == read && (day == readSlump || day == readSlump + 1)) return _Outcome.miss;
    final roll = _dice(habit, day).nextDouble();
    final keep = switch (habit) {
      water => 0.82,
      read => 0.8,
      meditate => 0.72,
      journal => 0.7,
      _ => 0.75,
    };
    if (roll < keep) return _Outcome.full;
    if (roll < keep + 0.03) return _Outcome.over;
    if (roll < keep + 0.08 && habit != meditate) return _Outcome.partial;
    if (roll < keep + 0.16 && habits[habit]!.twoMinute != null) return _Outcome.twoMinute;
    return _Outcome.miss;
  }

  static int _daysBetween(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}

enum _Outcome { full, over, partial, twoMinute, miss }

/// One day of the year: when the app is opened and what's done each time.
/// A day with no visits is a day the app isn't opened at all.
class PersonaDay {
  final int index;
  final DateTime date;
  final List<PersonaVisit> visits;

  const PersonaDay(this.index, this.date, this.visits);
}

class PersonaVisit {
  final int hour;
  final int minute;

  /// Done in order; empty for a quick look.
  final List<PersonaAction> actions;

  const PersonaVisit(this.hour, this.minute, this.actions);

  DateTime on(DateTime day) => DateTime(day.year, day.month, day.day, hour, minute);
}

/// Something the person does in the app.
sealed class PersonaAction {
  const PersonaAction();

  /// The habit it's about, if any.
  String? get habit => null;
}

final class CreateHabit extends PersonaAction {
  final CreateHabitParams params;
  const CreateHabit(this.params);
  @override
  String get habit => params.name;
  @override
  String toString() => 'add $habit';
}

/// Sets the period's total so far, as the card's − / + or typing on the
/// habit page does (it may go past the target).
final class SetTotal extends PersonaAction {
  @override
  final String habit;
  final int total;
  const SetTotal(this.habit, this.total);
  @override
  String toString() => '$habit $total';
}

/// Sets what was logged on a past day, from Calendar.
final class LogOn extends PersonaAction {
  @override
  final String habit;
  final DateTime day;
  final int amount;
  const LogOn(this.habit, this.day, this.amount);
  @override
  String toString() => '$habit ${day.month}/${day.day} = $amount (Calendar)';
}

/// The card's "2 min" button, today.
final class TwoMinuteTap extends PersonaAction {
  @override
  final String habit;
  const TwoMinuteTap(this.habit);
  @override
  String toString() => '$habit 2 min';
}

/// Holds the ring to finish the period, then (with [undo]) taps Undo.
final class HoldToFinish extends PersonaAction {
  @override
  final String habit;
  final bool undo;
  const HoldToFinish(this.habit, {this.undo = false});
  @override
  String toString() => '$habit hold${undo ? ' + undo' : ''}';
}

final class DayNote extends PersonaAction {
  @override
  final String habit;
  final String text;
  const DayNote(this.habit, this.text);
  @override
  String toString() => '$habit note';
}

/// Calendar's "Start from this day".
final class StartFrom extends PersonaAction {
  @override
  final String habit;
  final DateTime day;
  const StartFrom(this.habit, this.day);
  @override
  String toString() => '$habit starts ${day.month}/${day.day}';
}

/// The editor's "Counts from".
final class CountFrom extends PersonaAction {
  @override
  final String habit;
  final DateTime day;
  final bool clearEarlier;
  const CountFrom(this.habit, this.day, {this.clearEarlier = false});
  @override
  String toString() => '$habit counts from ${day.month}/${day.day}${clearEarlier ? ', earlier days cleared' : ''}';
}

final class EditHabit extends PersonaAction {
  @override
  final String habit;
  final UpdateHabitParams params;

  /// What changed, in words.
  final String what;
  const EditHabit(this.habit, this.params, this.what);
  @override
  String toString() => '$habit edited: $what';
}

final class DeleteHabit extends PersonaAction {
  @override
  final String habit;
  const DeleteHabit(this.habit);
  @override
  String toString() => '$habit deleted';
}

/// Keeps a library quote with a habit.
final class KeepQuote extends PersonaAction {
  @override
  final String habit;
  final String quoteId;
  const KeepQuote(this.habit, this.quoteId);
  @override
  String toString() => '$habit keeps $quoteId';
}

/// Files a quote of their own.
final class AddMyQuote extends PersonaAction {
  final String text;
  final String author;
  const AddMyQuote(this.text, this.author);
  @override
  String toString() => 'own quote added';
}

/// Keeps their own quote (the last added) with a habit.
final class KeepMyQuote extends PersonaAction {
  @override
  final String habit;
  const KeepMyQuote(this.habit);
  @override
  String toString() => '$habit keeps own quote';
}

/// Deletes their own quote (the last added).
final class DeleteMyQuote extends PersonaAction {
  const DeleteMyQuote();
  @override
  String toString() => 'own quote deleted';
}

/// Inspire's "Another quote".
final class AnotherQuote extends PersonaAction {
  const AnotherQuote();
  @override
  String toString() => 'another quote';
}

final class ChangeSetting extends PersonaAction {
  final PersonaSetting setting;
  const ChangeSetting(this.setting);
  @override
  String toString() => 'settings: $setting';
}

sealed class PersonaSetting {
  const PersonaSetting();
}

final class QuietHoursSetting extends PersonaSetting {
  final QuietHours quiet;
  const QuietHoursSetting(this.quiet);
  @override
  String toString() => 'quiet hours ${quiet.enabled ? 'on' : 'off'}';
}

final class WarningLeadSetting extends PersonaSetting {
  final Duration lead;
  const WarningLeadSetting(this.lead);
  @override
  String toString() => 'warn ${lead.inHours} hours before';
}

final class WeekStartSetting extends PersonaSetting {
  final int weekday;
  const WeekStartSetting(this.weekday);
  @override
  String toString() => 'week starts ${weekday == DateTime.sunday ? 'Sunday' : 'Monday'}';
}

final class DayStartSetting extends PersonaSetting {
  final TimeOfDay time;
  const DayStartSetting(this.time);
  @override
  String toString() => 'day starts at ${time.hour}:00';
}

final class InspireTabSetting extends PersonaSetting {
  final bool show;
  const InspireTabSetting(this.show);
  @override
  String toString() => 'Inspire tab ${show ? 'shown' : 'hidden'}';
}

final class QuoteSourceSetting extends PersonaSetting {
  final QuoteFamily family;
  final bool on;
  const QuoteSourceSetting(this.family, this.on);
  @override
  String toString() => '${family.name} quotes ${on ? 'on' : 'off'}';
}
