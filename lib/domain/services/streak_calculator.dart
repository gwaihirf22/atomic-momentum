import '../entities/habit_schedule.dart';
import '../entities/streak_data.dart';
import 'period_totals.dart';

/// Derives a habit's streak from its per-day history.
///
/// A streak counts completed due periods (days, N-day blocks, weeks or
/// months, per the [HabitSchedule]). A period is completed when the amounts
/// logged on its days add up to the target.
///
/// Never miss twice: a single missed due period bends the streak instead of
/// breaking it (it doesn't add to the count, and the streak is "at risk"
/// until the habit is completed again); two misses in a row end it. Rest days
/// (days a weekday schedule doesn't include) are skipped, so they're never
/// misses, and logging on them doesn't extend a streak. The current period
/// still being in progress isn't a miss. Because the streak is recomputed
/// from history, editing a past day automatically repairs or breaks it.
class StreakCalculator {
  const StreakCalculator._();

  /// Consecutive missed due periods that end a streak.
  static const missesToBreak = 2;

  static StreakData calculate({
    required Map<DateTime, int> history,
    required int target,
    required HabitSchedule schedule,
    required DateTime now,
  }) {
    if (!schedule.isPeriodic || target <= 0) return StreakData.empty();
    return _calculate(_completedPeriodStarts(history, target, schedule, now), schedule, now);
  }

  /// When the current streak is lost if the habit isn't completed, or null
  /// when there is no streak at stake: the end of the next unfinished due
  /// period after a miss, otherwise the end of the second one (one more miss
  /// is allowed).
  static DateTime? streakDeadline({
    required Map<DateTime, int> history,
    required int target,
    required HabitSchedule schedule,
    required DateTime now,
  }) {
    if (!schedule.isPeriodic || target <= 0) return null;

    final completed = _completedPeriodStarts(history, target, schedule, now);
    final streak = _calculate(completed, schedule, now);
    if (streak.current == 0) return null;

    final firstOpen = firstOpenDuePeriodStart(completed, schedule, now);
    if (streak.atRisk) return schedule.nextPeriodStart(firstOpen);
    return schedule.nextPeriodStart(schedule.nextDuePeriodStart(firstOpen));
  }

  /// End of the next unfinished due period: the current one while it's due
  /// and unfinished, otherwise the next due one. Missing it is a miss.
  static DateTime nextMissAt({
    required Map<DateTime, int> history,
    required int target,
    required HabitSchedule schedule,
    required DateTime now,
  }) {
    final completed = _completedPeriodStarts(history, target, schedule, now);
    return schedule.nextPeriodStart(firstOpenDuePeriodStart(completed, schedule, now));
  }

  static DateTime firstOpenDuePeriodStart(Set<DateTime> completed, HabitSchedule schedule, DateTime now) {
    final currentStart = schedule.periodStart(now);
    final currentIsOpen = schedule.isDueOn(currentStart) && !completed.contains(currentStart);
    return currentIsOpen ? currentStart : schedule.nextDuePeriodStart(now);
  }

  static StreakData _calculate(Set<DateTime> completed, HabitSchedule schedule, DateTime now) {
    if (completed.isEmpty) return StreakData.empty();

    final (current, atRisk) = _currentStreak(completed, schedule, now);
    final runs = _runs(completed.toList()..sort(), schedule);

    final longest = runs.fold<int>(0, (max, run) => run.length > max ? run.length : max);
    final lastCompleted = runs.last.lastPeriodStart;

    final periods = <StreakPeriod>[
      for (final run in runs)
        StreakPeriod(
          startDate: run.firstPeriodStart,
          // The run feeding the current streak is still open
          endDate: (current > 0 && identical(run, runs.last)) ? null : run.lastPeriodStart,
          length: run.length,
        ),
    ];

    return StreakData(
      current: current,
      longest: longest,
      lastUpdateDate: lastCompleted,
      history: periods,
      atRisk: atRisk,
    );
  }

  static Set<DateTime> _completedPeriodStarts(
    Map<DateTime, int> history,
    int target,
    HabitSchedule schedule,
    DateTime now,
  ) {
    final totals = PeriodTotals.byPeriodStart(history, schedule, now);
    return {
      for (final entry in totals.entries)
        if (entry.value >= target && schedule.isDueOn(entry.key)) entry.key,
    };
  }

  /// The current streak, and whether the last ended due period was missed
  /// (so one more miss ends it).
  static (int, bool) _currentStreak(Set<DateTime> completed, HabitSchedule schedule, DateTime now) {
    var periodStart = schedule.periodStart(now);
    // An unfinished current period (or a rest day) isn't a miss yet
    if (!completed.contains(periodStart)) {
      periodStart = schedule.previousDuePeriodStart(periodStart);
    }
    final lastEndedWasMissed = !completed.contains(periodStart);

    // Walk back until two misses in a row; completed is finite, so this ends
    var count = 0;
    var missesInARow = 0;
    while (missesInARow < missesToBreak) {
      if (completed.contains(periodStart)) {
        count++;
        missesInARow = 0;
      } else {
        missesInARow++;
      }
      periodStart = schedule.previousDuePeriodStart(periodStart);
    }
    return (count, count > 0 && lastEndedWasMissed);
  }

  /// Groups completed periods into streaks, bridging single missed periods.
  static List<_Run> _runs(List<DateTime> sortedStarts, HabitSchedule schedule) {
    final runs = <_Run>[];
    for (final start in sortedStarts) {
      if (runs.isNotEmpty && _withinOneMiss(runs.last.lastPeriodStart, start, schedule)) {
        runs.last
          ..lastPeriodStart = start
          ..length += 1;
      } else {
        runs.add(_Run(start));
      }
    }
    return runs;
  }

  static bool _withinOneMiss(DateTime previous, DateTime start, HabitSchedule schedule) {
    var next = schedule.nextDuePeriodStart(previous);
    for (var gap = 0; gap < missesToBreak; gap++) {
      if (next == start) return true;
      next = schedule.nextDuePeriodStart(next);
    }
    return false;
  }
}

class _Run {
  _Run(this.firstPeriodStart) : lastPeriodStart = firstPeriodStart;

  final DateTime firstPeriodStart;
  DateTime lastPeriodStart;
  int length = 1;
}
