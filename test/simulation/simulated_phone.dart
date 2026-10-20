import 'package:clock/clock.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/notification_service.dart';
import 'package:atomic_momentum/core/services/reminder_service.dart';
import 'package:atomic_momentum/data/datasources/shared_preferences_datasource.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/quiet_hours.dart';
import 'package:atomic_momentum/domain/services/reminder_planner.dart';
import 'package:atomic_momentum/domain/services/streak_warning_planner.dart';
import 'package:atomic_momentum/domain/services/vacation_notice_planner.dart';
import 'package:atomic_momentum/domain/services/weekly_review_planner.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/domain/usecases/update_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';

import 'simulated_notification_center.dart';

/// A notification the app means to show: what it planned the last time
/// something changed. Delivered notifications must match these exactly.
class _Expected {
  final String habitId;
  final String kind;
  final DateTime at;
  final String title;
  final String body;

  _Expected(this.habitId, this.kind, this.at, this.title, this.body);

  String get key => '$habitId|$kind|${at.toIso8601String()}|$title|$body';
}

/// The real app (providers, use cases, storage, NotificationService) on a
/// phone whose clock the test moves forward. Notifications go to a
/// [SimulatedNotificationCenter], which delivers them as time passes.
///
/// Every delivery is checked as it happens:
/// - against what the app planned after the last change: nothing missing,
///   nothing extra (this catches dropped, stale and duplicate scheduling);
/// - against the habit as it is at that moment: a reminder never comes for a
///   period already done, at the wrong time or on a day its mode excludes; a
///   streak warning only when a streak is at stake, at the lead time before
///   midnight on the clock;
/// - iOS's limit: never more than 64 pending.
///
/// Everything (actions and notifications) goes into a readable [timeline].
class SimulatedPhone {
  SimulatedPhone._(this.now);

  /// The phone's clock: all app code reads it through package:clock.
  DateTime now;

  final center = SimulatedNotificationCenter();
  late HabitProvider habits;
  late SettingsProvider settings;

  final List<String> timeline = [];
  final List<String> failures = [];
  final List<SimRequest> delivered = [];
  final Map<String, String> _ids = {};

  bool _open = false;
  bool _launched = false;
  List<_Expected> _expected = [];
  final Set<String> _deliveredKeys = {};

  /// Runs [script] on a fresh phone starting at [start]. Failures are
  /// collected, not thrown, so a scenario reports all of them at once.
  static Future<SimulatedPhone> run(DateTime start, Future<void> Function(SimulatedPhone phone) script) async {
    final phone = SimulatedPhone._(start);
    await withClock(Clock(() => phone.now), () async {
      await phone._setUp();
      await script(phone);
      phone._finish();
    });
    return phone;
  }

