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

  /// What Health said for each linked habit and day at the last sync (in
  /// the metric's base unit, a week): the floor the app won't go below.
  static const valuesKey = 'health_values_v1';

  /// Rounding slack when converting units (well under any unit's size).
  static const _tiny = 0.001;

  final HealthSource Function() _source;
  final SharedPreferences _prefs;

  HealthSyncService({required HealthSource Function() source, required SharedPreferences prefs})
      : _source = source,
        _prefs = prefs;

  HealthSource get source => _source();

  /// Whether reading is allowed, as far as can be told: false only where
  /// the store says so (Android); null before the first sync.
  bool? accessAllowed;
  bool _accessChecked = false;

  static Set<HealthMetric> _reads(List<Habit> linked) => {for (final h in linked) h.health!.metric};
  static Set<HealthMetric> _writesFor(List<Habit> linked) =>
      {for (final h in linked) if (h.health!.logsToHealth) h.health!.metric};

  /// Asks again for what the linked [habits] need (Settings' or the habit
  /// page's "Allow").
  Future<bool> askAgain(List<Habit> habits) async {
    final linked = habits.where((h) => h.health != null && !h.isBreak).toList();
    await source.requestAccess(read: _reads(linked), write: _writesFor(linked));
    accessAllowed = await source.ensureAccess(read: _reads(linked), write: _writesFor(linked));
    return accessAllowed!;
  }

  /// Health had nothing for [habit] on any day of the last week, though it
  /// was looked at (iPhone never says whether reading was allowed, so this
  /// is the sign it wasn't).
  bool readsNothing(Habit habit) {
    final days = _readValues()[habit.id];
    if (habit.health == null || days == null || days.length < HealthMerge.window) return false;
    return days.values.every((v) => v <= _tiny);
  }

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

  Map<String, Map<String, double>>? _values;

  Map<String, Map<String, double>> _readValues() {
    if (_values != null) return _values!;
    final raw = _prefs.getString(valuesKey);
    var values = <String, Map<String, double>>{};
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          values = {
            for (final habit in decoded.entries)
              if (habit.key is String && habit.value is Map)
                habit.key as String: {
                  for (final day in (habit.value as Map).entries)
                    if (day.key is String && day.value is num) day.key as String: (day.value as num).toDouble(),
                },
          };
        }
      } catch (_) {
        // Unreadable: start again from the next sync
      }
    }
    return _values = values;
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// The least [habit] can show on [day]: what Health said for it at the
  /// last sync, less what the app wrote there itself (that, − takes back).
  /// 0 for days a sync doesn't look at (Health wouldn't raise them again).
  int floorOn(Habit habit, DateTime day) {
    final link = habit.health;
    if (link == null || habit.isBreak) return 0;
    final d = DateTime(day.year, day.month, day.day);
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    if (d.isBefore(HealthMerge.firstDay(habit, today)) || d.isAfter(today)) return 0;
    final base = _readValues()[habit.id]?[_dayKey(d)];
    if (base == null) return 0;
    var own = 0.0;
    if (link.logsToHealth) {
      for (final w in _writes()) {
        if (w.habitId == habit.id && w.day == d) own += w.amount;
      }
    }
    final rest = base - own;
    return rest <= _tiny ? 0 : link.unit.fromBase(rest);
  }

  /// What Health holds for [habitId] on [day] changed by the app's own
  /// write ([delta], base unit): the remembered number follows, so the floor
  /// is right before the next sync.
  Future<void> _adjustValue(String habitId, DateTime day, double delta) async {
    final days = _readValues()[habitId];
    final key = _dayKey(day);
    if (days == null || !days.containsKey(key)) return;
    days[key] = (days[key]! + delta).clamp(0, double.infinity).toDouble();
    await _prefs.setString(valuesKey, jsonEncode(_readValues()));
  }

  Future<void> _rememberValues(Map<String, Map<DateTime, double>> read, DateTime today) async {
    final values = _readValues();
    final weekAgo = DateTime(today.year, today.month, today.day - HealthMerge.window);
    for (final entry in read.entries) {
      final days = values[entry.key] ??= {};
      for (final day in entry.value.entries) {
        days[_dayKey(day.key)] = day.value;
      }
    }
    // Only the days a sync can still change
    for (final days in values.values) {
      days.removeWhere((key, _) => (DateTime.tryParse(key) ?? weekAgo).isBefore(weekAgo));
    }
    values.removeWhere((_, days) => days.isEmpty);
    await _prefs.setString(valuesKey, jsonEncode(values));
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
      await _adjustValue(after.id, today, deltaBase);
      return null;
    }
    var owed = -deltaBase;
    final ours = writes.where((w) => w.habitId == after.id && w.day == today).toList();
    while (owed > _tiny && ours.isNotEmpty) {
      final last = ours.removeLast();
      if (!await source.remove(last.record)) {
        // Still in Health: keep the record, to take it back next time
        await _saveWrites(writes);
        return 'Couldn\'t take that back from ${source.name}. Try again.';
      }
      writes.remove(last);
      await _adjustValue(after.id, today, -last.amount);
      if (last.amount > owed + _tiny) {
        // Took back too much: log the rest again
        final rest = await source.log(link.metric, last.amount - owed, last.record.end);
        if (rest != null) {
          writes.add(HealthWrite(habitId: after.id, day: today, amount: last.amount - owed, record: rest));
          await _adjustValue(after.id, today, last.amount - owed);
        }
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
    // Once a launch: ask about anything never asked (a new phone, a
    // reinstall); on Android, find out whether it's allowed
    if (!_accessChecked) {
      _accessChecked = true;
      accessAllowed = await source.ensureAccess(read: _reads(linked), write: _writesFor(linked));
    }
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = <String, Map<DateTime, int>>{};
    final read = <String, Map<DateTime, double>>{};
    for (final habit in linked) {
      final metric = habit.health!.metric;
      if (!metric.availableOn(isAndroid: source.isAndroid)) continue;
      final base = await source.dailyValues(metric, HealthMerge.firstDay(habit, today), today);
      read[habit.id] = {for (final e in base.entries) e.key: e.value.toDouble()};
      // Into what the habit counts in (ml into glasses, minutes into hours)
      final unit = habit.health!.unit;
      final values = {for (final e in base.entries) e.key: unit.fromBase(e.value)};
      final days = HealthMerge.daysToSet(habit, values, today);
      if (days.isNotEmpty) result[habit.id] = days;
    }
    await _rememberValues(read, today);
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
