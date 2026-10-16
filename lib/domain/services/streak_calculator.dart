import '../entities/habit_schedule.dart';
import '../entities/streak_data.dart';

/// Derives a habit's streak from its per-day history.
///
/// A streak counts consecutive completed due periods (days, N-day blocks,
/// weeks or months, per the [HabitSchedule]). A period is completed when the
/// amounts logged on its days add up to the target. Rest days (days a
/// weekday schedule doesn't include) are skipped, so they never break a
/// streak, and logging on them doesn't extend one. The current period still
/// being in progress does not break the streak; once a due period ends
/// incomplete, the streak drops to 0. Because the streak is recomputed from
/// history, editing a past day automatically repairs or breaks it.
class StreakCalculator {
  const StreakCalculator._();

  static StreakData calculate({
    required Map<DateTime, int> history,
    required int target,
    required HabitSchedule schedule,
    required DateTime now,
  }) {
    if (!schedule.isPeriodic || target <= 0) return StreakData.empty();

    final completedPeriods = _completedPeriodStarts(history, target, schedule, now);
    if (completedPeriods.isEmpty) return StreakData.empty();

    final current = _currentStreak(completedPeriods, schedule, now);
    final runs = _runs(completedPeriods.toList()..sort(), schedule);

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
    );
  }

  /// When the current streak is lost if the habit isn't completed, or null
  /// when there is no streak at stake. If the current period is already
  /// complete, or today is a rest day, it's the end of the next due period.
  static DateTime? streakDeadline({
    required Map<DateTime, int> history,
    required int target,
    required HabitSchedule schedule,
    required DateTime now,
  }) {
    if (!schedule.isPeriodic || target <= 0) return null;

    final streak = calculate(history: history, target: target, schedule: schedule, now: now);
    if (streak.current == 0) return null;

    final completedPeriods = _completedPeriodStarts(history, target, schedule, now);
    final currentStart = schedule.periodStart(now);

    if (schedule.isDueOn(currentStart) && !completedPeriods.contains(currentStart)) {
      return schedule.nextPeriodStart(now);
    }
    return schedule.nextPeriodStart(schedule.nextDuePeriodStart(now));
  }

  static Set<DateTime> _completedPeriodStarts(
    Map<DateTime, int> history,
    int target,
    HabitSchedule schedule,
    DateTime now,
  ) {
    final totals = <DateTime, int>{};
    for (final entry in history.entries) {
      if (entry.value <= 0 || entry.key.isAfter(now)) continue;
      final start = schedule.periodStart(entry.key);
      totals[start] = (totals[start] ?? 0) + entry.value;
    }
    return {
      for (final entry in totals.entries)
        if (entry.value >= target && schedule.isDueOn(entry.key)) entry.key,
    };
  }

  static int _currentStreak(Set<DateTime> completed, HabitSchedule schedule, DateTime now) {
    var periodStart = schedule.periodStart(now);
    // An unfinished current period (or a rest day) doesn't break the streak yet
    if (!completed.contains(periodStart)) {
      periodStart = schedule.previousDuePeriodStart(periodStart);
    }

    var count = 0;
    while (completed.contains(periodStart)) {
      count++;
      periodStart = schedule.previousDuePeriodStart(periodStart);
    }
    return count;
  }

  static List<_Run> _runs(List<DateTime> sortedStarts, HabitSchedule schedule) {
    final runs = <_Run>[];
    for (final start in sortedStarts) {
      if (runs.isNotEmpty && schedule.nextDuePeriodStart(runs.last.lastPeriodStart) == start) {
        runs.last
          ..lastPeriodStart = start
          ..length += 1;
      } else {
        runs.add(_Run(start));
      }
    }
    return runs;
  }
}

class _Run {
  _Run(this.firstPeriodStart) : lastPeriodStart = firstPeriodStart;

  final DateTime firstPeriodStart;
  DateTime lastPeriodStart;
  int length = 1;
}