  Future<void> _setUp() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    center.now = () => now;
    NotificationService.debugOverride(plugin: center);
    await initializeDependencies(seedDefaultHabit: false);
    habits = get<HabitProvider>();
    settings = get<SettingsProvider>();
  }

  void _finish() {
    for (final d in center.dropped) {
      _fail(d.when, 'iOS discarded "${d.request.title}" due ${_stamp(d.request.at)} '
          '(over ${SimulatedNotificationCenter.iosPendingLimit} pending)');
    }
    for (final r in center.scheduledInPast) {
      _fail(r.at, '"${r.title}" was scheduled for a time already past');
    }
  }

  String id(String name) => _ids[name] ?? (throw ArgumentError('No habit named $name'));

  Habit habit(String name) => habits.getHabitById(id(name))!;

  // ---------------------------------------------------------------- time

  /// Moves the clock to [time]. Notifications due on the way are delivered
  /// and checked. While the app is open, crossing midnight runs what the
  /// Habits screen's midnight timer runs.
  Future<void> advanceTo(DateTime time) async {
    while (now.isBefore(time)) {
      var next = time;
      DateTime? midnight;
      if (_open) {
        midnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 1);
        if (midnight.isBefore(next)) next = midnight;
      }
      _deliverUntil(next);
      now = next;
      if (midnight != null && next == midnight) {
        await habits.resetHabitsIfNeeded();
        await _changed();
      }
    }
  }

  /// Opens the app at [time] (a resume; the first time, a launch) and
  /// closes it again: what a quick look does.
  Future<void> checkIn(DateTime time) async {
    await advanceTo(time);
    final wasOpen = _open;
    await open();
    if (!wasOpen) close();
  }

  /// At [time], opens the app if needed, does [action] and closes it again,
  /// noting [label] in the timeline.
  Future<void> at(DateTime time, String label, Future<void> Function() action) async {
    await advanceTo(time);
    final wasOpen = _open;
    if (!wasOpen) await open();
    await action();
    await _changed();
    _line(now, label);
    if (!wasOpen) close();
  }

  /// Launch (first time, or [cold] after the app was killed: a new provider
  /// that loads from storage) or resume, as the Habits screen does.
  Future<void> open({bool cold = false}) async {
    if (!_launched || cold) {
      habits = get<HabitProvider>();
      await habits.loadHabits();
      _launched = true;
    } else {
      await habits.resetHabitsIfNeeded();
    }
    _open = true;
    await _changed();
  }

  void close() => _open = false;

  /// Leaves the app open (it then crosses midnight with its timer).
  Future<void> keepOpen(DateTime from) async {
    await advanceTo(from);
    await open();
  }

  // ------------------------------------------------------------- actions

  Future<void> create(CreateHabitParams params) async {
    await habits.createHabit(params);
    final created = habits.habits.firstWhere((h) => h.name == params.name);
    _ids[params.name] = created.id;
  }

  /// Sets today's total for the period, as the card's −/+ does.
  Future<void> log(String name, int total) => habits.updateHabitProgress(id(name), total);

  /// Sets what was logged on [date], as the Calendar does.
  Future<void> logOn(String name, DateTime date, int amount) => habits.updateProgressForDate(id(name), date, amount);

  Future<void> twoMinute(String name, bool done) => habits.setTwoMinute(id(name), done);

  Future<void> edit(String name, UpdateHabitParams params) => habits.updateHabitDetails(id(name), params);

  /// Spends a freeze on [name]'s period containing [day] (or takes it back).
  Future<void> freeze(String name, DateTime day, {bool on = true}) =>
      on ? habits.freeze(id(name), day) : habits.unfreeze(id(name), day);

  /// Turns vacation mode on (until the morning of [back], if given) or off.
  Future<void> vacation(bool on, {DateTime? back}) => on ? habits.startVacation(back: back) : habits.endVacation();

  /// Moves the return day while on vacation (null: none).
  Future<void> vacationReturn(DateTime? back) => habits.setVacationReturn(back);

  /// "I'm back" on a vacation check-in: the response arrives, and the app
  /// ends vacation mode as the main screen does.
  Future<void> imBack() async {
    NotificationService.handleResponse(NotificationService.vacationBackAction, NotificationService.vacationPayload);
    await habits.endVacation();
  }

  /// Turns vacation check-ins on or off, then resyncs as Settings does.
  Future<void> vacationNotices(bool on) async {
    await settings.setVacationNotices(on);
    await habits.resyncVacationNotices();
  }

  /// Turns the week in review on or off, or moves its time, then resyncs as
  /// Settings does.
  Future<void> weeklyReview({bool? on, TimeOfDay? time}) async {
    if (on != null) await settings.setWeeklyReview(on);
    if (time != null) await settings.setWeeklyReviewTime(time);
    await habits.resyncWeeklyReview();
  }

  /// Changes the first day of the week (null: the region's), then resyncs as
  /// Settings does.
  Future<void> weekStart(int? day) async {
    await settings.setWeekStart(day);
    await habits.resyncWeeklyReview();
  }

  Future<void> delete(String name) => habits.deleteHabit(id(name));

  /// The habits as stored, as Settings → Developer keeps them aside.
  String get storedHabits => get<SharedPreferences>().getString(SharedPreferencesDataSource.habitsKey) ?? '[]';

  /// Puts [stored] back in place of the habits and reloads, as "Load a year
  /// of use" and "Put my habits back" do: habits go without being deleted.
  Future<void> replaceStoredHabits(String stored) async {
    await get<SharedPreferences>().setString(SharedPreferencesDataSource.habitsKey, stored);
    await habits.loadHabits();
  }

  /// Sets quiet hours, then resyncs as the Settings screen does.
  Future<void> quietHours(QuietHours quiet) async {
    await settings.setQuietHours(quiet);
    await habits.resyncStreakWarnings();
  }

  /// Changes streak warning settings, then resyncs as the Settings screen does.
  Future<void> warnings({bool? enabled, Duration? lead, bool? firstMiss}) async {
    if (enabled != null) await settings.setStreakWarningsEnabled(enabled);
    if (lead != null) await settings.setStreakWarningLeadTime(lead);
    if (firstMiss != null) await settings.setRemindBeforeFirstMiss(firstMiss);
    await habits.resyncStreakWarnings();
  }

  // ------------------------------------------------------- the checking

  /// Lets un-awaited syncs finish, then records what the app now intends.
  Future<void> _changed() async {
    await pumpEventQueue(times: 50);
    _expected = _plan();
  }

  /// What the app should have pending right now, worked out from its state:
  /// the soonest reminders within the budget, every streak warning, and
  /// vacation mode's notices.
  List<_Expected> _plan() {
    final vacation = habits.vacationForNotices;
    final time = settings.defaultReminderTime;
    final notices = vacation == null || !settings.vacationNotices
        ? const <PlannedVacationNotice>[]
        : VacationNoticePlanner.plan(vacation,
            now: now, hour: time.hour, minute: time.minute, quiet: settings.quietHours);
    final reminders = [
      for (final h in habits.habits) ...ReminderPlanner.plan(h, now: now, quiet: settings.quietHours),
    ]..sort((a, b) => a.at.compareTo(b.at));
    final warningSettings = settings.streakWarnings;
    final reviewTime = settings.weeklyReviewTime;
    final reviews = !settings.weeklyReview
        ? const <PlannedWeeklyReview>[]
        : WeeklyReviewPlanner.plan(
            now: now,
            weekStart: settings.firstDayOfWeek,
            hour: reviewTime.hour,
            minute: reviewTime.minute,
            trackedSince: habits.weeklyReviewInput.trackedSince,
            vacation: habits.weeklyReviewInput.vacation,
            quiet: settings.quietHours,
          );
    return [
      for (final r in reminders.take(get<ReminderService>().roomFor(habits.habits)))
        _Expected(r.habitId, 'reminder', r.at, r.title, r.body),
      for (final h in habits.habits)
        for (final w in StreakWarningPlanner.plan(h.refresh(now), warningSettings, now, quiet: settings.quietHours))
          _Expected(h.id, w.kind.name, w.at, w.title, w.body),
      for (final n in notices) _Expected(NotificationService.vacationPayload, n.kind.name, n.at, n.title, n.body),
      for (final r in reviews)
        _Expected(NotificationService.weeklyReviewPayload, 'weeklyReview', r.at, WeeklyReviewPlanner.title,
            WeeklyReviewPlanner.body),
    ];
  }

  void _deliverUntil(DateTime time) {
    final due = center.deliverDue(time);
    final expectedNow = _expected.where((e) => !e.at.isAfter(time)).toList();
    _expected.removeWhere((e) => !e.at.isAfter(time));

    final unmatched = {for (final e in expectedNow) e.key: e};
    for (final r in due) {
      final kind = _kindOf(r);
      final key = '${r.habitId}|$kind|${r.at.toIso8601String()}|${r.title}|${r.body}';
      if (unmatched.remove(key) == null) _fail(r.at, 'UNEXPECTED "${r.title}: ${r.body}"');
      _check(r, kind);
      delivered.add(r);
      _line(r.at, '${_label(kind)}${r.title}: ${r.body}');
    }
    final missingSorted = unmatched.values.toList()..sort((a, b) => a.key.compareTo(b.key));
    for (final missing in missingSorted) {
      _fail(missing.at, 'MISSING "${missing.title}: ${missing.body}"');
      _line(missing.at, 'MISSING    ${missing.title}: ${missing.body}');
    }
  }

  static String _kindOf(SimRequest r) {
    if (r.isReminder) return 'reminder';
    if (r.payload == NotificationService.weeklyReviewPayload) return 'weeklyReview';
    if (r.payload == NotificationService.vacationPayload) {
      return r.title == VacationNoticePlanner.welcomeTitle ? VacationNoticeKind.welcomeBack.name : VacationNoticeKind.checkIn.name;
    }
    return (r.title ?? '').startsWith("Don't miss twice") ? 'secondMiss' : 'firstMiss';
  }

  static String _label(String kind) => switch (kind) {
        'reminder' => 'REMINDER   ',
        'secondMiss' => 'WARNING    ',
        'checkIn' => 'VACATION   ',
        'welcomeBack' => 'WELCOME    ',
        'weeklyReview' => 'WEEKLY     ',
        _ => 'NUDGE      ',
      };

  /// The rules a delivered notification must meet, judged by the habit as
  /// it is at that moment.
  void _check(SimRequest r, String kind) {
    final key = '${r.habitId}|$kind|${r.at.toIso8601String()}';
    if (!_deliveredKeys.add(key)) _fail(r.at, 'DUPLICATE "${r.title}"');
    if (r.payload == NotificationService.vacationPayload) {
      _checkVacationNotice(r, kind);
      return;
    }
    if (r.payload == NotificationService.weeklyReviewPayload) {
      _checkWeeklyReview(r);
      return;
    }

    final habit = habits.getHabitById(r.habitId ?? '');
    if (habit == null) {
      _fail(r.at, '"${r.title}" is for a habit that no longer exists (payload ${r.payload})');
      return;
    }
    final justBefore = r.at.subtract(const Duration(minutes: 1));
    final quiet = settings.quietHours;
    if (quiet.contains(r.at)) _fail(r.at, '"${r.title}" arrived during quiet hours');

    if (kind == 'reminder') {
      final reminder = habit.reminder;
      if (reminder == null || !reminder.enabled) {
        _fail(r.at, 'reminder for "${habit.name}", whose reminder is off');
        return;
      }
      final wanted = DateTime(r.at.year, r.at.month, r.at.day, reminder.time.hour, reminder.time.minute);
      final wallTimeExists = wanted.hour == reminder.time.hour && wanted.minute == reminder.time.minute;
      // Its time, or moved out of quiet hours on the same day
      final expected = quiet.shift(wanted);
      if (wallTimeExists && (r.at.hour != expected.hour || r.at.minute != expected.minute)) {
        _fail(r.at, 'reminder for "${habit.name}" at ${_hm(r.at)}, not its time ${_hm(expected)}');
      }
      if (!reminder.isSmart && !reminder.daysOfWeek.contains(r.at.weekday)) {
        _fail(r.at, 'reminder for "${habit.name}" on a day its custom days exclude');
      }
      // A habit being broken checks in every day: there's nothing to finish
      if (!habit.isBreak && habit.wasKeptOnDate(r.at)) {
        _fail(r.at, 'reminder for "${habit.name}", already done for this period');
      }
      if (habit.isOnVacation) _fail(r.at, 'reminder for "${habit.name}" while on vacation');
      if (habit.isFrozenOn(r.at)) _fail(r.at, 'reminder for "${habit.name}" on a frozen day');
      if (habit.isBreak && r.body != ReminderPlanner.checkInBody && r.body != reminder.customMessage?.trim()) {
        _fail(r.at, 'check-in for "${habit.name}" with the wrong message "${r.body}"');
      }
      final fresh = ReminderPlanner.plan(habit, now: justBefore, horizon: 2, quiet: quiet);
      if (!fresh.any((p) => p.at == r.at && p.title == r.title && p.body == r.body)) {
        _fail(r.at, 'stale reminder for "${habit.name}": the app would no longer send "${r.body}"');
      }
      return;
    }

    final warningSettings = settings.streakWarnings;
    if (!warningSettings.enabled) _fail(r.at, 'streak warning for "${habit.name}" with warnings turned off');
    if (habit.isBreak) _fail(r.at, 'streak warning for "${habit.name}", a habit being broken');
    if (!habit.notify.streakWarnings) _fail(r.at, 'streak warning for "${habit.name}" with its warnings turned off');
    if (kind == 'firstMiss' && !warningSettings.remindBeforeFirstMiss) {
      _fail(r.at, 'first-miss nudge for "${habit.name}" with that setting off');
    }
    final current = habit.refresh(justBefore);
    if (current.streak.current == 0) _fail(r.at, 'streak warning for "${habit.name}" with no streak at stake');
    if (habit.wasKeptOnDate(r.at)) _fail(r.at, 'streak warning for "${habit.name}", already done for this period');
    if (habit.isOnVacation) _fail(r.at, 'streak warning for "${habit.name}" while on vacation');

    // The lead time is measured on the clock: "4 hours before midnight" is
    // 20:00 even on the day the clocks change
    final deadline = kind == 'secondMiss' ? current.streakDeadline(justBefore) : current.nextMissAt(justBefore);
    if (deadline != null) {
      final lead = warningSettings.leadTime;
      final onTheClock = quiet.shift(DateTime(deadline.year, deadline.month, deadline.day,
          deadline.hour - lead.inHours, deadline.minute - lead.inMinutes.remainder(60)));
      if (r.at != onTheClock) {
        _fail(r.at, 'streak warning for "${habit.name}" at ${_stamp(r.at)}; '
            '${lead.inHours}h before the deadline on the clock is ${_stamp(onTheClock)}');
      }
    }
    final fresh = StreakWarningPlanner.plan(current, warningSettings, justBefore, quiet: quiet);
    if (!fresh.any((w) => w.at == r.at && w.title == r.title && w.body == r.body)) {
      _fail(r.at, 'stale streak warning for "${habit.name}": the app would no longer send "${r.body}"');
    }
  }

  /// A vacation notice: a check-in only while vacation mode is on with no
  /// return date, a welcome back only on the return day, once it has ended
  /// by itself; at the default reminder time (out of quiet hours), and only
  /// with the switch on.
  void _checkVacationNotice(SimRequest r, String kind) {
    if (settings.quietHours.contains(r.at)) _fail(r.at, '"${r.title}" arrived during quiet hours');
    if (!settings.vacationNotices) _fail(r.at, '"${r.title}" with vacation check-ins turned off');
    final time = settings.defaultReminderTime;
    final expected = settings.quietHours.shift(DateTime(r.at.year, r.at.month, r.at.day, time.hour, time.minute));
    if (r.at.hour != expected.hour || r.at.minute != expected.minute) {
      _fail(r.at, '"${r.title}" at ${_hm(r.at)}, not the default reminder time ${_hm(expected)}');
    }
    final today = DateTime(r.at.year, r.at.month, r.at.day);
    if (kind == VacationNoticeKind.checkIn.name) {
      final vacation = habits.vacation;
      if (vacation == null) _fail(r.at, 'vacation check-in "${r.title}" with vacation mode off');
      if (vacation?.back != null) _fail(r.at, 'vacation check-in with a return date set');
      return;
    }
    if (habits.onVacation) _fail(r.at, 'welcome back while still on vacation');
    final returning = habits.habits.any((h) => h.pauses.isNotEmpty && h.pauses.last.back == today);
    if (!returning) _fail(r.at, 'welcome back on a day that isn\'t a return day');
  }

  /// The week in review: on the last day of the person's week, at the
  /// review time (out of quiet hours), with the switch on, a week with
  /// something tracked to look back on, and not on vacation.
  void _checkWeeklyReview(SimRequest r) {
    if (settings.quietHours.contains(r.at)) _fail(r.at, 'the week in review arrived during quiet hours');
    if (!settings.weeklyReview) _fail(r.at, 'the week in review with it turned off');
    final day = DateTime(r.at.year, r.at.month, r.at.day);
    final lastDay = (settings.firstDayOfWeek + 5) % 7 + 1;
    if (day.weekday != lastDay) _fail(r.at, 'the week in review on a ${_weekday(day)}, not the week\'s last day');
    final time = settings.weeklyReviewTime;
    final expected = settings.quietHours.shift(DateTime(day.year, day.month, day.day, time.hour, time.minute));
    if (r.at.hour != expected.hour || r.at.minute != expected.minute) {
      _fail(r.at, 'the week in review at ${_hm(r.at)}, not the review time ${_hm(expected)}');
    }
    if (habits.onVacation) _fail(r.at, 'the week in review while on vacation');
    final since = habits.weeklyReviewInput.trackedSince;
    if (since == null || since.isAfter(DateTime(day.year, day.month, day.day - 2))) {
      _fail(r.at, 'the week in review with too little of the week tracked');
    }
  }

  static String _weekday(DateTime d) => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];

  // ------------------------------------------------------------ output

  void _fail(DateTime at, String message) => failures.add('${_stamp(at)}  $message');

  void _line(DateTime at, String text) => timeline.add('${_stamp(at)}  $text');

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _hm(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';
  static String _stamp(DateTime t) => '${_days[t.weekday - 1]} ${_months[t.month - 1]} ${_two(t.day)} ${_hm(t)}';
}
