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
/// A period kept with the two-minute version counts at least half
/// ([TwoMinuteLog.credit]). A two-minute today counts early only when that
/// raises the score, so logging the tiny version never makes it drop.
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
      // A habit being broken: full credit at or under the limit, none over
      var done = breakLimit != null
          ? ((totals[periodStart] ?? 0) <= breakLimit ? 1.0 : 0.0)
          : math.min(1.0, (totals[periodStart] ?? 0) / target);
      final isTiny = tiny.contains(periodStart);
      if (isTiny) done = math.max(done, TwoMinuteLog.credit);
      final next = s * (1 - alpha) + done * alpha;
      if (periodStart == current && done < 1 && !(isTiny && next > s)) continue;
      s = next;
    }
    return 100 * s;
  }
}
