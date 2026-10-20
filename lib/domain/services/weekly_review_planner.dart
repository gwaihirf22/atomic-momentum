import 'package:equatable/equatable.dart';

import '../../core/locale/week_start.dart';
import '../entities/quiet_hours.dart';
import 'vacation_notice_planner.dart';
import 'weekly_review.dart';

/// One "your week in review" notification to deliver.
class PlannedWeeklyReview extends Equatable {
  final DateTime at;

  const PlannedWeeklyReview(this.at);

  @override
  List<Object?> get props => [at];

  @override
  String toString() => 'PlannedWeeklyReview(at $at)';
}

/// When the week in review is announced: on the last day of each of the
/// person's weeks, at Settings' review time (moved out of quiet hours), the
/// next few ahead. None for a week with too little tracked to review, or
/// spent on vacation.
class WeeklyReviewPlanner {
  const WeeklyReviewPlanner._();

  /// At most this many are pending at once; opening the app plans again.
  static const maxPending = 2;

  static const title = 'Your week in review';
  static const body = 'Wins, comebacks and how it went. Come take a look.';

  /// [trackedSince]: when the first habit began being tracked (null: none).
  static List<PlannedWeeklyReview> plan({
    required DateTime now,
    required int weekStart,
    required int hour,
    required int minute,
    required DateTime? trackedSince,
    VacationPlan? vacation,
    QuietHours quiet = QuietHours.off,
  }) {
    if (trackedSince == null) return const [];
    final since = DateTime(trackedSince.year, trackedSince.month, trackedSince.day);
    final first = weekStartOf(now, weekStart);
    final planned = <PlannedWeeklyReview>[];
    for (var week = 0; planned.length < maxPending && week <= maxPending; week++) {
      final last = DateTime(first.year, first.month, first.day + 6 + 7 * week);
      final at = quiet.shift(DateTime(last.year, last.month, last.day, hour, minute));
      if (!at.isAfter(now)) continue;
      // A week the review would have nothing on
      if (since.isAfter(DateTime(last.year, last.month, last.day - (WeeklyReview.minDays - 1)))) continue;
      if (vacation != null && _away(vacation, last)) continue;
      planned.add(PlannedWeeklyReview(at));
    }
    return planned;
  }

  /// On vacation on [day] (from its start until the return day).
  static bool _away(VacationPlan vacation, DateTime day) =>
      !day.isBefore(vacation.since) && (vacation.back == null || day.isBefore(vacation.back!));
}
