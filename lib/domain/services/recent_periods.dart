import '../entities/habit.dart';

/// How one of a habit's recent periods went.
enum PeriodMark {
  /// The target was reached.
  done,

  /// Kept with the two-minute version.
  twoMinute,

  /// Some done, not enough, and the period is over.
  partial,

  /// Nothing done, and the period is over.
  missed,

  /// The period now under way, not finished yet.
  current,

  /// A rest day: not due.
  rest,

  /// Before the habit was tracked.
  untracked,
}

class RecentPeriod {
  /// The local midnight the period began.
  final DateTime start;
  final PeriodMark mark;

  /// How much was done, 0 to 1 (a two-minute day counts half).
  final double fraction;

  const RecentPeriod(this.start, this.mark, this.fraction);

  @override
  String toString() => 'RecentPeriod($start, $mark, $fraction)';
}

/// A habit's last [count] periods, oldest first, ending with the one under
/// way at [now]: days for daily habits (rest days included), weeks or months
/// for longer ones. Empty for habits that never reset.
List<RecentPeriod> recentPeriods(Habit habit, DateTime now, {int count = 7}) {
  final schedule = habit.schedule;
  if (!schedule.isPeriodic) return const [];

  var start = schedule.periodStart(now);
  final starts = [start];
  while (starts.length < count) {
    start = schedule.periodStart(start.subtract(const Duration(hours: 12)));
    starts.insert(0, start);
  }

  final tracked = habit.trackedFrom;
  final current = starts.last;
  return [
    for (final start in starts) _markFor(habit, start, isCurrent: start == current, tracked: tracked),
  ];
}

RecentPeriod _markFor(Habit habit, DateTime start, {required bool isCurrent, required DateTime tracked}) {
  final schedule = habit.schedule;
  final fraction = habit.fractionDoneOn(start);
  if (!schedule.nextPeriodStart(start).isAfter(tracked)) return RecentPeriod(start, PeriodMark.untracked, 0);
  if (!habit.isDueOn(start)) return RecentPeriod(start, PeriodMark.rest, fraction);
  if (habit.wasCompletedOnDate(start)) return RecentPeriod(start, PeriodMark.done, 1);
  if (habit.isTwoMinuteOn(start)) return RecentPeriod(start, PeriodMark.twoMinute, fraction);
  if (isCurrent) return RecentPeriod(start, PeriodMark.current, fraction);
  return RecentPeriod(start, fraction > 0 ? PeriodMark.partial : PeriodMark.missed, fraction);
}
