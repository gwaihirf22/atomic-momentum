import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';
import '../entities/habit.dart';
import '../entities/habit_notify.dart';
import '../entities/habit_schedule.dart';
import '../entities/quiet_hours.dart';
import '../entities/reset_frequency.dart';
import 'package:clock/clock.dart';

/// One reminder notification to deliver.
class PlannedReminder extends Equatable {
  final String habitId;
  final DateTime at;
  final String title;
  final String body;

  /// How it arrives: the habit's sound and time sensitivity.
  final HabitNotify notify;

  const PlannedReminder({
    required this.habitId,
    required this.at,
    required this.title,
    required this.body,
    this.notify = HabitNotify.standard,
  });

  @override
  List<Object?> get props => [habitId, at, title, body, notify];

  @override
  String toString() => 'PlannedReminder($habitId at $at: $body)';
}

/// Works out when to remind about a habit over the next couple of weeks.
///
/// Smart reminders follow the schedule. A habit due every day (or on chosen
/// weekdays) is reminded on each due day. Longer periods count down to the
/// day they're due (the period's last day), with more nudges the longer the
/// period: 1 day before for every 2-6 days, 3 and 1 day before for weekly up
/// to every 3 weeks, and 7, 3 and 1 day before for monthly. Custom reminders
/// fire on the chosen weekdays.
///
/// Either way, a reminder is dropped once the habit is done (or kept with
/// the two-minute version) for the period it falls in, so planning again
/// after each change keeps them current.
///
/// A habit being broken gets a check-in instead ("Still on track? Log any
/// slips."): every day, smart or on the chosen days, never dropped, since
/// there's nothing to finish.
class ReminderPlanner {
  const ReminderPlanner._();

  /// How far ahead reminders are scheduled; planning again (on app open, at
  /// midnight, after changes) keeps the window rolling.
  static const horizonDays = 14;

  /// Days before the due day to remind, for a period of [periodDays] days.
  static List<int> countdownOffsets(int periodDays) {
    if (periodDays <= 1) return const [0];
    if (periodDays < 7) return const [1];
    if (periodDays < 28) return const [3, 1];
    return const [7, 3, 1];
  }

  /// [quiet]: reminders falling in quiet hours move out of them, staying on
  /// the same day (see [QuietHours.shift]).
  static List<PlannedReminder> plan(
    Habit habit, {
    required DateTime now,
    int horizon = horizonDays,
    QuietHours quiet = QuietHours.off,
  }) {
    final reminder = habit.reminder;
    // Vacation mode: nothing is due until it's turned off. With a return
    // date, the days away are paused and reminders pick up that day
    if (reminder == null || !reminder.enabled || habit.isOnOpenVacation) return const [];

    final today = _dateOnly(now);
    final days = reminder.isSmart
        ? (habit.isBreak
            ? [for (var i = 0; i < horizon; i++) _addDays(today, i)]
            : _smartDays(habit.schedule, today, horizon))
        : [
            for (var i = 0; i < horizon; i++)
              if (reminder.daysOfWeek.contains(_addDays(today, i).weekday)) _addDays(today, i),
          ];

    DateTime at(DateTime day) => quiet.shift(_at(day, reminder.time.hour, reminder.time.minute));
    return [
      for (final day in days)
        // Not for a period already kept, frozen or on vacation (habits being
        // broken check in every other day)
        if (at(day).isAfter(now) && !habit.isPausedOn(day) && (habit.isBreak || !habit.wasKeptOnDate(day)))
          PlannedReminder(
            habitId: habit.id,
            at: at(day),
            notify: habit.notify,
            title: habit.name,
            body:
                reminder.customMessage?.trim().isNotEmpty == true ? reminder.customMessage!.trim() : _body(habit, day),
          ),
    ];
  }

  /// What smart reminders do for [schedule], for the form, e.g. "3 days and
  /// 1 day before it's due (Thu and Sat)".
  static String describeSmart(HabitSchedule schedule, {DateTime? now}) {
    if (!schedule.isPeriodic) return "Every day until it's done";
    if (_isDayByDay(schedule)) {
      return schedule.hasRestDays ? 'On each due day (${schedule.shortLabel})' : 'Every day';
    }

    final start = schedule.periodStart(now ?? clock.now());
    final next = schedule.nextPeriodStart(start);
    final offsets = countdownOffsets(_daysBetween(start, next));
    final when = switch (offsets.length) {
      1 => "1 day before it's due",
      2 => "${offsets[0]} days and 1 day before it's due",
      _ => "${offsets.take(offsets.length - 1).join(', ')} and 1 day before it's due",
    };
    if (schedule.frequency != ResetFrequency.weekly || schedule.interval != 1) return when;

    // A weekly habit is due on the same weekday each week: name the days
    final due = _addDays(next, -1);
    final names = [for (final o in offsets) DateFormat.E().format(_addDays(due, -o))];
    return '$when (${names.join(' and ')})';
  }

  static bool _isDayByDay(HabitSchedule schedule) =>
      schedule.frequency == ResetFrequency.daily && schedule.interval == 1;

  static List<DateTime> _smartDays(HabitSchedule schedule, DateTime today, int horizon) {
    final end = _addDays(today, horizon);
    if (!schedule.isPeriodic || _isDayByDay(schedule)) {
      return [
        for (var i = 0; i < horizon; i++)
          if (schedule.isDueOn(_addDays(today, i))) _addDays(today, i),
      ];
    }

    final days = <DateTime>[];
    var start = schedule.periodStart(today);
    while (start.isBefore(end)) {
      final next = schedule.nextPeriodStart(start);
      final due = _addDays(next, -1);
      for (final offset in countdownOffsets(_daysBetween(start, next))) {
        final day = _addDays(due, -offset);
        if (!day.isBefore(start) && !day.isBefore(today) && day.isBefore(end)) days.add(day);
      }
      start = next;
    }
    days.sort();
    return days;
  }

  /// A break habit's check-in, when it has no message of its own.
  static const checkInBody = 'Still on track? Log any slips.';

  static String _body(Habit habit, DateTime day) {
    if (habit.isBreak) return checkInBody;
    final units = habit.units.isEmpty ? '' : ' ${habit.units}';
    final done = habit.progressForPeriodContaining(day);
    final schedule = habit.schedule;

    if (!schedule.isPeriodic) return '$done of ${habit.target}$units so far';
    if (_isDayByDay(schedule)) {
      return done == 0 ? '0 of ${habit.target}$units today' : '$done of ${habit.target}$units today. Keep going!';
    }

    final due = _addDays(schedule.nextPeriodStart(day), -1);
    final daysLeft = _daysBetween(day, due);
    final dueText = switch (daysLeft) {
      0 => 'Due today',
      1 => 'Due tomorrow',
      < 7 => 'Due ${DateFormat.EEEE().format(due)}',
      _ => 'Due ${DateFormat.MMMd().format(due)}',
    };
    final period = schedule.interval != 1
        ? 'this period'
        : switch (schedule.frequency) {
            ResetFrequency.weekly => 'this week',
            ResetFrequency.monthly => 'this month',
            _ => 'this period',
          };
    return '$done of ${habit.target}$units $period. $dueText';
  }

  static DateTime _at(DateTime day, int hour, int minute) => DateTime(day.year, day.month, day.day, hour, minute);

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  // Calendar-field arithmetic, so daylight-saving changes don't shift days
  static DateTime _addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

  static int _daysBetween(DateTime from, DateTime to) =>
      DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
}
