import 'dart:math' as math;
import '../../domain/entities/habit.dart';
import '../../domain/services/reminder_planner.dart';
import '../logging/log.dart';
import 'notification_service.dart';
import 'package:clock/clock.dart' as system_clock show clock;

/// Delivers habit reminders. Separated from [ReminderService] so tests can
/// substitute a fake for the platform notification plugin.
abstract class ReminderScheduler {
  /// Cancels every reminder scheduled earlier, including the weekly
  /// repeating ones older versions set for [habitIds].
  Future<void> cancelAll(Iterable<String> habitIds);

  Future<void> schedule(PlannedReminder reminder);
}

class LocalNotificationReminderScheduler implements ReminderScheduler {
  LocalNotificationReminderScheduler();

  // Older versions' repeating reminders only need clearing once per launch
  final _legacyCleared = <String>{};

  @override
  Future<void> cancelAll(Iterable<String> habitIds) async {
    await NotificationService.cancelPendingReminders();
    for (final id in habitIds) {
      if (_legacyCleared.add(id)) await NotificationService.cancelHabitReminder(id);
    }
  }

  @override
  Future<void> schedule(PlannedReminder reminder) {
    return NotificationService.scheduleReminder(
      id: reminderId(reminder),
      at: reminder.at,
      title: reminder.title,
      body: reminder.body,
      habitId: reminder.habitId,
    );
  }

  /// A stable id per habit and moment (FNV-1a; String.hashCode isn't
  /// guaranteed stable across runs).
  static int reminderId(PlannedReminder reminder) {
    final key = 'reminder|${reminder.habitId}|${reminder.at.toIso8601String()}';
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }
}

/// Keeps every habit's upcoming reminders scheduled: plans them all (see
/// [ReminderPlanner]), keeps the soonest [budget], and replaces whatever was
/// scheduled before. Called whenever habits or progress change, and as days
/// pass, so finished habits go quiet and the window keeps rolling.
class ReminderService {
  /// iOS keeps at most 64 pending notifications per app; this leaves room
  /// for streak warnings and the developer tester.
  static const budget = 48;

  /// iOS keeps at most this many pending notifications and silently
  /// discards the rest.
  static const iosPendingLimit = 64;

  /// Kept free under [iosPendingLimit] for the developer tester.
  static const spare = 4;

  final ReminderScheduler _scheduler;
  final DateTime Function() _clock;

  /// How many streak warnings may be pending alongside the reminders.
  final int Function(List<Habit> habits) _reservedFor;

  // One sync at a time, so a slow one can't undo a newer one. Requests that
  // arrive meanwhile collapse into one more pass with the latest habits.
  // (A flag rather than a chained Future: a Future kept across calls breaks
  // under test clocks and isn't needed.)
  bool _running = false;
  List<Habit>? _pending;

  ReminderService({
    required ReminderScheduler scheduler,
    DateTime Function()? clock,
    int Function(List<Habit> habits)? reservedFor,
  })  : _scheduler = scheduler,
        _clock = clock ?? _systemNow,
        _reservedFor = reservedFor ?? _noneReserved;

  /// How many reminders to schedule for [habits]: [budget], or less when
  /// their streak warnings need the room, so the total stays under iOS's
  /// limit and nothing is silently dropped.
  int roomFor(List<Habit> habits) =>
      math.max(0, math.min(budget, iosPendingLimit - spare - _reservedFor(habits)));

  Future<void> syncAll(Iterable<Habit> habits) async {
    _pending = habits.toList();
    if (_running) return;
    _running = true;
    try {
      while (_pending != null) {
        final next = _pending!;
        _pending = null;
        await _sync(next);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _sync(List<Habit> habits) async {
    try {
      final now = _clock();
      final planned = [for (final habit in habits) ...ReminderPlanner.plan(habit, now: now)]
        ..sort((a, b) => a.at.compareTo(b.at));

      await _scheduler.cancelAll(habits.map((h) => h.id));
      for (final reminder in planned.take(roomFor(habits))) {
        await _scheduler.schedule(reminder);
      }
    } catch (e) {
      logWarning('ReminderService: failed to sync reminders: $e');
    }
  }
}

DateTime _systemNow() => system_clock.clock.now();

int _noneReserved(List<Habit> habits) => 0;
