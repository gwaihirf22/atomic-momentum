import 'package:intl/intl.dart';

import '../../domain/entities/habit.dart';
import '../../domain/entities/momentum.dart';
import '../../domain/entities/reset_frequency.dart';
import '../../domain/services/weekly_review.dart';

/// The week in review's words, in the app's own voice (first person, a
/// quip now and then, as in the tours and the fun achievements).
abstract final class WeeklyReviewWords {
  /// "Oct 14 – 20", or "Sep 29 – Oct 5" across months.
  static String dates(WeeklyReview review) {
    final start = review.start, end = review.end;
    final first = DateFormat.MMMd().format(start);
    final last = start.month == end.month ? DateFormat.d().format(end) : DateFormat.MMMd().format(end);
    return '$first – $last';
  }

  /// "31 of 36 kept".
  static String kept(WeeklyReview review) => '${review.kept.kept} of ${review.kept.total} kept';

  static String keptShare(WeeklyReview review) =>
      review.kept.total == 0 ? '–' : '${(100 * review.kept.kept / review.kept.total).round()}%';

  /// "6 perfect days · 2 two-minute days", or null with neither.
  static String? days(WeeklyReview review) {
    final parts = [
      if (review.perfectDays > 0) '${review.perfectDays} perfect ${review.perfectDays == 1 ? 'day' : 'days'}',
      if (review.twoMinuteDays > 0)
        '${review.twoMinuteDays} two-minute ${review.twoMinuteDays == 1 ? 'day' : 'days'}',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// "72, up 4 this week".
  static String? momentum(WeeklyReview review) {
    final after = review.momentumAfter;
    if (after == null) return null;
    final change = review.momentumChange?.round();
    final level = MomentumLevel.of(after).label;
    return switch (change) {
      null || 0 => '${after.round()} · $level',
      > 0 => '${after.round()}, up $change · $level',
      _ => '${after.round()}, down ${-change} · $level',
    };
  }

  static const tonight = 'With tonight still to go.';

  /// A win's title and the line under it.
  static ({String title, String line}) win(WeekWin win) => switch (win) {
        EarnedWin(:final achievement) => (title: achievement.title, line: achievement.message),
        PerfectWeekWin() => (title: 'A perfect week', line: "Every day, every habit. I'm genuinely impressed."),
        LevelWin(:final level) => (title: '${level.label} momentum', line: 'You moved up a level this week. It shows.'),
        KeptEveryTimeWin(:final habit, :final times) => habit.isBreak
            ? (title: habit.name, line: 'Clean every day. Not one slip.')
            : (title: habit.name, line: 'Kept all $times times it was due.'),
        StreakWin(:final habit, :final length) =>
          (title: habit.name, line: '${_capital(habit.schedule.streakLabel(length))}, and counting.'),
      };

  /// What the wins card says with none to show.
  static String noWins(WeeklyReview review) => review.quiet
      ? 'A quiet week. Rest counts too.'
      : "No big wins this week, and that's okay. Showing up was the win.";

  /// "Missed Tuesday, back on Wednesday." (a day's habit), "Missed one,
  /// kept the next on Friday." (a longer one); habits being broken slip.
  static String comeback(WeekComeback c) {
    final habit = c.habit;
    final back = DateFormat.EEEE().format(c.comeback.back);
    final tiny = c.comeback.twoMinute ? ' With the two-minute version.' : '';
    if (!_dayByDay(habit)) {
      return habit.isBreak ? 'Went over once, back under by $back.' : 'Missed one, kept the next on $back.$tiny';
    }
    final missed = DateFormat.EEEE().format(c.comeback.missed);
    return habit.isBreak ? 'Slipped on $missed, clean again $back.' : 'Missed $missed, back on $back.$tiny';
  }

  /// What the comebacks card says with none to show.
  static String noComebacks(WeeklyReview review) => review.kept.missed == 0
      ? "Nothing to come back from: you didn't miss once."
      : "No comebacks this week. Next week is a fresh start, and I'll be here.";

  static bool _dayByDay(Habit habit) => habit.resetFrequency == ResetFrequency.daily && habit.schedule.interval == 1;

  static String _capital(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
