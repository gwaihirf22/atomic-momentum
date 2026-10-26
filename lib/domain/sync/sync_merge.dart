import 'dart:math' as math;

import 'hlc.dart';
import 'sync_records.dart';

/// Every device's records combined: the same answer on every device,
/// whatever order the records arrived in, however often.
class SyncMerge {
  const SyncMerge._();

  /// Combines [replicas], each device's records by device id.
  static MergedState merge(Map<String, Records> replicas) {
    final state = MergedState._();
    // Devices in a fixed order, so ties in "union" and "earliest" settle the
    // same way everywhere (stamps never tie across devices)
    final devices = replicas.keys.toList()..sort();
    for (final device in devices) {
      state.add(device, replicas[device]!);
    }
    return state;
  }
}

Stamped? _later(Stamped? a, Stamped b) => a == null || b.stamp > a.stamp ? b : a;
Stamped? _earlierStamp(Stamped? a, Stamped b) => a == null || b.stamp < a.stamp ? b : a;

/// The merged records.
class MergedState {
  MergedState._();

  /// Each habit's records, by id.
  final Map<String, MergedHabit> habits = {};

  /// Everything else that takes the latest or the earliest, by key.
  final Map<String, Stamped> values = {};

  /// Sets that only grow, by set name: their members, each with the first
  /// value set for it.
  final Map<String, Map<String, Stamped>> sets = {};

  /// Takes in more of [device]'s records (this device's latest changes),
  /// without merging everything again.
  void add(String device, Records records) {
    for (final entry in records.entries) {
      _add(device, entry.key, entry.value);
    }
  }

  void _add(String device, String key, Stamped record) {
    final habitId = SyncKeys.habitOf(key);
    if (habitId != null) {
      (habits[habitId] ??= MergedHabit._(habitId))._add(device, key, record);
      return;
    }
    switch (SyncKeys.ruleOf(key)) {
      case MergeRule.union:
        // e/<set>/<item>
        final slash = key.indexOf('/', 2);
        if (slash < 0) return;
        final members = sets[key.substring(2, slash)] ??= {};
        final item = key.substring(slash + 1);
        members[item] = _earlierStamp(members[item], record)!;
      case MergeRule.earliest:
        final current = values[key];
        values[key] = current == null || _compareValues(record.value, current.value) < 0 ||
                (_compareValues(record.value, current.value) == 0 && record.stamp < current.stamp)
            ? record
            : current;
      case MergeRule.latest || MergeRule.sum:
        values[key] = _later(values[key], record)!;
    }
  }

  /// The latest or earliest value under [key], or null.
  Object? valueOf(String key) => values[key]?.value;

  /// The members of [set].
  Set<String> members(String set) => sets[set]?.keys.toSet() ?? const {};
}

int _compareValues(Object? a, Object? b) {
  if (a == null) return b == null ? 0 : 1;
  if (b == null) return -1;
  if (a is num && b is num) return a.compareTo(b);
  return a.toString().compareTo(b.toString());
}

/// One habit's merged records.
class MergedHabit {
  final String id;

  MergedHabit._(this.id);

  /// Its settings, by group.
  final Map<String, Stamped> fields = {};

  /// Set once it's been deleted on any device.
  Stamped? deleted;

  /// Its days, by `yyyy-MM-dd`.
  final Map<String, MergedDay> days = {};

  /// Its history generations (units changed), by id.
  final Map<String, Stamped> generations = {};

