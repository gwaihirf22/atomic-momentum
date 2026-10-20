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

  /// Habits frozen (or on vacation) that day: not counted in [due].
  final int frozen;

  const DayRecord({
    required this.day,
    this.due = 0,
    this.done = 0,
    this.twoMinute = 0,
    this.amount = 0,
    this.frozen = 0,
  });

  /// 0 to 1: how much of the day's habits was done.
  double get level => due == 0 ? 0 : (amount / due).clamp(0.0, 1.0);

  /// Every habit counted that day was done in full.
  bool get perfect => due > 0 && done == due;

  bool get isEmpty => due == 0;

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
    final index = <DateTime, int>{};
    for (var d = first; !d.isAfter(last); d = DateTime(d.year, d.month, d.day + 1)) {
      index[d] = index.length;
    }
    final due = List<int>.filled(index.length, 0);
    final done = List<int>.filled(index.length, 0);
    final tiny = List<int>.filled(index.length, 0);
    final amount = List<double>.filled(index.length, 0);
    final frozen = List<int>.filled(index.length, 0);
    for (final habit in habits) {
      for (final entry in _daysOf(habit, now).entries) {
        final i = index[entry.key];
        if (i == null) continue;
        final mark = entry.value;
        if (mark.mark == PeriodMark.frozen) {
          frozen[i]++;
          continue;
        }
        due[i]++;
        if (mark.mark == PeriodMark.done) done[i]++;
        if (mark.mark == PeriodMark.twoMinute) tiny[i]++;
        amount[i] += mark.fraction;
      }
    }
    return [
      for (final entry in index.entries)
        DayRecord(
          day: entry.key,
          due: due[entry.value],
          done: done[entry.value],
          twoMinute: tiny[entry.value],
          amount: amount[entry.value],
          frozen: frozen[entry.value],
        ),
    ];
  }

  /// Where each of a habit's periods shows on the heatmap, by day, as things
  /// stand on [now]'s day: a day's own day; a longer period, the day it was
  /// kept. Kept per habit and day, so screens and achievements share it.
  static final _dayCache = Expando<Map<DateTime, Map<DateTime, RecentPeriod>>>('insight days');

  static Map<DateTime, RecentPeriod> _daysOf(Habit habit, DateTime now) {
    final today = _date(now);
    final cached = _dayCache[habit] ??= {};
    if (cached.length > 4) cached.clear();
    return cached[today] ??= () {
      final out = <DateTime, RecentPeriod>{};
      for (final period in periods(habit, now)) {
        // Frozen days are kept to show as frozen; rest days and days before
        // the habit was tracked aren't
        if (!period.mark.isDue && period.mark != PeriodMark.frozen) continue;
        if (period.isOneDay) {
          out[period.start] = period;
        } else if (period.mark == PeriodMark.done || period.mark == PeriodMark.twoMinute) {
          final day = keptOn(habit, period);
          if (!day.isAfter(today)) out[day] = period;
        }
      }
      return out;
    }();
  }

  /// Overall momentum at the end of each of the last [count] months, oldest
  /// first, the last being this month so far. Habits count once they're
  /// tracked, each as much as it had formed, as for the Habits ring.
  static List<MonthMomentum> momentumByMonth(List<Habit> habits, DateTime now, {int count = 6}) {
    final times = [
      for (var i = count - 1; i >= 1; i--) DateTime(now.year, now.month - i + 1, 0, 23, 59),
      now,
    ];
    final sums = List<double>.filled(times.length, 0);
    final weights = List<double>.filled(times.length, 0);
    for (final habit in habits) {
      if (!habit.schedule.isPeriodic) continue;
      final points = _monthEnds(habit, times);
      for (var i = 0; i < times.length; i++) {
        final point = points[i];
        if (point == null) continue;
        sums[i] += point.score * point.formed;
        weights[i] += point.formed;
      }
    }
    return [
      for (var i = 0; i < times.length; i++)
        MonthMomentum(DateTime(times[i].year, times[i].month), weights[i] == 0 ? null : sums[i] / weights[i]),
    ];
  }

  /// Overall momentum at each of [times] (ascending), weighed as on the
  /// Habits ring; null where no habit was being tracked yet.
  static List<double?> overallMomentumAt(List<Habit> habits, List<DateTime> times) {
    final sums = List<double>.filled(times.length, 0);
    final weights = List<double>.filled(times.length, 0);
    for (final habit in habits) {
      if (!habit.schedule.isPeriodic) continue;
      final points = habit.momentumPoints(times);
      for (var i = 0; i < times.length; i++) {
        if (!habit.countsTowardMomentumAt(times[i])) continue;
        sums[i] += points[i].score * points[i].formed;
        weights[i] += points[i].formed;
      }
    }
    return [for (var i = 0; i < times.length; i++) weights[i] == 0 ? null : sums[i] / weights[i]];
  }

  /// A habit's momentum at each of [times] (null where it doesn't count
  /// yet), kept per habit for the day of the last one and how many months
  /// were asked for (the Insights tab asks for 6, the widgets for 2).
  static final _monthCache = Expando<Map<(DateTime, int), List<({double score, double formed})?>>>('month momentum');

  static List<({double score, double formed})?> _monthEnds(Habit habit, List<DateTime> times) {
    final cached = _monthCache[habit] ??= {};
    if (cached.length > 4) cached.clear();
    return cached[(_date(times.last), times.length)] ??= () {
      final points = habit.momentumPoints(times);
      return [for (var i = 0; i < times.length; i++) habit.countsTowardMomentumAt(times[i]) ? points[i] : null];
    }();
  }

  /// How the periods that ended between [from] and [now] went (habits being
  /// broken have no two-minute version, so they count as full or missed).
  /// With [to], only periods that began before it (date-only, exclusive).
  static KeptSummary kept(List<Habit> habits, {required DateTime from, DateTime? to, required DateTime now}) {
    final first = _date(from);
    final until = to == null ? null : _date(to);
    var full = 0, twoMinute = 0, missed = 0, saved = 0;
    for (final habit in habits) {
      // From the start, to know whether a streak was going before [from]
      final habitPeriods = periods(habit, now)
          .where((p) => p.mark.isDue && p.mark != PeriodMark.current)
          .toList();
      var streak = 0;
      PeriodMark? previous;
      var streakBeforeMiss = 0;
      final rangeStart = habit.schedule.periodStart(first);
      for (final period in habitPeriods) {
        if (until != null && !period.start.isBefore(until)) break;
        final inRange = !period.start.isBefore(rangeStart);
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
    final first = _date(from);
    final kept = List<int>.filled(8, 0);
    final due = List<int>.filled(8, 0);
    for (final habit in habits) {
      for (final period in periods(habit, now)) {
        if (period.start.isBefore(first) || !period.isOneDay) continue;
        final mark = period.mark;
        if (!mark.isDue || mark == PeriodMark.current) continue;
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
  /// at [now], oldest first. They only depend on which period [now] is in,
  /// so they're kept per period, not per moment.
  static List<RecentPeriod> periods(Habit habit, DateTime now) {
    final schedule = habit.schedule;
    if (!schedule.isPeriodic) return const [];
    final cached = _cache[habit] ??= {};
    final first = schedule.periodStart(habit.trackedFrom);
    return cached[schedule.periodStart(now)] ??= periodsBack(habit, now, (starts) => starts.last.isAfter(first));
  }

  /// The day a kept period was kept: a day's own day; for a longer period,
  /// when its running total reached the target (or the two-minute minimum),
  /// or the "2 min" button was used. A habit being broken keeps a period on
  /// its last day.
  static DateTime keptOn(Habit habit, RecentPeriod period) {
    if (period.isOneDay) return period.start;
    final end = period.end;
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
