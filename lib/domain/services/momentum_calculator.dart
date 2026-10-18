import 'dart:math' as math;
import '../entities/habit_schedule.dart';
import '../entities/momentum.dart';
import '../entities/two_minute_version.dart';
import 'period_totals.dart';

/// Derives a habit's momentum from its per-day history.
///
/// Each due period since [start] contributes how much of the target was done
/// (6 of 8 counts as 0.75) to an exponential moving average. The current
/// period only counts once it's complete, so finishing today raises the
/// score at once while an unfinished today never lowers it. Rest days aren't
/// due periods, so they're ignored.
///
/// A period kept with the two-minute version never lowers the score: it
/// holds it where it is, or lifts it toward half ([TwoMinuteLog.credit])
/// when it's lower. Showing up small is never punished; only full days
/// climb high. A two-minute today counts early only when that raises the
/// score.
///
/// Calibrated so that steady practice reaches 80 in about 66 days (the
/// average time to form a habit, Lally et al. 2009) whatever the schedule,
/// with at least 8 periods for slow schedules like monthly.
class MomentumCalculator {
  const MomentumCalculator._();

  static const _daysToHabit = 66.0;
  static const _minPeriodsToHabit = 8.0;
  static const _scoreAtHabit = 0.8;

  static Momentum calculate({
    required Map<DateTime, int> history,
    required int target,
    required HabitSchedule schedule,
    required DateTime start,
    required DateTime now,
    TwoMinuteLog twoMinute = TwoMinuteLog.none,
    int? breakLimit,
  }) {
    if (!schedule.isPeriodic || (breakLimit == null && target <= 0)) return Momentum.none;

    final alpha = smoothing(schedule);
    final score = _scoreAt(history, target, schedule, start, now, alpha, twoMinute, breakLimit);
    final weekAgo = DateTime(now.year, now.month, now.day - 7, now.hour, now.minute);
    final before = _scoreAt(history, target, schedule, start, weekAgo, alpha, twoMinute, breakLimit);
    return Momentum(score: score, trend: score - before);
  }

  /// The weight each new period gets in the moving average.
  static double smoothing(HabitSchedule schedule) {
    final periods = math.max(_minPeriodsToHabit, _daysToHabit / schedule.averageDaysBetweenDuePeriods);
    return 1 - math.pow(1 - _scoreAtHabit, 1 / periods).toDouble();
  }

  /// The score at each of [at] (oldest first), as [calculate] would give
  /// with history up to that moment, in one pass: for charts over many days.
  static List<double> series({
    required Map<DateTime, int> history,
    required int target,
    required HabitSchedule schedule,
    required DateTime start,
    required List<DateTime> at,
    TwoMinuteLog twoMinute = TwoMinuteLog.none,
    int? breakLimit,
  }) {
    if (at.isEmpty) return const [];
    if (!schedule.isPeriodic || (breakLimit == null && target <= 0)) return [for (final _ in at) 0.0];
    assert(() {
      for (var i = 1; i < at.length; i++) {
        if (at[i].isBefore(at[i - 1])) return false;
      }
      return true;
    }(), 'times must be in order');

    final alpha = smoothing(schedule);
    final last = at.last;
    final totals = PeriodTotals.byPeriodStart(history, schedule, last);
    final tiny = PeriodTotals.twoMinuteStarts(totals, twoMinute, schedule, last);
    final due = PeriodTotals.dueStarts(schedule, start, last).toList();

    // What the period under way held at each time, kept as a sliding window
    // over the logged days (times only move forward, and so do periods), so
    // a year of days costs one pass rather than one pass per day
    final logged = [for (final e in history.entries) if (e.value > 0) e]..sort((a, b) => a.key.compareTo(b.key));
    final tapped = twoMinute.days.toList()..sort();
    var loggedFrom = 0, loggedTo = 0, windowTotal = 0;
    var tappedFrom = 0, tappedTo = 0;

    var s = 0.0;
    var next = 0;
    final scores = <double>[];
    for (final time in at) {
      if (time.isBefore(start)) {
        scores.add(0);
        continue;
      }
      final current = schedule.periodStart(time);
      // Periods ended by then count in full
      while (next < due.length && due[next].isBefore(current)) {
        final period = due[next++];
        final done = _credit(totals[period] ?? 0, tiny.contains(period), s, target, breakLimit);
        s = s * (1 - alpha) + done * alpha;
      }
      var score = s;
      if (next < due.length && due[next] == current) {
        // The period under way, as it stood then: logged from its start to [time]
        for (; loggedTo < logged.length && !logged[loggedTo].key.isAfter(time); loggedTo++) {
          windowTotal += logged[loggedTo].value;
        }
        for (; loggedFrom < loggedTo && logged[loggedFrom].key.isBefore(current); loggedFrom++) {
          windowTotal -= logged[loggedFrom].value;
        }
        for (; tappedTo < tapped.length && !tapped[tappedTo].isAfter(time); tappedTo++) {}
        for (; tappedFrom < tappedTo && tapped[tappedFrom].isBefore(current); tappedFrom++) {}
        final total = windowTotal;
        final usedTiny = tappedTo > tappedFrom;
        final minimum = twoMinute.minimum;
        final isTiny = usedTiny || (minimum != null && minimum > 0 && total >= minimum);
        score = _counted(s, _credit(total, isTiny, s, target, breakLimit), isTiny, alpha) ?? s;
      }
      scores.add(100 * score);
    }
    return scores;
  }

  /// How much of a period was done, 0 to 1. A habit being broken gets full
  /// credit at or under the limit and none over it; a two-minute period
  /// holds the score [s] or lifts it toward half.
  static double _credit(int total, bool isTiny, double s, int target, int? breakLimit) {
    var done = breakLimit != null ? (total <= breakLimit ? 1.0 : 0.0) : math.min(1.0, total / target);
    if (isTiny) done = math.max(done, math.max(TwoMinuteLog.credit, s));
    return done;
  }

  /// The score after the period under way, or null while it doesn't count
  /// yet: only once complete, or kept small when that raises the score.
  static double? _counted(double s, double done, bool isTiny, double alpha) {
    final next = s * (1 - alpha) + done * alpha;
    return done >= 1 || (isTiny && next > s) ? next : null;
  }

  static double _scoreAt(
    Map<DateTime, int> history,
    int target,
    HabitSchedule schedule,
    DateTime start,
    DateTime at,
    double alpha,
    TwoMinuteLog twoMinute,
    int? breakLimit,
  ) {
    if (at.isBefore(start)) return 0;
    final totals = PeriodTotals.byPeriodStart(history, schedule, at);
    final tiny = PeriodTotals.twoMinuteStarts(totals, twoMinute, schedule, at);
    final current = schedule.periodStart(at);

    var s = 0.0;
    for (final periodStart in PeriodTotals.dueStarts(schedule, start, at)) {
      final isTiny = tiny.contains(periodStart);
      final done = _credit(totals[periodStart] ?? 0, isTiny, s, target, breakLimit);
      if (periodStart == current) {
        s = _counted(s, done, isTiny, alpha) ?? s;
      } else {
        s = s * (1 - alpha) + done * alpha;
      }
    }
    return 100 * s;
  }
}
