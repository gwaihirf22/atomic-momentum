import 'dart:math' as math;
import '../../domain/entities/habit.dart';
import '../../domain/entities/quiet_hours.dart';
import '../../domain/services/reminder_planner.dart';
import '../logging/log.dart';
import 'notification_service.dart';
import 'package:clock/clock.dart' as system_clock show clock;

/// Delivers habit reminders. Separated from [ReminderService] so tests can
/// substitute a fake for the platform notification plugin.
abstract class ReminderScheduler {
  /// Cancels every reminder scheduled earlier ([habitIds] are the habits
  /// being resynced).
  Future<void> cancelAll(Iterable<String> habitIds);

  Future<void> schedule(PlannedReminder reminder);

  /// Cancels one reminder scheduled earlier.
  Future<void> cancel(PlannedReminder reminder);

  /// What the scheduler adds to each reminder (the default sound), so a
  /// change to it reschedules them.
  String get detailsKey;
}

class LocalNotificationReminderScheduler implements ReminderScheduler {
  /// Settings' defaults for habits without their own sound.
  final NotifyDefaults Function() _defaults;

  LocalNotificationReminderScheduler({NotifyDefaults Function()? defaults})
      : _defaults = defaults ?? (() => NotifyDefaults.standard);

  @override
  Future<void> cancelAll(Iterable<String> habitIds) => NotificationService.cancelPendingReminders();

  @override
  Future<void> cancel(PlannedReminder reminder) => NotificationService.cancel(reminderId(reminder));

  @override
  String get detailsKey => _defaults().key;

  @override
  Future<void> schedule(PlannedReminder reminder) {
    return NotificationService.scheduleReminder(
      id: reminderId(reminder),
      at: reminder.at,
      title: reminder.title,
      body: reminder.body,
      habitId: reminder.habitId,
      details: _defaults().detailsFor(reminder.notify, canLog: reminder.canLog),
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

  /// Planning notifications now (what's asked meanwhile runs after).
  bool get isBusy => _running;
  List<Habit>? _pending;

  /// What the last sync left scheduled (null before the first), by what
  /// makes each one what it is, and the scheduler's defaults then.
  Map<String, PlannedReminder>? _scheduled;
  String? _scheduledDetails;

  static String _key(PlannedReminder r) =>
      '${r.habitId}|${r.at.toIso8601String()}|${r.title}|${r.body}|${r.notify.sound?.name}|${r.notify.timeSensitive}';

  ReminderService({
    required ReminderScheduler scheduler,
    DateTime Function()? clock,
    int Function(List<Habit> habits)? reservedFor,
    QuietHours Function()? quietHours,
  })  : _scheduler = scheduler,
        _clock = clock ?? _systemNow,
        _reservedFor = reservedFor ?? _noneReserved,
        _quietHours = quietHours ?? _noQuietHours;

  /// Settings' quiet hours: reminders move out of them.
  final QuietHours Function() _quietHours;
  static QuietHours _noQuietHours() => QuietHours.off;

  /// How many reminders to schedule for [habits]: [budget], or less when
  /// their streak warnings need the room, so the total stays under iOS's
  /// limit and nothing is silently dropped.
  int roomFor(List<Habit> habits) =>
      math.max(0, math.min(budget, iosPendingLimit - spare - _reservedFor(habits)));

  /// [replace]: cancel everything and schedule afresh (on a full reload),
  /// rather than only what changed since the last sync.
  Future<void> syncAll(Iterable<Habit> habits, {bool replace = false}) async {
    if (replace) _scheduled = null;
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
      final planned = [for (final habit in habits) ...ReminderPlanner.plan(habit, now: now, quiet: _quietHours())]
        ..sort((a, b) => a.at.compareTo(b.at));

      final chosen = planned.take(roomFor(habits)).toList();
      final details = _scheduler.detailsKey;
      final scheduled = _scheduled;
      if (scheduled == null || details != _scheduledDetails) {
        // The first time (or new defaults): replace whatever is there
        await _scheduler.cancelAll(habits.map((h) => h.id));
        for (final reminder in chosen) {
          await _scheduler.schedule(reminder);
        }
      } else {
        // Since then, only what changed: a tap or a new day moves a few
        final wanted = {for (final r in chosen) _key(r): r};
        for (final entry in scheduled.entries) {
          if (!wanted.containsKey(entry.key)) await _scheduler.cancel(entry.value);
        }
        for (final entry in wanted.entries) {
          if (!scheduled.containsKey(entry.key)) await _scheduler.schedule(entry.value);
        }
      }
      _scheduled = {for (final r in chosen) _key(r): r};
      _scheduledDetails = details;
    } catch (e) {
      // Not sure what's there now: replace it all next time
      _scheduled = null;
      logWarning('ReminderService: failed to sync reminders: $e');
    }
  }
}

DateTime _systemNow() => system_clock.clock.now();

int _noneReserved(List<Habit> habits) => 0;
