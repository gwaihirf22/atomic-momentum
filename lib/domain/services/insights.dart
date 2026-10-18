import '../entities/habit.dart';
import '../entities/momentum.dart';
import 'recent_periods.dart';

/// One day across a set of habits, for the heatmap.
///
/// A habit done day by day counts on each day it's due. A habit with longer
/// periods (every few days, weekly, monthly) counts on the day its period
/// was kept, when the target (or the two-minute version) was reached; a
/// period it missed has no single day to show on.
class DayRecord {
  final DateTime day;

  /// Habits counted that day.
  final int due;

  /// Of those, done in full.
  final int done;

  /// Kept with the two-minute version.
  final int twoMinute;

  /// How much was done, summed over the habits counted (0 to [due]).
  final double amount;

  const DayRecord({required this.day, this.due = 0, this.done = 0, this.twoMinute = 0, this.amount = 0});

  /// 0 to 1: how much of the day's habits was done.
  double get level => due == 0 ? 0 : (amount / due).clamp(0.0, 1.0);

  /// Every habit counted that day was done in full.
  bool get perfect => due > 0 && done == due;

  bool get isEmpty => due == 0;

  DayRecord _plus({int done = 0, int twoMinute = 0, required double amount}) => DayRecord(
        day: day,
        due: due + 1,
        done: this.done + done,
        twoMinute: this.twoMinute + twoMinute,
        amount: this.amount + amount,
      );

  @override
  String toString() => 'DayRecord($day, $done+$twoMinute of $due, ${level.toStringAsFixed(2)})';
}

/// Overall momentum at the end of one month (or now, for this month).
class MonthMomentum {
  /// The first of the month.
  final DateTime month;

  /// Null when no habit was being tracked yet.
  final double? score;

  const MonthMomentum(this.month, this.score);

  @override
  String toString() => 'MonthMomentum(${month.year}-${month.month}, $score)';
}

/// How the periods that ended in a range went, across habits.
class KeptSummary {
  final int full;
  final int twoMinute;

  /// Partly done or missed.
  final int missed;

  /// Two-minute periods that kept a streak alive: they came right after a
  /// missed one, so without them the streak would have ended.
  final int streaksSaved;

  const KeptSummary({this.full = 0, this.twoMinute = 0, this.missed = 0, this.streaksSaved = 0});

  int get total => full + twoMinute + missed;
  int get kept => full + twoMinute;
}

/// Kept share by weekday for habits done day by day.
class WeekdayPattern {
  /// DateTime.monday..sunday → kept share 0 to 1; only weekdays with enough
  /// days to say anything.
  final Map<int, double> rates;

  const WeekdayPattern(this.rates);

  /// Days needed on a weekday before its rate means something.
  static const minDays = 4;

  bool get isEmpty => rates.length < 7;

  int? get best => isEmpty ? null : rates.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  int? get hardest => isEmpty ? null : rates.entries.reduce((a, b) => b.value < a.value ? b : a).key;
}

/// Statistics across habits, all worked out from their history (so habits
/// filled in from elsewhere, such as Apple Health, need nothing special).
class Insights {
  const Insights._();

  /// One record for each day from [from] to [to] (date-only, inclusive),
  /// as things stand at [now].
  static List<DayRecord> days(List<Habit> habits, {required DateTime from, required DateTime to, required DateTime now}) {
    final first = _date(from);
    final last = _date(to);
    final records = <DateTime, DayRecord>{
      for (var d = first; !d.isAfter(last); d = DateTime(d.year, d.month, d.day + 1)) d: DayRecord(day: d),
    };

    void add(DateTime day, RecentPeriod period) {
      final record = records[day];
      if (record == null) return;
      records[day] = record._plus(
        done: period.mark == PeriodMark.done ? 1 : 0,
        twoMinute: period.mark == PeriodMark.twoMinute ? 1 : 0,
        amount: period.fraction,
      );
    }

    for (final habit in habits) {
      for (final period in periods(habit, now)) {
        if (period.mark == PeriodMark.untracked || period.mark == PeriodMark.rest) continue;
        if (_isOneDay(habit, period.start)) {
          add(period.start, period);
        } else if (period.mark == PeriodMark.done || period.mark == PeriodMark.twoMinute) {
          final day = _keptOn(habit, period);
          if (day != null && !day.isAfter(_date(now))) add(day, period);
        }
      }
    }
    return records.values.toList();
  }

  /// Overall momentum at the end of each of the last [count] months, oldest
  /// first, the last being this month so far. Habits count once they're
  /// tracked, as for the Habits ring.
  static List<MonthMomentum> momentumByMonth(List<Habit> habits, DateTime now, {int count = 6}) {
    final times = [
      for (var i = count - 1; i >= 1; i--) DateTime(now.year, now.month - i + 1, 0, 23, 59),
      now,
    ];
    final sums = List<double>.filled(times.length, 0);
    final counts = List<int>.filled(times.length, 0);
    for (final habit in habits) {
      if (!habit.schedule.isPeriodic) continue;
      final scores = habit.momentumSeries(times);
      for (var i = 0; i < times.length; i++) {
        if (!habit.countsTowardMomentumAt(times[i])) continue;
        sums[i] += scores[i];
        counts[i]++;
      }
    }
    return [
      for (var i = 0; i < times.length; i++)
        MonthMomentum(DateTime(times[i].year, times[i].month), counts[i] == 0 ? null : sums[i] / counts[i]),
    ];
  }

