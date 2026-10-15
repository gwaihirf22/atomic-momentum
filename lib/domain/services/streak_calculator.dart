import '../entities/reset_frequency.dart';
import '../entities/streak_data.dart';

/// Derives a habit's streak from its per-day history.
///
/// A streak counts consecutive completed periods (days, weeks or months,
/// depending on [ResetFrequency]). A period is completed when the amounts
/// logged on its days add up to the target. The current period still being
/// in progress does not break the streak; once it ends incomplete, the streak
/// drops to 0. Because the streak is recomputed from history, editing a past
/// day automatically repairs or breaks it.
class StreakCalculator {
  const StreakCalculator._();

  static StreakData calculate({
    required Map<DateTime, int> history,
    required int target,
    required ResetFrequency frequency,
    required DateTime anchor,
    required DateTime now,
  }) {
    if (!frequency.isPeriodic || target <= 0) return StreakData.empty();

    final completedPeriods = _completedPeriodStarts(history, target, frequency, anchor, now);
    if (completedPeriods.isEmpty) return StreakData.empty();

    final current = _currentStreak(completedPeriods, frequency, anchor, now);
    final runs = _runs(completedPeriods.toList()..sort(), frequency, anchor);

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

  /// Start of the period that ends the current streak if it is not completed,
  /// or null when there is no streak at risk. If the current period is already
  /// complete, the next deadline is the end of the following period.
  static DateTime? streakDeadline({
    required Map<DateTime, int> history,
    required int target,
    required ResetFrequency frequency,
    required DateTime anchor,
    required DateTime now,
  }) {
    if (!frequency.isPeriodic || target <= 0) return null;

    final streak = calculate(
      history: history,
      target: target,
      frequency: frequency,
      anchor: anchor,
      now: now,
    );
    if (streak.current == 0) return null;

    final completedPeriods = _completedPeriodStarts(history, target, frequency, anchor, now);
    final currentStart = frequency.periodStart(now, anchor: anchor);
    final currentEnd = frequency.nextPeriodStart(now, anchor: anchor);

    if (completedPeriods.contains(currentStart)) {
      return frequency.nextPeriodStart(currentEnd, anchor: anchor);
    }
    return currentEnd;
  }

  static Set<DateTime> _completedPeriodStarts(
    Map<DateTime, int> history,
    int target,
    ResetFrequency frequency,
    DateTime anchor,
    DateTime now,
  ) {
    final totals = <DateTime, int>{};
    for (final entry in history.entries) {
      if (entry.value <= 0 || entry.key.isAfter(now)) continue;
      final start = frequency.periodStart(entry.key, anchor: anchor);
      totals[start] = (totals[start] ?? 0) + entry.value;
    }
    return {
      for (final entry in totals.entries)
        if (entry.value >= target) entry.key,
    };
  }

  static int _currentStreak(
    Set<DateTime> completed,
    ResetFrequency frequency,
    DateTime anchor,
    DateTime now,
  ) {
    var periodStart = frequency.periodStart(now, anchor: anchor);
    // An unfinished current period doesn't break the streak yet
    if (!completed.contains(periodStart)) {
      periodStart = _previousPeriodStart(periodStart, frequency, anchor);
    }

    var count = 0;
    while (completed.contains(periodStart)) {
      count++;
      periodStart = _previousPeriodStart(periodStart, frequency, anchor);
    }
    return count;
  }

  static DateTime _previousPeriodStart(DateTime periodStart, ResetFrequency frequency, DateTime anchor) {
    final dayBefore = DateTime(periodStart.year, periodStart.month, periodStart.day - 1);
    return frequency.periodStart(dayBefore, anchor: anchor);
  }

  static List<_Run> _runs(List<DateTime> sortedStarts, ResetFrequency frequency, DateTime anchor) {
    final runs = <_Run>[];
    for (final start in sortedStarts) {
      if (runs.isNotEmpty &&
          frequency.nextPeriodStart(runs.last.lastPeriodStart, anchor: anchor) == start) {
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
