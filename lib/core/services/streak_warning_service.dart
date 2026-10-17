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

  Future<void> sync(Habit habit) async {
    try {
      final warnings = StreakWarningPlanner.plan(habit, _readSettings(), _clock(), quiet: _quietHours());
      await _scheduler.cancel(habit.id);
      for (final warning in warnings) {
        await _scheduler.schedule(habit.id, warning);
      }
    } catch (e) {
      debugPrint('StreakWarningService: failed to sync ${habit.name}: $e');
    }
  }

  Future<void> syncAll(Iterable<Habit> habits) async {
    for (final habit in habits) {
      await sync(habit);
    }
  }

  Future<void> cancel(String habitId) async {
    try {
      await _scheduler.cancel(habitId);
    } catch (e) {
      debugPrint('StreakWarningService: failed to cancel $habitId: $e');
    }
  }
}

DateTime _systemNow() => system_clock.clock.now();
