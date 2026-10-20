import '../../core/locale/week_start.dart';
import '../entities/habit.dart';
import '../entities/momentum.dart';
import 'achievements.dart';
import 'insights.dart';
import 'recent_periods.dart';

/// A habit that didn't miss twice during the week.
class WeekComeback {
  final Habit habit;
  final Comeback comeback;

  const WeekComeback(this.habit, this.comeback);
}

/// One of the week's wins, most notable first (the words are the screen's).
sealed class WeekWin {
  const WeekWin();
}

/// An achievement earned that week.
final class EarnedWin extends WeekWin {
  final Achievement achievement;
  const EarnedWin(this.achievement);
}

/// Every day with something due was kept.
final class PerfectWeekWin extends WeekWin {
  const PerfectWeekWin();
}

/// A habit kept every time it was due that week (twice or more).
final class KeptEveryTimeWin extends WeekWin {
  final Habit habit;
  final int times;
  const KeptEveryTimeWin(this.habit, this.times);
}

/// Overall momentum reached a new level.
final class LevelWin extends WeekWin {
  final MomentumLevel level;
  const LevelWin(this.level);
}

/// The longest streak going at the week's end.
final class StreakWin extends WeekWin {
  final Habit habit;
  final int length;
  const StreakWin(this.habit, this.length);
}

/// The week in review: how the person's week went, worked out from history
/// like everything on Insights. It's for the last evening of the week (at
/// the review time), then stays until the next one.
class WeeklyReview {
  /// The week's first day.
  final DateTime start;

  /// The week's evening is still under way (the review came on its last day).
  final bool underWay;

  /// Each of the 7 days, as on the heatmap.
  final List<DayRecord> days;

  /// How the periods in the week went.
  final KeptSummary kept;

  /// Overall momentum when the week began, and at its end (or now).
  final double? momentumBefore;
  final double? momentumAfter;

  /// Achievements earned during the week (those kept on the shelf).
  final List<Achievement> earned;

  /// Habits kept every time they were due, with how many times.
  final List<({Habit habit, int times})> keptEveryTime;

  /// The longest streak going at the week's end.
  final ({Habit habit, int length})? bestStreak;

  /// Each time a habit didn't miss twice.
  final List<WeekComeback> comebacks;

  const WeeklyReview({
    required this.start,
    required this.underWay,
    required this.days,
    required this.kept,
    required this.momentumBefore,
    required this.momentumAfter,
    required this.earned,
    required this.keptEveryTime,
    required this.bestStreak,
    required this.comebacks,
  });

  /// The week's last day.
  DateTime get end => DateTime(start.year, start.month, start.day + 6);

  int get perfectDays => days.where((d) => d.perfect).length;
  int get twoMinuteDays => days.where((d) => d.twoMinute > 0).length;

  /// Every day with something due kept, five days or more (tonight, still
  /// under way, only once it's kept).
  bool get perfectWeek {
    bool kept(DayRecord d) => d.done + d.twoMinute == d.due;
    final due = [
      for (final (i, d) in days.indexed)
        if (!d.isEmpty && !(underWay && i == days.length - 1 && !kept(d))) d,
    ];
    return due.length >= 5 && due.every(kept);
  }

  double? get momentumChange =>
      momentumBefore == null || momentumAfter == null ? null : momentumAfter! - momentumBefore!;

  /// Nothing was due all week.
  bool get quiet => kept.total == 0 && days.every((d) => d.isEmpty);

  /// The wins, most notable first, at most [max].
  List<WeekWin> wins({int max = 5}) {
    final level = momentumAfter == null ? null : MomentumLevel.of(momentumAfter!);
    final levelUp = level != null && momentumBefore != null && level.index > MomentumLevel.of(momentumBefore!).index;
    final streak = bestStreak;
    return [
      for (final a in earned) EarnedWin(a),
      if (perfectWeek) const PerfectWeekWin(),
      if (levelUp) LevelWin(level),
      for (final k in keptEveryTime) KeptEveryTimeWin(k.habit, k.times),
      if (streak != null && streak.length >= 3) StreakWin(streak.habit, streak.length),
    ].take(max).toList();
  }

  /// The review time on [day].
  static DateTime _at(DateTime day, ({int hour, int minute}) time) =>
      DateTime(day.year, day.month, day.day, time.hour, time.minute);

