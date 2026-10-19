import '../entities/habit.dart';
import '../entities/momentum.dart';
import '../entities/reset_frequency.dart';
import 'recent_periods.dart';

/// One bar of a habit's trend: how much of a stretch (a week of a daily
/// habit, or one week or month of a longer habit) was kept.
class TrendBar {
  /// When the stretch began.
  final DateTime start;

  /// 0 to 1.
  final double fraction;

  /// What the bar says on top: days kept for a week of days ("5"), else
  /// nothing.
  final String label;

  const TrendBar(this.start, this.fraction, this.label);
}

/// Everything the habit page shows about how a habit is going, worked out
/// from its history at [now].
class HabitStats {
  final int streak;
  final int best;
  final Momentum momentum;

  /// Momentum at the end of today and each of the [trendDays] days before
  /// it, oldest first.
  final List<double> momentumTrend;

  /// Of the recent due periods ([recentLabel]): how many were kept, how many
  /// of those with the two-minute version, out of how many.
  final int kept;
  final int keptWithTwoMinute;
  final int due;

  /// "Last 30 days", "Last 8 weeks", "Last 6 months".
  final String recentLabel;

  /// The last 8 weeks (or months), oldest first.
  final List<TrendBar> bars;

  /// "Last 8 weeks" or "Last 8 months".
  final String barsLabel;

  /// For habits that never reset: everything logged so far.
  final int total;

  const HabitStats({
    required this.streak,
    required this.best,
    required this.momentum,
    required this.momentumTrend,
    required this.kept,
    required this.keptWithTwoMinute,
    required this.due,
    required this.recentLabel,
    required this.bars,
    required this.barsLabel,
    required this.total,
  });

  static const trendDays = 30;
  static const barCount = 8;

  /// Kept share of [due], 0 to 1 (0 with nothing due yet).
  double get keptShare => due == 0 ? 0 : kept / due;

  /// Momentum's change over the last [trendDays] days, in points.
  double get momentumChange => momentumTrend.isEmpty ? 0 : momentumTrend.last - momentumTrend.first;

  /// [weekStart] is the first day of the user's week (DateTime.monday..sunday),
  /// for the weekly bars of a daily habit.
  /// Worked out once per habit, day and week start: the habit page asks on
  /// every rebuild (a day tap, a hold).
  static final _cache = Expando<Map<(DateTime, int), HabitStats>>('habit stats');

  static HabitStats of(Habit habit, DateTime now, {int weekStart = DateTime.monday}) {
    final cached = _cache[habit] ??= {};
    if (cached.length > 4) cached.clear();
    return cached[(DateTime(now.year, now.month, now.day), weekStart)] ??= _of(habit, now, weekStart);
  }

  static HabitStats _of(Habit habit, DateTime now, int weekStart) {
    final today = DateTime(now.year, now.month, now.day);
    final total = habit.history.values.fold(0, (sum, amount) => sum + amount);
    if (!habit.resetFrequency.isPeriodic) {
      return HabitStats(
        streak: 0,
        best: 0,
        momentum: Momentum.none,
        momentumTrend: const [],
        kept: 0,
        keptWithTwoMinute: 0,
        due: 0,
        recentLabel: '',
        bars: const [],
        barsLabel: '',
        total: total,
      );
    }

    // trendDays + 1 day-ends, so the change spans exactly trendDays days
    final trend = habit.momentumSeries([
      for (var i = trendDays; i >= 0; i--) DateTime(today.year, today.month, today.day - i, 23, 59),
    ]);

    // Recent periods: 30 days, 8 weeks or 6 months. The one under way counts
    // only once it's kept (it isn't over yet).
    final daily = habit.resetFrequency == ResetFrequency.daily && habit.resetInterval == 1;
    final count = switch (habit.resetFrequency) {
      ResetFrequency.daily => habit.resetInterval == 1 ? 30 : 15,
      ResetFrequency.weekly => 8,
      _ => 6,
    };
    final recent = recentPeriods(habit, now, count: count).where((p) {
      if (!p.mark.isDue) return false;
      return p.mark != PeriodMark.current;
    }).toList();
    final kept = recent.where((p) => p.mark == PeriodMark.done || p.mark == PeriodMark.twoMinute).length;
    final unit = habit.resetFrequency == ResetFrequency.daily
        ? 'days'
        : habit.resetFrequency == ResetFrequency.weekly
            ? 'weeks'
            : 'months';
    final periodsLabel = habit.resetFrequency == ResetFrequency.daily && habit.resetInterval > 1
        ? 'Last $count periods'
        : 'Last $count $unit';

    return HabitStats(
      streak: habit.streak.current,
      best: habit.streak.longest > habit.streak.current ? habit.streak.longest : habit.streak.current,
      momentum: habit.momentum,
      momentumTrend: trend,
      kept: kept,
      keptWithTwoMinute: recent.where((p) => p.mark == PeriodMark.twoMinute).length,
      due: recent.length,
      recentLabel: periodsLabel,
      bars: daily ? _weeksOfDays(habit, today, weekStart) : _periodBars(habit, now),
      barsLabel: habit.resetFrequency == ResetFrequency.monthly ? 'Last $barCount months' : 'Last $barCount weeks',
      total: total,
    );
  }

  /// A daily habit's last 8 weeks: the share of each week's due days kept,
  /// labelled with how many.
  static List<TrendBar> _weeksOfDays(Habit habit, DateTime today, int weekStart) {
    final back = (today.weekday - weekStart + 7) % 7;
    final thisWeek = DateTime(today.year, today.month, today.day - back);
    return [
      for (var w = barCount - 1; w >= 0; w--) _weekBar(habit, DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7 * w), today),
    ];
  }

  static TrendBar _weekBar(Habit habit, DateTime start, DateTime today) {
    var due = 0;
    var kept = 0;
    for (var d = 0; d < 7; d++) {
      final day = DateTime(start.year, start.month, start.day + d);
      if (day.isAfter(today) || !habit.isDueOn(day) || habit.skipsPeriod(habit.schedule.periodStart(day))) continue;
      due++;
      if (habit.wasKeptOnDate(day)) kept++;
    }
    return TrendBar(start, due == 0 ? 0 : kept / due, '$kept');
  }

  /// A longer habit's last 8 periods, each as full as it was done.
  static List<TrendBar> _periodBars(Habit habit, DateTime now) => [
        for (final p in recentPeriods(habit, now, count: barCount))
          TrendBar(p.start, p.mark == PeriodMark.untracked ? 0 : p.fraction, ''),
      ];
}
