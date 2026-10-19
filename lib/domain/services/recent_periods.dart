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

  /// Frozen, or on vacation, and not kept: neither counted nor missed.
  frozen;

  /// Whether the period counts toward what was due (rest days, frozen
  /// periods and days before the habit was tracked don't).
  bool get isDue => this != rest && this != untracked && this != frozen;
}

class RecentPeriod {
  /// The local midnight the period began.
  final DateTime start;

  /// The local midnight the next period begins.
  final DateTime end;
  final PeriodMark mark;

  /// How much was done, 0 to 1 (a two-minute day counts half).
  final double fraction;

  const RecentPeriod(this.start, this.end, this.mark, this.fraction);

  /// A single day (not every few days, a week or a month).
  bool get isOneDay => end == DateTime(start.year, start.month, start.day + 1);

  @override
  String toString() => 'RecentPeriod($start, $mark, $fraction)';
}

/// A habit's last [count] periods, oldest first, ending with the one under
/// way at [now]: days for daily habits (rest days included), weeks or months
/// for longer ones. Empty for habits that never reset.
List<RecentPeriod> recentPeriods(Habit habit, DateTime now, {int count = 7}) =>
    periodsBack(habit, now, (starts) => starts.length < count);

/// A habit's periods back from the one under way at [now] for as long as
/// [more] says (given the starts so far, newest first), oldest first.
List<RecentPeriod> periodsBack(Habit habit, DateTime now, bool Function(List<DateTime> starts) more) {
  final schedule = habit.schedule;
  if (!schedule.isPeriodic) return const [];

  // Newest first while walking back (one date sum a period), then turned round
  final starts = [schedule.periodStart(now)];
  while (more(starts)) {
    starts.add(schedule.periodStart(starts.last.subtract(const Duration(hours: 12))));
  }
  final tracked = habit.trackedFrom;
  final periods = <RecentPeriod>[];
  var end = schedule.nextPeriodStart(starts.first);
  for (var i = 0; i < starts.length; i++) {
    periods.add(_markFor(habit, starts[i], end, isCurrent: i == 0, tracked: tracked));
    end = starts[i];
  }
  return periods.reversed.toList();
}

RecentPeriod _markFor(Habit habit, DateTime start, DateTime end, {required bool isCurrent, required DateTime tracked}) {
  if (!end.isAfter(tracked)) return RecentPeriod(start, end, PeriodMark.untracked, 0);
  final outcome = habit.periodOutcome(start, end);
  if (!habit.isDueOn(start)) return RecentPeriod(start, end, PeriodMark.rest, outcome.fraction);
  if (habit.skipsPeriod(start)) return RecentPeriod(start, end, PeriodMark.frozen, outcome.fraction);
  if (outcome.completed) return RecentPeriod(start, end, PeriodMark.done, 1);
  if (outcome.twoMinute) return RecentPeriod(start, end, PeriodMark.twoMinute, outcome.fraction);
  if (isCurrent) return RecentPeriod(start, end, PeriodMark.current, outcome.fraction);
  return RecentPeriod(start, end, outcome.fraction > 0 ? PeriodMark.partial : PeriodMark.missed, outcome.fraction);
}
