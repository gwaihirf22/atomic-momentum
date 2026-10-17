import 'package:flutter/foundation.dart';
import '../../domain/entities/habit.dart';
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
  const LocalNotificationStreakWarningScheduler();

  @override
  Future<void> schedule(String habitId, StreakWarning warning) {
    return NotificationService.scheduleStreakWarning(habitId, warning);
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
  })  : _scheduler = scheduler,
        _readSettings = readSettings,
        _clock = clock ?? _systemNow;

  Future<void> sync(Habit habit) async {
    try {
      final warnings = StreakWarningPlanner.plan(habit, _readSettings(), _clock());
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
