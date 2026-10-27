import 'package:clock/clock.dart' as system_clock show clock;
import 'package:flutter/material.dart' show TimeOfDay;

import '../../domain/entities/quiet_hours.dart';
import '../../domain/services/vacation_notice_planner.dart';
import '../../domain/services/weekly_review_planner.dart';
import '../logging/log.dart';
import 'notification_service.dart';

/// Delivers the week-in-review notifications. Separate from
/// [WeeklyReviewService] so tests can substitute a fake for the platform
/// notification plugin.
abstract class WeeklyReviewScheduler {
  /// Cancels every week-in-review notification scheduled earlier.
  Future<void> cancelAll();

  Future<void> schedule(PlannedWeeklyReview review);
}

class LocalNotificationWeeklyReviewScheduler implements WeeklyReviewScheduler {
  @override
  Future<void> cancelAll() => NotificationService.cancelWeeklyReviews();

  @override
  Future<void> schedule(PlannedWeeklyReview review) => NotificationService.scheduleWeeklyReview(
        id: reviewId(review),
        at: review.at,
        title: WeeklyReviewPlanner.title,
        body: WeeklyReviewPlanner.body,
      );

  /// A stable id per moment (FNV-1a, as reminders do).
  static int reviewId(PlannedWeeklyReview review) {
    final key = 'weekly_review|${review.at.toIso8601String()}';
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }
}

/// What the week in review is planned from: when tracking began, and
/// vacation mode (a week away isn't announced).
typedef WeeklyReviewInput = ({DateTime? trackedSince, VacationPlan? vacation});

/// Keeps the week-in-review notifications scheduled (see
/// [WeeklyReviewPlanner]): planned again on launch, as days pass and when
/// its settings change. Nothing with Settings' switch off.
class WeeklyReviewService {
  final WeeklyReviewScheduler _scheduler;
  final DateTime Function() _clock;
  final bool Function() _enabled;
  final TimeOfDay Function() _time;
  final int Function() _weekStart;
  final QuietHours Function() _quietHours;

  WeeklyReviewService({
    required WeeklyReviewScheduler scheduler,
    required bool Function() enabled,
    required TimeOfDay Function() time,
    required int Function() weekStart,
    QuietHours Function()? quietHours,
    DateTime Function()? clock,
  })  : _scheduler = scheduler,
        _enabled = enabled,
        _time = time,
        _weekStart = weekStart,
        _quietHours = quietHours ?? (() => QuietHours.off),
        _clock = clock ?? (() => system_clock.clock.now());

  /// What the last sync scheduled (null before the first, or when unsure).
  List<PlannedWeeklyReview>? _scheduled;

  // One sync at a time; requests meanwhile collapse into one more pass
  // (a flag and a pending value, not a chained Future: see ReminderService)
  bool _running = false;

  /// Planning notifications now (what's asked meanwhile runs after).
  bool get isBusy => _running;
  bool _hasPending = false;
  WeeklyReviewInput? _pending;

  /// The notifications wanted right now.
  List<PlannedWeeklyReview> planFor(WeeklyReviewInput input) {
    if (!_enabled()) return const [];
    final time = _time();
    return WeeklyReviewPlanner.plan(
      now: _clock(),
      weekStart: _weekStart(),
      hour: time.hour,
      minute: time.minute,
      trackedSince: input.trackedSince,
      vacation: input.vacation,
      quiet: _quietHours(),
    );
  }

  /// [replace]: cancel and schedule afresh even if nothing seems to have
  /// changed (a full reload).
  Future<void> sync(WeeklyReviewInput input, {bool replace = false}) async {
    if (replace) _scheduled = null;
    _pending = input;
    _hasPending = true;
    if (_running) return;
    _running = true;
    try {
      while (_hasPending) {
        final next = _pending!;
        _hasPending = false;
        await _sync(next);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _sync(WeeklyReviewInput input) async {
    try {
      final wanted = planFor(input);
      final scheduled = _scheduled;
      if (scheduled != null && _same(scheduled, wanted)) return;
      await _scheduler.cancelAll();
      for (final review in wanted) {
        await _scheduler.schedule(review);
      }
      _scheduled = wanted;
    } catch (e) {
      _scheduled = null;
      logWarning('WeeklyReviewService: failed to sync: $e');
    }
  }

  static bool _same(List<PlannedWeeklyReview> a, List<PlannedWeeklyReview> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
