import '../entities/habit.dart';
import 'achievements.dart';
import 'insights.dart';
import 'recent_periods.dart';

/// A habit's best stretch in the year: kept periods in a row, one miss
/// bridged (never miss twice).
typedef YearStreak = ({Habit habit, int length});

/// The year in review (Momentum Plus): how a calendar year went, worked out
/// from history like the week in review, for the year so far or a finished
/// one. On Insights from a week of tracking; "in review" from December 26
/// and through January.
class YearReview {
  final int year;

  /// The year isn't over (a "so far" review).
  final bool underWay;

  /// Each day from January 1 (or the first tracked day) to the year's end
  /// or today, as on the heatmap.
  final List<DayRecord> days;

  /// How the year's periods went.
  final KeptSummary kept;

  /// Overall momentum as the year began (null before tracking) and at its
  /// end (or now).
  final double? momentumStart;
  final double? momentumEnd;

  /// Achievements earned in the year (those kept on the shelf), most
  /// notable first.
  final List<Achievement> earned;

  /// The longest streak reached in the year.
  final YearStreak? bestStreak;

  /// The month with the most periods kept (of those due), 1 to 12, with its
  /// share kept.
  final ({int month, double rate})? bestMonth;

  /// The habit kept most reliably (at least [minDue] times due), with its
  /// share kept and how many times it was due.
  final ({Habit habit, double rate, int due})? mostConsistent;

  /// Times a habit didn't miss twice.
  final int comebacks;

  const YearReview({
    required this.year,
    required this.underWay,
    required this.days,
    required this.kept,
    required this.momentumStart,
    required this.momentumEnd,
    required this.earned,
    required this.bestStreak,
    required this.bestMonth,
    required this.mostConsistent,
    required this.comebacks,
  });

  /// Days tracked before there's a year to look back on.
  static const minDays = 7;

  /// Times a habit must have been due to be "most consistent".
  static const minDue = 8;

  /// A month needs this many periods due to be the best month.
  static const minMonthDue = 10;

  int get perfectDays => days.where((d) => d.perfect).length;
  int get twoMinuteDays => days.where((d) => d.twoMinute > 0).length;

  /// Habits formed in the year (momentum reached 80).
  int get formed => earned.where((a) => a.kind == AchievementKind.formed).length;

  /// Share of periods kept, 0 to 1.
  double get keptRate => kept.total == 0 ? 0 : kept.kept / kept.total;

  double? get momentumChange =>
      momentumStart == null || momentumEnd == null ? null : momentumEnd! - momentumStart!;

  /// The year to show at [now]: last year through January (its review, in
  /// full), otherwise this one (so far, "in review" from December 26).
  static int yearFor(DateTime now) => now.month == 1 ? now.year - 1 : now.year;

  /// Whether the review for [now] is the full one ("in review") rather than
  /// "so far".
  static bool isReviewSeason(DateTime now) => now.month == 1 || (now.month == 12 && now.day >= 26);

  static ({List<Habit> habits, int year, DateTime day, int weekStart, YearReview? review})? _last;

  /// The review of [year] at [now], or null with under a week tracked in it.
  /// Remembered for the same habits, year, day and week start.
  static YearReview? of(List<Habit> habits, {required int year, required DateTime now, required int weekStart}) {
    final day = DateTime(now.year, now.month, now.day);
    final last = _last;
    if (last != null && last.year == year && last.day == day && last.weekStart == weekStart && _same(last.habits, habits)) {
      return last.review;
    }
    final review = _build(habits, year, now, weekStart);
    _last = (habits: List.of(habits), year: year, day: day, weekStart: weekStart, review: review);
    return review;
  }

  static bool _same(List<Habit> a, List<Habit> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  static YearReview? _build(List<Habit> habits, int year, DateTime now, int weekStart) {
    final tracked = habits.where((h) => h.schedule.isPeriodic).toList();
    final jan1 = DateTime(year);
    final next = DateTime(year + 1);
    final today = DateTime(now.year, now.month, now.day);
    if (!today.isAfter(jan1) && today != jan1) return null;
    final lastDay = today.isBefore(next) ? today : DateTime(year, 12, 31);

    final firstTracked = tracked.map((h) => h.trackedFrom).fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
    if (firstTracked == null) return null;
    final from = firstTracked.isAfter(jan1) ? DateTime(firstTracked.year, firstTracked.month, firstTracked.day) : jan1;
    if (from.isAfter(lastDay) || lastDay.difference(from).inDays + 1 < minDays) return null;

    bool inYear(DateTime d) => !d.isBefore(jan1) && d.isBefore(next);
    final underWay = now.isBefore(next);
    final end = underWay ? now : DateTime(year, 12, 31, 23, 59);
    final momentum = Insights.overallMomentumAt(tracked, [DateTime(year - 1, 12, 31, 23, 59), end]);

    final monthDue = List<int>.filled(13, 0);
    final monthKept = List<int>.filled(13, 0);
    YearStreak? best;
    ({Habit habit, double rate, int due})? steadiest;
    var comebacks = 0;
    for (final habit in tracked) {
      var due = 0, keptCount = 0;
      var streak = 0, beforeMiss = 0, longest = 0;
      var missed = false;
      for (final period in Insights.periods(habit, now)) {
        if (!period.start.isBefore(next)) break;
        final mark = period.mark;
        if (!mark.isDue || mark == PeriodMark.current) continue;
        if (habit.isBreak && period.end.isAfter(now)) continue;
        final kept = mark == PeriodMark.done || mark == PeriodMark.twoMinute;
        // The streak walks the habit's whole history, so one running into
        // the year counts from where it began
        if (kept) {
          streak = (missed ? beforeMiss : streak) + 1;
          missed = false;
        } else {
          beforeMiss = missed ? 0 : streak;
          missed = true;
          streak = 0;
        }
        if (!inYear(period.start)) continue;
        final running = missed ? beforeMiss : streak;
        if (running > longest) longest = running;
        due++;
        monthDue[period.start.month]++;
        if (kept) {
          keptCount++;
          monthKept[period.start.month]++;
        }
      }
      if (longest > 0 && (best == null || longest > best.length)) best = (habit: habit, length: longest);
      if (due >= minDue) {
        final rate = keptCount / due;
        if (steadiest == null || rate > steadiest.rate || (rate == steadiest.rate && due > steadiest.due)) {
          steadiest = (habit: habit, rate: rate, due: due);
        }
      }
      for (final c in Achievements.comebacks(habit, now)) {
        if (inYear(c.back)) comebacks++;
      }
    }

    ({int month, double rate})? bestMonth;
    for (var m = 1; m <= 12; m++) {
      if (monthDue[m] < minMonthDue) continue;
      final rate = monthKept[m] / monthDue[m];
      if (bestMonth == null || rate > bestMonth.rate) bestMonth = (month: m, rate: rate);
    }

    return YearReview(
      year: year,
      underWay: underWay,
      days: Insights.days(tracked, from: from, to: lastDay, now: now),
      kept: Insights.kept(tracked, from: from, to: next, now: now),
      momentumStart: momentum[0],
      momentumEnd: momentum[1],
      earned: [
        for (final a in Achievements.earned(habits, now, weekStart: weekStart))
          if (a.onShelf && inYear(a.earnedOn)) a,
      ]..sort((a, b) => a.rank != b.rank ? a.rank.compareTo(b.rank) : b.earnedOn.compareTo(a.earnedOn)),
      bestStreak: best,
      bestMonth: bestMonth,
      mostConsistent: steadiest,
      comebacks: comebacks,
    );
  }
}
