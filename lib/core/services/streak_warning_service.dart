import 'package:flutter/foundation.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/quiet_hours.dart';
import '../../domain/entities/streak_warning_settings.dart';
import '../../domain/services/streak_warning_planner.dart';
import 'notification_service.dart';
import 'package:clock/clock.dart' as system_clock show clock;

/// Delivers streak warnings. Separated from [StreakWarningService] so tests
/// can substitute a fake for the platform notification plugin.
abstract class StreakWarningScheduler {
  Future<void> schedule(String habitId, StreakWarning warning);

  /// Cancels every kind of warning for the habit.
  Future<void> cancel(String habitId);

  /// What the scheduler adds to each warning (the default sound), so a
  /// change to it reschedules them.
  String get detailsKey;
}

class LocalNotificationStreakWarningScheduler implements StreakWarningScheduler {
  /// Settings' defaults for habits without their own sound.
  final NotifyDefaults Function() _defaults;

  LocalNotificationStreakWarningScheduler({NotifyDefaults Function()? defaults})
      : _defaults = defaults ?? (() => NotifyDefaults.standard);

  @override
  Future<void> schedule(String habitId, StreakWarning warning) {
    return NotificationService.scheduleStreakWarning(habitId, warning, details: _defaults().detailsFor(warning.notify));
  }

  @override
  Future<void> cancel(String habitId) {
    return NotificationService.cancelStreakWarning(habitId);
  }

  @override
  String get detailsKey => _defaults().key;
}

/// Keeps each habit's pending streak warnings (at most one of each
/// [StreakWarningKind]) in line with its current state and the user's settings.
class StreakWarningService {
  final StreakWarningScheduler _scheduler;
  final StreakWarningSettings Function() _readSettings;
  final DateTime Function() _clock;

  StreakWarningService({
    required StreakWarningScheduler scheduler,
    required StreakWarningSettings Function() readSettings,
    DateTime Function()? clock,
    QuietHours Function()? quietHours,
  })  : _scheduler = scheduler,
        _readSettings = readSettings,
        _clock = clock ?? _systemNow,
        _quietHours = quietHours ?? (() => QuietHours.off);

  /// Settings' quiet hours: warnings move to just before them.
  final QuietHours Function() _quietHours;

  /// What each habit's last sync scheduled, so a sync that would schedule
  /// the same again does nothing (every launch, tap and midnight syncs).
  final Map<String, String> _scheduled = {};

  Future<void> sync(Habit habit) async {
    try {
      final warnings = StreakWarningPlanner.plan(habit, _readSettings(), _clock(), quiet: _quietHours());
      final key = [
        _scheduler.detailsKey,
        for (final w in warnings) '${w.kind.name}|${w.at.toIso8601String()}|${w.title}|${w.body}|${w.notify.sound?.name}|${w.notify.timeSensitive}',
      ].join('\n');
      if (_scheduled[habit.id] == key) return;
      _scheduled.remove(habit.id);
      await _scheduler.cancel(habit.id);
      for (final warning in warnings) {
        await _scheduler.schedule(habit.id, warning);
      }
      _scheduled[habit.id] = key;
    } catch (e) {
      debugPrint('StreakWarningService: failed to sync ${habit.name}: $e');
    }
  }

  /// [replace]: cancel and schedule every habit's warnings afresh (on a
  /// full reload), not only the ones that changed.
  Future<void> syncAll(Iterable<Habit> habits, {bool replace = false}) async {
    if (replace) _scheduled.clear();
    for (final habit in habits) {
      await sync(habit);
    }
  }

  Future<void> cancel(String habitId) async {
    _scheduled.remove(habitId);
    try {
      await _scheduler.cancel(habitId);
    } catch (e) {
      debugPrint('StreakWarningService: failed to cancel $habitId: $e');
    }
  }
}

DateTime _systemNow() => system_clock.clock.now();