  void _add(String device, String key, Stamped record) {
    final parts = key.split('/');
    switch (parts[0]) {
      case 'h':
        if (parts.length >= 3) fields[parts[2]] = _later(fields[parts[2]], record)!;
      case 'x':
        deleted = _earlierStamp(deleted, record);
      case 'd':
        if (parts.length >= 4) {
          final day = days[parts[2]] ??= MergedDay._();
          final counts = day.counts[parts[3]] ??= {};
          counts[device] = _later(counts[device], record)!;
        }
      case 'r':
        if (parts.length >= 3) {
          final day = days[parts[2]] ??= MergedDay._();
          day.value = _later(day.value, record);
        }
      case 'm':
        if (parts.length >= 4) {
          final day = days[parts[2]] ??= MergedDay._();
          day.marks[parts[3]] = _later(day.marks[parts[3]], record)!;
        }
      case 'g':
        if (parts.length >= 3) generations[parts[2]] = _earlierStamp(generations[parts[2]], record)!;
    }
  }

  bool get isDeleted => deleted != null;

  /// How many of [generation]'s units make one of the first generation's:
  /// each change of units multiplies by its scale.
  double factorOf(String generation) {
    var factor = 1.0;
    var current = generation;
    final seen = <String>{};
    while (current != SyncKeys.firstGeneration && seen.add(current)) {
      final record = generations[current]?.value;
      if (record is! Map) break;
      factor *= (record['s'] as num?)?.toDouble() ?? 1;
      current = record['p'] as String? ?? SyncKeys.firstGeneration;
    }
    return factor;
  }

  /// [day]'s count in [generation]'s units: the devices' counts added up,
  /// unless a whole-day value (Health-linked habits) was set after them.
  int total(String day, String generation) {
    final record = days[day];
    if (record == null) return 0;
    final target = factorOf(generation);
    final counts = record._countSum(this, target);
    final value = record.value;
    if (value != null && (counts.newest == null || value.stamp > counts.newest!)) {
      final map = value.value;
      if (map is! Map) return 0;
      final v = (map['v'] as num?)?.toDouble() ?? 0;
      final g = map['g'] as String? ?? SyncKeys.firstGeneration;
      return math.max(0, (v * target / factorOf(g)).round());
    }
    return math.max(0, counts.sum.round());
  }

  /// What [device]'s own count in [generation] should be for [day] to hold
  /// [total] (the others' counts stay as they are).
  int ownCountFor(String day, String generation, String device, int total) {
    final record = days[day];
    if (record == null) return total;
    final target = factorOf(generation);
    var others = 0.0;
    for (final entry in record.counts.entries) {
      final factor = target / factorOf(entry.key);
      for (final count in entry.value.entries) {
        if (entry.key == generation && count.key == device) continue;
        others += ((count.value.value as num?) ?? 0) * factor;
      }
    }
    return total - others.round();
  }

  /// The latest stamp of anything set on [day].
  Hlc? newestOn(String day) {
    final record = days[day];
    if (record == null) return null;
    Hlc? newest;
    void consider(Hlc stamp) {
      if (newest == null || stamp > newest!) newest = stamp;
    }

    for (final counts in record.counts.values) {
      for (final count in counts.values) {
        consider(count.stamp);
      }
    }
    if (record.value != null) consider(record.value!.stamp);
    for (final mark in record.marks.values) {
      consider(mark.stamp);
    }
    return newest;
  }
}

/// One day of a habit's merged records.
class MergedDay {
  MergedDay._();

  /// Each device's count, by generation and then device.
  final Map<String, Map<String, Stamped>> counts = {};

  /// The whole day's count, for habits filled in from Health.
  Stamped? value;

  /// Its two-minute, frozen and note marks.
  final Map<String, Stamped> marks = {};

  /// A mark's value, or null when unset.
  Object? mark(String kind) => marks[kind]?.value;

  ({double sum, Hlc? newest}) _countSum(MergedHabit habit, double target) {
    var sum = 0.0;
    Hlc? newest;
    for (final entry in counts.entries) {
      final factor = target / habit.factorOf(entry.key);
      for (final count in entry.value.values) {
        sum += ((count.value as num?) ?? 0) * factor;
        if (newest == null || count.stamp > newest) newest = count.stamp;
      }
    }
    return (sum: sum, newest: newest);
  }
}
