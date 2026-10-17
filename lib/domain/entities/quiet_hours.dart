import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show TimeOfDay;

/// A daily window when nothing should arrive (e.g. 10 PM to 7 AM; it may
/// span midnight). Reminders in it move to its end, streak warnings to just
/// before it starts (see ReminderPlanner and StreakWarningPlanner).
class QuietHours extends Equatable {
  final bool enabled;
  final TimeOfDay start;
  final TimeOfDay end;

  const QuietHours({this.enabled = false, this.start = defaultStart, this.end = defaultEnd});

  static const defaultStart = TimeOfDay(hour: 22, minute: 0);
  static const defaultEnd = TimeOfDay(hour: 7, minute: 0);
  static const off = QuietHours();

  static int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  bool get _spansMidnight => _minutes(start) > _minutes(end);

  /// Whether [at] (by the clock on the wall) falls inside the window.
  bool contains(DateTime at) {
    if (!enabled || _minutes(start) == _minutes(end)) return false;
    final m = at.hour * 60 + at.minute;
    return _spansMidnight
        ? m >= _minutes(start) || m < _minutes(end)
        : m >= _minutes(start) && m < _minutes(end);
  }

  /// When the window holding [at] ends: the next time the clock reads [end].
  DateTime endAfter(DateTime at) {
    var day = DateTime(at.year, at.month, at.day, end.hour, end.minute);
    if (!day.isAfter(at)) day = DateTime(at.year, at.month, at.day + 1, end.hour, end.minute);
    return day;
  }

  /// When the window holding [at] began: the last time the clock read
  /// [start], at or before [at].
  DateTime startBefore(DateTime at) {
    var day = DateTime(at.year, at.month, at.day, start.hour, start.minute);
    if (day.isAfter(at)) day = DateTime(at.year, at.month, at.day - 1, start.hour, start.minute);
    return day;
  }

  /// How long before the window starts a late notification moves to.
  static const _beforeStart = Duration(minutes: 15);

  /// Where a notification due at [at] goes instead, keeping it on the same
  /// day: early ones wait for the window to end, late ones come a little
  /// before it starts. Outside the window, [at] itself.
  DateTime shift(DateTime at) {
    if (!contains(at)) return at;
    final after = endAfter(at);
    if (_sameDay(after, at)) return after;
    final today = DateTime(at.year, at.month, at.day, start.hour, start.minute);
    return DateTime(today.year, today.month, today.day, today.hour, today.minute - _beforeStart.inMinutes);
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  List<Object?> get props => [enabled, _minutes(start), _minutes(end)];
}
