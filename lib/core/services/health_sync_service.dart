import 'dart:convert';
import 'package:clock/clock.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/health_link.dart';
import '../../domain/services/health_days.dart';
import 'health_source.dart';

/// Reads Health for habits linked to it and works out which days to fill
/// in (HealthMerge: the higher number wins). The provider applies them.
class HealthSyncService {
  /// When this phone last synced (it's the phone's, not the habit's).
  static const lastSyncKey = 'health_last_sync_v1';

  /// Syncs closer together than this are skipped unless forced.
  static const minGap = Duration(seconds: 60);

  /// What the app wrote to Health (the phone's own record, kept a week).
  static const writesKey = 'health_writes_v1';

  /// Rounding slack when converting units (well under any unit's size).
  static const _tiny = 0.001;

  final HealthSource Function() _source;
  final SharedPreferences _prefs;

  HealthSyncService({required HealthSource Function() source, required SharedPreferences prefs})
      : _source = source,
        _prefs = prefs;

  HealthSource get source => _source();

  DateTime? get lastSync {
    final ms = _prefs.getInt(lastSyncKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Whether a sync is due ([force]: always).
  bool isDue({bool force = false}) {
    if (force) return true;
    final last = lastSync;
    return last == null || clock.now().difference(last) >= minGap;
  }

  List<HealthWrite> _writes() {
    final raw = _prefs.getString(writesKey);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? [for (final e in decoded) if (HealthWrite.fromJson(e) case final w?) w] : [];
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveWrites(List<HealthWrite> writes) async {
    final weekAgo = clock.now().subtract(const Duration(days: 8));
    await _prefs.setString(writesKey, jsonEncode([for (final w in writes) if (w.day.isAfter(weekAgo)) w.toJson()]));
  }

  /// Mirrors a change to today's amount of a habit that logs to Health:
  /// more is written to Health; less takes back what the app wrote today,
  /// newest first. Returns a message when Health holds more than the app
  /// can take back (it came from Health itself), or null.
  Future<String?> logChange(Habit before, Habit after) async {
    final link = after.health;
    if (link == null || !link.logsToHealth) return null;
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final delta = (after.history[today] ?? 0) - (before.history[today] ?? 0);
    if (delta == 0) return null;
    final source = _source();
    final writes = _writes();
    // Health keeps exact amounts (ml, minutes); the habit's unit converts
    final deltaBase = link.unit.toBase(delta);
    if (deltaBase > 0) {
      final record = await source.log(link.metric, deltaBase, now);
      if (record == null) return 'Couldn\'t log that to ${source.name}';
      await _saveWrites([...writes, HealthWrite(habitId: after.id, day: today, amount: deltaBase, record: record)]);
      return null;
    }
    var owed = -deltaBase;
    final ours = writes.where((w) => w.habitId == after.id && w.day == today).toList();
    while (owed > _tiny && ours.isNotEmpty) {
      final last = ours.removeLast();
      writes.remove(last);
      await source.remove(last.record);
      if (last.amount > owed + _tiny) {
        // Took back too much: log the rest again
        final rest = await source.log(link.metric, last.amount - owed, last.record.end);
        if (rest != null) writes.add(HealthWrite(habitId: after.id, day: today, amount: last.amount - owed, record: rest));
        owed = 0;
      } else {
        owed -= last.amount;
      }
    }
    await _saveWrites(writes);
    return owed > _tiny ? 'That came from ${source.name}. Change it there.' : null;
  }

  /// Days to set per habit id, for the linked [habits].
  Future<Map<String, Map<DateTime, int>>> changes(List<Habit> habits) async {
    final linked = habits.where((h) => h.health != null && !h.isBreak).toList();
    if (linked.isEmpty) return const {};
    final source = _source();
    final available = await source.availability() == HealthAvailability.available;
    if (!available) return const {};
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = <String, Map<DateTime, int>>{};
    for (final habit in linked) {
      final metric = habit.health!.metric;
      if (!metric.availableOn(isAndroid: source.isAndroid)) continue;
      final base = await source.dailyValues(metric, HealthMerge.firstDay(habit, today), today);
      // Into what the habit counts in (ml into glasses, minutes into hours)
      final unit = habit.health!.unit;
      final values = {for (final e in base.entries) e.key: unit.fromBase(e.value)};
      final days = HealthMerge.daysToSet(habit, values, today);
      if (days.isNotEmpty) result[habit.id] = days;
    }
    await _prefs.setInt(lastSyncKey, now.millisecondsSinceEpoch);
    return result;
  }
}

/// What the app wrote to Health for a habit, so − can take it back.
class HealthWrite {
  final String habitId;
  final DateTime day;

  /// How much, in the metric's base unit (ml, minutes).
  final double amount;
  final HealthRecord record;

  const HealthWrite({required this.habitId, required this.day, required this.amount, required this.record});

  Map<String, dynamic> toJson() => {
        'habit': habitId,
        'day': day.millisecondsSinceEpoch,
        'amount': amount,
        'metric': record.metric.name,
        'start': record.start.millisecondsSinceEpoch,
        'end': record.end.millisecondsSinceEpoch,
      };

  static HealthWrite? fromJson(dynamic json) {
    if (json is! Map) return null;
    final metric = HealthMetric.fromName(json['metric']);
    final values = [json['day'], json['start'], json['end']];
    if (metric == null || json['habit'] is! String || values.any((v) => v is! int) || json['amount'] is! num) {
      return null;
    }
    DateTime at(Object? ms) => DateTime.fromMillisecondsSinceEpoch(ms as int);
    return HealthWrite(
      habitId: json['habit'] as String,
      day: at(json['day']),
      amount: (json['amount'] as num).toDouble(),
      record: (metric: metric, start: at(json['start']), end: at(json['end'])),
    );
  }
}
