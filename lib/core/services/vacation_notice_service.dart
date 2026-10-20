import 'package:clock/clock.dart' as system_clock show clock;
import 'package:flutter/material.dart' show TimeOfDay;

import '../../domain/entities/quiet_hours.dart';
import '../../domain/services/vacation_notice_planner.dart';
import '../logging/log.dart';
import 'notification_service.dart';

/// Delivers vacation notices. Separate from [VacationNoticeService] so tests
/// can substitute a fake for the platform notification plugin.
abstract class VacationNoticeScheduler {
  /// Cancels every vacation notice scheduled earlier.
  Future<void> cancelAll();

  Future<void> schedule(PlannedVacationNotice notice);
}

class LocalNotificationVacationNoticeScheduler implements VacationNoticeScheduler {
  @override
  Future<void> cancelAll() => NotificationService.cancelVacationNotices();

  @override
  Future<void> schedule(PlannedVacationNotice notice) => NotificationService.scheduleVacationNotice(
        id: noticeId(notice),
        at: notice.at,
        title: notice.title,
        body: notice.body,
        canEnd: notice.kind == VacationNoticeKind.checkIn,
      );

  /// A stable id per moment (FNV-1a, as reminders do).
  static int noticeId(PlannedVacationNotice notice) {
    final key = 'vacation|${notice.kind.name}|${notice.at.toIso8601String()}';
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }
}

/// Keeps vacation mode's notifications scheduled (see
/// [VacationNoticePlanner]): replaced whenever vacation mode changes, and
/// planned again as days pass so the check-ins keep rolling. Nothing while
/// vacation mode is off, or with Settings' switch off.
class VacationNoticeService {
  final VacationNoticeScheduler _scheduler;
  final DateTime Function() _clock;
  final bool Function() _enabled;
  final TimeOfDay Function() _time;
  final QuietHours Function() _quietHours;

  VacationNoticeService({
    required VacationNoticeScheduler scheduler,
    required bool Function() enabled,
    required TimeOfDay Function() time,
    QuietHours Function()? quietHours,
    DateTime Function()? clock,
  })  : _scheduler = scheduler,
        _enabled = enabled,
        _time = time,
        _quietHours = quietHours ?? (() => QuietHours.off),
        _clock = clock ?? (() => system_clock.clock.now());

  /// What the last sync scheduled (null before the first, or when unsure).
  List<PlannedVacationNotice>? _scheduled;

  // One sync at a time; requests meanwhile collapse into one more pass
  // (a flag and a pending value, not a chained Future: see ReminderService)
  bool _running = false;
  bool _hasPending = false;
  VacationPlan? _pending;

  /// The notices for [vacation] (null: vacation mode is off) right now.
  List<PlannedVacationNotice> planFor(VacationPlan? vacation) {
    if (vacation == null || !_enabled()) return const [];
    final time = _time();
    return VacationNoticePlanner.plan(vacation,
        now: _clock(), hour: time.hour, minute: time.minute, quiet: _quietHours());
  }

  /// [replace]: cancel and schedule afresh even if nothing seems to have
  /// changed (a full reload).
  Future<void> sync(VacationPlan? vacation, {bool replace = false}) async {
    if (replace) _scheduled = null;
    _pending = vacation;
    _hasPending = true;
    if (_running) return;
    _running = true;
    try {
      while (_hasPending) {
        final next = _pending;
        _hasPending = false;
        await _sync(next);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _sync(VacationPlan? vacation) async {
    try {
      final wanted = planFor(vacation);
      final scheduled = _scheduled;
      if (scheduled != null && _same(scheduled, wanted)) return;
      await _scheduler.cancelAll();
      for (final notice in wanted) {
        await _scheduler.schedule(notice);
      }
      _scheduled = wanted;
    } catch (e) {
      _scheduled = null;
      logWarning('VacationNoticeService: failed to sync: $e');
    }
  }

  static bool _same(List<PlannedVacationNotice> a, List<PlannedVacationNotice> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
