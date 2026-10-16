import '../entities/habit_schedule.dart';

/// History summed per period. Shared by the streak and momentum calculations
/// so they agree on what each period's total is.
class PeriodTotals {
  const PeriodTotals._();

  /// The amount logged in each period up to [now], keyed by period start.
  static Map<DateTime, int> byPeriodStart(
    Map<DateTime, int> history,
    HabitSchedule schedule,
    DateTime now,
  ) {
    final totals = <DateTime, int>{};
    for (final entry in history.entries) {
      if (entry.value <= 0 || entry.key.isAfter(now)) continue;
      final start = schedule.periodStart(entry.key);
      totals[start] = (totals[start] ?? 0) + entry.value;
    }
    return totals;
  }

  /// Starts of the due periods from the one containing [from] (or the first
  /// due one after it) through the one containing [now], oldest first.
  static Iterable<DateTime> dueStarts(HabitSchedule schedule, DateTime from, DateTime now) sync* {
    var start = schedule.periodStart(from);
    if (!schedule.isDueOn(start)) start = schedule.nextDuePeriodStart(start);
    final last = schedule.periodStart(now);
    while (!start.isAfter(last)) {
      yield start;
      start = schedule.nextDuePeriodStart(start);
    }
  }
}