  /// The first day of the week whose review is the latest at [now]: this
  /// week's once its last day reaches [reviewTime], else last week's.
  static DateTime weekFor(DateTime now, {required int weekStart, required ({int hour, int minute}) reviewTime}) {
    final thisWeek = weekStartOf(now, weekStart);
    final lastDay = DateTime(thisWeek.year, thisWeek.month, thisWeek.day + 6);
    return now.isBefore(_at(lastDay, reviewTime)) ? DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7) : thisWeek;
  }

  /// How many of the week's days a habit needs to have been tracked before
  /// there's a week to review.
  static const minDays = 3;

  static ({List<Habit> habits, DateTime day, int weekStart, ({int hour, int minute}) time, WeeklyReview? review})? _last;

  /// The latest week in review at [now], or null before there's a week to
  /// look back on. Remembered for the same habits, day and settings.
  static WeeklyReview? of(
    List<Habit> habits, {
    required DateTime now,
    required int weekStart,
    required ({int hour, int minute}) reviewTime,
  }) {
    final start = weekFor(now, weekStart: weekStart, reviewTime: reviewTime);
    final last = _last;
    // The same until the next review time (or anything changes)
    final day = DateTime(now.year, now.month, now.day);
    if (last != null &&
        last.day == day &&
        last.weekStart == weekStart &&
        last.time == reviewTime &&
        (last.review?.start ?? start) == start &&
        _same(last.habits, habits)) {
      return last.review;
    }
    final review = _build(habits, now, start, weekStart);
    _last = (habits: List.of(habits), day: day, weekStart: weekStart, time: reviewTime, review: review);
    return review;
  }

  static bool _same(List<Habit> a, List<Habit> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  static WeeklyReview? _build(List<Habit> habits, DateTime now, DateTime start, int weekStart) {
    final tracked = habits.where((h) => h.schedule.isPeriodic).toList();
    final lastDay = DateTime(start.year, start.month, start.day + 6);
    final next = DateTime(start.year, start.month, start.day + 7);
    // Enough of the week tracked to say something about it
    final firstTracked = tracked.map((h) => h.trackedFrom).fold<DateTime?>(
          null,
          (a, b) => a == null || b.isBefore(a) ? b : a,
        );
    if (firstTracked == null) return null;
    final from = DateTime(firstTracked.year, firstTracked.month, firstTracked.day);
    if (from.isAfter(DateTime(lastDay.year, lastDay.month, lastDay.day - (minDays - 1)))) return null;

    final underWay = now.isBefore(next);
    final endOfWeek = underWay ? now : DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59);
    final dayBefore = DateTime(start.year, start.month, start.day - 1, 23, 59);
    final momentum = Insights.overallMomentumAt(tracked, [dayBefore, endOfWeek]);
    bool inWeek(DateTime d) => !d.isBefore(start) && d.isBefore(next);

    final keptEveryTime = <({Habit habit, int times})>[];
    ({Habit habit, int length})? best;
    final comebacks = <WeekComeback>[];
    for (final habit in tracked) {
      var due = 0, kept = 0;
      for (final period in Insights.periods(habit, now)) {
        // (A habit being broken is clean "so far" today, as on Insights)
        if (!inWeek(period.start) || !period.mark.isDue || period.mark == PeriodMark.current) continue;
        due++;
        if (period.mark == PeriodMark.done || period.mark == PeriodMark.twoMinute) kept++;
      }
      if (due >= 2 && kept == due) keptEveryTime.add((habit: habit, times: due));
      final streak = _streakAt(habit, now, next);
      if (streak > 0 && (best == null || streak > best.length)) best = (habit: habit, length: streak);
      for (final c in Achievements.comebacks(habit, now)) {
        if (inWeek(c.back)) comebacks.add(WeekComeback(habit, c));
      }
    }
    keptEveryTime.sort((a, b) => b.times.compareTo(a.times));
    comebacks.sort((a, b) => a.comeback.back.compareTo(b.comeback.back));

    return WeeklyReview(
      start: start,
      underWay: underWay,
      days: Insights.days(tracked, from: start, to: lastDay, now: now),
      kept: Insights.kept(tracked, from: start, to: next, now: now),
      momentumBefore: momentum[0],
      momentumAfter: momentum[1],
      // The most notable first, then the latest
      earned: [
        for (final a in Achievements.earned(habits, now, weekStart: weekStart))
          if (a.onShelf && inWeek(a.earnedOn)) a,
      ]..sort((a, b) => a.rank != b.rank ? a.rank.compareTo(b.rank) : b.earnedOn.compareTo(a.earnedOn)),
      keptEveryTime: keptEveryTime,
      bestStreak: best,
      comebacks: comebacks,
    );
  }

  /// [habit]'s streak as the week ended: kept periods in a row, a single
  /// miss bridged (never miss twice), up to the period under way at [now].
  static int _streakAt(Habit habit, DateTime now, DateTime weekEnd) {
    var streak = 0, beforeMiss = 0;
    var missed = false;
    for (final period in Insights.periods(habit, now)) {
      if (!period.start.isBefore(weekEnd)) break;
      final mark = period.mark;
      if (!mark.isDue || mark == PeriodMark.current) continue;
      if (habit.isBreak && period.end.isAfter(now)) continue;
      if (mark == PeriodMark.done || mark == PeriodMark.twoMinute) {
        streak = (missed ? beforeMiss : streak) + 1;
        missed = false;
      } else {
        beforeMiss = missed ? 0 : streak;
        missed = true;
        streak = 0;
      }
    }
    return missed ? beforeMiss : streak;
  }
}