  /// How the periods that ended between [from] and [now] went (habits being
  /// broken have no two-minute version, so they count as full or missed).
  static KeptSummary kept(List<Habit> habits, {required DateTime from, required DateTime now}) {
    final first = _date(from);
    var full = 0, twoMinute = 0, missed = 0, saved = 0;
    for (final habit in habits) {
      // From the start, to know whether a streak was going before [from]
      final habitPeriods = periods(habit, now)
          .where((p) => p.mark != PeriodMark.untracked && p.mark != PeriodMark.rest && p.mark != PeriodMark.current)
          .toList();
      var streak = 0;
      PeriodMark? previous;
      var streakBeforeMiss = 0;
      for (final period in habitPeriods) {
        final inRange = !period.start.isBefore(habit.schedule.periodStart(first));
        final mark = period.mark;
        if (mark == PeriodMark.done || mark == PeriodMark.twoMinute) {
          final missedBefore = previous == PeriodMark.missed || previous == PeriodMark.partial;
          if (mark == PeriodMark.twoMinute && missedBefore && streakBeforeMiss > 0 && inRange) saved++;
          streak = (missedBefore ? streakBeforeMiss : streak) + 1;
          if (inRange) mark == PeriodMark.done ? full++ : twoMinute++;
        } else {
          // One miss puts the streak at risk; two in a row end it
          final missedBefore = previous == PeriodMark.missed || previous == PeriodMark.partial;
          streakBeforeMiss = missedBefore ? 0 : streak;
          streak = 0;
          if (inRange) missed++;
        }
        previous = mark;
      }
    }
    return KeptSummary(full: full, twoMinute: twoMinute, missed: missed, streaksSaved: saved);
  }

  /// The kept share on each weekday, for habits done day by day, over days
  /// that ended between [from] and [now].
  static WeekdayPattern weekdays(List<Habit> habits, {required DateTime from, required DateTime now}) {
    final kept = List<int>.filled(8, 0);
    final due = List<int>.filled(8, 0);
    for (final habit in habits) {
      for (final period in periods(habit, now)) {
        if (period.start.isBefore(_date(from)) || !_isOneDay(habit, period.start)) continue;
        final mark = period.mark;
        if (mark == PeriodMark.untracked || mark == PeriodMark.rest || mark == PeriodMark.current) continue;
        final weekday = period.start.weekday;
        due[weekday]++;
        if (mark == PeriodMark.done || mark == PeriodMark.twoMinute) kept[weekday]++;
      }
    }
    return WeekdayPattern({
      for (var day = DateTime.monday; day <= DateTime.sunday; day++)
        if (due[day] >= WeekdayPattern.minDays) day: kept[day] / due[day],
    });
  }

  /// Habits whose momentum is at or past the mark where a habit has formed.
  static int formed(List<Habit> habits) =>
      habits.where((h) => h.schedule.isPeriodic && h.momentum.rounded >= Momentum.habitFormed).length;

  /// The longest streak any habit has had.
  static int longestStreak(List<Habit> habits) => habits.fold(
        0,
        (best, h) => [best, h.streak.longest, h.streak.current].reduce((a, b) => a > b ? a : b),
      );

  /// Periods worked out per habit, kept while the habit lives (a Habit never
  /// changes), so the heatmap, kept counts and weekdays share the work.
  static final _cache = Expando<Map<DateTime, List<RecentPeriod>>>('insight periods');

  /// A habit's periods from when it was first tracked to the one under way
  /// at [now], oldest first.
  static List<RecentPeriod> periods(Habit habit, DateTime now) {
    final schedule = habit.schedule;
    if (!schedule.isPeriodic) return const [];
    final cached = _cache[habit] ??= {};
    return cached[now] ??= () {
      final first = schedule.periodStart(habit.trackedFrom);
      var start = schedule.periodStart(now);
      var count = 1;
      while (start.isAfter(first)) {
        start = schedule.periodStart(start.subtract(const Duration(hours: 12)));
        count++;
      }
      return recentPeriods(habit, now, count: count);
    }();
  }

  static bool _isOneDay(Habit habit, DateTime start) =>
      habit.schedule.nextPeriodStart(start) == DateTime(start.year, start.month, start.day + 1);

  /// The day a longer period was kept: when its running total reached the
  /// target (or the two-minute minimum), or the "2 min" button was used. A
  /// habit being broken keeps a period on its last day.
  static DateTime? _keptOn(Habit habit, RecentPeriod period) {
    final schedule = habit.schedule;
    final end = schedule.nextPeriodStart(period.start);
    final lastDay = DateTime(end.year, end.month, end.day - 1);
    if (habit.isBreak) return lastDay;
    final goal = period.mark == PeriodMark.done ? habit.target : (habit.twoMinute?.minimum ?? 0);
    var total = 0;
    for (var d = period.start; d.isBefore(end); d = DateTime(d.year, d.month, d.day + 1)) {
      total += habit.history[d] ?? 0;
      final tapped = period.mark == PeriodMark.twoMinute && habit.twoMinuteDays.contains(d);
      if ((goal > 0 && total >= goal) || tapped) return d;
    }
    return lastDay;
  }

  static DateTime _date(DateTime t) => DateTime(t.year, t.month, t.day);
}
