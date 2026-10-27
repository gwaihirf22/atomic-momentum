import 'package:clock/clock.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/momentum.dart';
import '../../domain/services/year_review.dart';

/// The year in review's words, in the app's voice.
abstract final class YearReviewWords {
  static final _number = NumberFormat.decimalPattern();

  /// "Your 2026 so far" or "Your 2025 in review".
  static String title(YearReview review) => review.underWay && !YearReview.isReviewSeason(clock.now())
      ? 'Your ${review.year} so far'
      : 'Your ${review.year} in review';

  static String kept(YearReview review) =>
      '${_number.format(review.kept.kept)} of ${_number.format(review.kept.total)} kept';

  static String keptShare(YearReview review) => review.kept.total == 0 ? '–' : '${(100 * review.keptRate).round()}%';

  /// "210 perfect days · 14 two-minute days", or null with neither.
  static String? days(YearReview review) {
    String plural(int n, String one) => '${_number.format(n)} $one${n == 1 ? '' : 's'}';
    final parts = [
      if (review.perfectDays > 0) plural(review.perfectDays, 'perfect day'),
      if (review.twoMinuteDays > 0) plural(review.twoMinuteDays, 'two-minute day'),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// "Momentum 78, up 22 this year · Strong".
  static String? momentum(YearReview review) {
    final end = review.momentumEnd;
    if (end == null) return null;
    final level = MomentumLevel.of(end).label;
    final change = review.momentumChange?.round();
    return switch (change) {
      null || 0 => '${end.round()} · $level',
      > 0 => '${end.round()}, up $change this year · $level',
      _ => '${end.round()}, down ${-change} this year · $level',
    };
  }

  /// The year's highlights, most notable first, as (title, detail).
  static List<(String, String)> highlights(YearReview review, {bool hideName = false}) {
    String name(String n) => hideName ? 'A habit' : n;
    final best = review.bestStreak;
    final month = review.bestMonth;
    final steady = review.mostConsistent;
    return [
      if (review.formed > 0)
        (
          '${review.formed} ${review.formed == 1 ? 'habit' : 'habits'} formed',
          'Momentum past 80: ${review.formed == 1 ? 'it runs' : 'they run'} on autopilot now.',
        ),
      if (best != null && best.length >= 7)
        (
          'A ${best.habit.schedule.streakLabel(best.length)}',
          '${name(best.habit.name)}, the year\'s longest run.',
        ),
      if (steady != null)
        (
          '${name(steady.habit.name)}, ${(100 * steady.rate).round()}% of the time',
          'The habit you kept most reliably: ${steady.due} times due.',
        ),
      if (month != null)
        (
          'Best month: ${DateFormat.MMMM().format(DateTime(review.year, month.month))}',
          '${(100 * month.rate).round()}% of everything due, kept.',
        ),
      if (review.comebacks > 0)
        (
          '${_number.format(review.comebacks)} ${review.comebacks == 1 ? 'comeback' : 'comebacks'}',
          'Missed once, back the next time. Never twice.',
        ),
      if (review.earned.isNotEmpty)
        (
          '${review.earned.length} ${review.earned.length == 1 ? 'achievement' : 'achievements'}',
          'Earned this year, all on your shelf.',
        ),
    ];
  }

  static String noHighlights(YearReview review) =>
      review.kept.total == 0 ? 'A quiet year. The next one starts whenever you do.' : 'Every day you showed up counts. Keep going.';
}
