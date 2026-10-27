import 'dart:math' as math;

import 'package:clock/clock.dart';

import '../../data/models/habit_model.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/reset_frequency.dart';
import '../../domain/entities/streak_data.dart';
import '../../domain/sync/hlc.dart';
import '../../domain/sync/sync_merge.dart';
import '../../domain/sync/sync_records.dart';

/// A habit as sync records, and back: its settings in groups that change
/// together, each day's count, and its two-minute, frozen and note marks.
class HabitRecords {
  const HabitRecords._();

  /// The settings groups, by the habit JSON keys each holds. A group is one
  /// record, so a merge never pairs a target with another device's units or
  /// mixes two schedules.
  static const groups = {
    'name': ['name'],
    'amount': ['target', 'units', 'health'],
    'schedule': ['resetFrequency', 'resetInterval', 'resetAnchor', 'scheduledWeekdays'],
    'reminders': ['reminder', 'notify'],
    'color': ['color'],
    'category': ['category'],
    'twoMinute': ['twoMinute'],
    'why': ['why'],
    'quotes': ['quotes'],
    'goal': ['goal'],
    'pauses': ['pauses'],
  };

  /// Habit JSON keys that aren't a group's: worked out, or kept per day.
  static const _notGroups = {
    'id', 'progress', 'lastUpdatedDate', 'streak', 'metadata', '_version', '_serializedAt', //
    'history', 'twoMinuteDays', 'dayNotes', 'frozen',
  };

  /// Group names for the habit's metadata: its icon, the day it counts
  /// from, and anything else kept there.
  static const icon = 'icon';
  static const start = 'start';
  static const custom = 'custom';

  /// The amount group's key for the history generation (not habit JSON).
  static const _generation = 'gen';

  /// [habit]'s settings, by group (JSON values; missing keys left out).
  static Map<String, Object?> fieldsOf(Habit habit) {
    final json = HabitModel.fromDomain(habit).toCompactJson();
    final fields = <String, Object?>{};
    final grouped = <String>{};
    for (final group in groups.entries) {
      fields[group.key] = {
        for (final key in group.value)
          if (json[key] != null) key: json[key],
      };
      grouped.addAll(group.value);
    }
    // Anything newer than this list still syncs, one record per key
    for (final entry in json.entries) {
      if (grouped.contains(entry.key) || _notGroups.contains(entry.key)) continue;
      fields['k.${entry.key}'] = entry.value;
    }
    final metadata = habit.metadata;
    fields[icon] = metadata.icon;
    fields[start] = metadata.createdDate.toIso8601String();
    fields[custom] = metadata.customFields;
    return fields;
  }

  /// The generation [habit]'s counts are kept in, from what's merged.
  static String generationOf(MergedHabit? merged) {
    final amount = merged?.fields['amount']?.value;
    return amount is Map ? amount[_generation] as String? ?? SyncKeys.firstGeneration : SyncKeys.firstGeneration;
  }

  /// The records for a change from [before] to [after] (null [before]: just
  /// made; null [after]: deleted), as [device] made it. [merged] is what's
  /// known so far from every device, this one included, for working out
  /// this device's share of a day. Settings come before days, so a day
  /// logged before the start (which also moves the start) is stamped after
  /// the start's record.
  static Records changes({
    required Habit? before,
    required Habit? after,
    required MergedHabit? merged,
    required String device,
    required Hlc Function() stamp,
  }) {
    final records = <String, Stamped>{};
    final id = (after ?? before)!.id;
    if (after == null) {
      records[SyncKeys.deleted(id)] = Stamped(true, stamp());
      return records;
    }

    var generation = generationOf(merged);
    final oldFields = before == null ? const <String, Object?>{} : fieldsOf(before);
    final newFields = fieldsOf(after);
    final scale = before == null ? null : _historyScale(before, after);
    if (scale != null) {
      // Units changed and history was rescaled: a new generation, so counts
      // still arriving in the old units are converted rather than mixed in
      final made = stamp();
      final next = made.encode();
      records[SyncKeys.generation(id, next)] = Stamped({'p': generation, 's': scale}, made);
      generation = next;
    }
    for (final entry in newFields.entries) {
      final value = entry.key == 'amount'
          ? {...entry.value as Map<String, dynamic>, _generation: generation}
          : entry.value;
      final changed = scale != null && entry.key == 'amount' ||
          !oldFields.containsKey(entry.key) ||
          !jsonEquals(oldFields[entry.key], entry.value);
      if (changed) records[SyncKeys.field(id, entry.key)] = Stamped(value, stamp());
    }
    for (final key in oldFields.keys) {
      if (!newFields.containsKey(key)) records[SyncKeys.field(id, key)] = Stamped(null, stamp());
    }

    // Days: a rescale already converts every old count, so only real
    // changes are recorded (the scaled history isn't a change)
    final linked = after.health != null;
    final oldHistory = scale == null ? (before?.history ?? const {}) : _scaled(before!.history, scale);
    for (final day in {...oldHistory.keys, ...after.history.keys}) {
      final value = after.history[day] ?? 0;
      if ((oldHistory[day] ?? 0) == value) continue;
      final key = SyncKeys.day(day);
      if (linked) {
        records[SyncKeys.dayValue(id, key)] = Stamped({'v': value, 'g': generation}, stamp());
      } else {
        final own = merged?.ownCountFor(key, generation, device, value) ?? value;
        records[SyncKeys.count(id, key, generation)] = Stamped(own, stamp());
      }
    }

    void marks(Set<DateTime> was, Set<DateTime> now, String kind) {
      for (final day in now.difference(was)) {
        records[SyncKeys.mark(id, SyncKeys.day(day), kind)] = Stamped(true, stamp());
      }
      for (final day in was.difference(now)) {
        records[SyncKeys.mark(id, SyncKeys.day(day), kind)] = Stamped(null, stamp());
      }
    }

    marks(before?.twoMinuteDays ?? const {}, after.twoMinuteDays, SyncKeys.twoMinuteMark);
    marks(before?.frozenDays ?? const {}, after.frozenDays, SyncKeys.frozenMark);
    final oldNotes = before?.dayNotes ?? const {};
    for (final day in {...oldNotes.keys, ...after.dayNotes.keys}) {
      final text = after.dayNotes[day];
      if (oldNotes[day] == text) continue;
      records[SyncKeys.mark(id, SyncKeys.day(day), SyncKeys.noteMark)] = Stamped(text, stamp());
    }
    return records;
  }

  /// How [after]'s history was scaled from [before]'s, when its units
  /// changed and every day moved together (the editor's unit change); null
  /// otherwise.
  static double? _historyScale(Habit before, Habit after) {
    if (before.units.trim() == after.units.trim() || before.history.isEmpty) return null;
    // The target usually moved by the same scale; if it was also changed,
    // the biggest day gives it
    final biggest = before.history.entries.reduce((a, b) => b.value > a.value ? b : a);
    final candidates = [
      if (before.target > 0) after.target / before.target,
      if (after.history[biggest.key] != null) after.history[biggest.key]! / biggest.value,
    ];
    for (final scale in candidates) {
      if (scale == 1) continue;
      final scaled = _scaled(before.history, scale);
      if (scaled.length == after.history.length &&
          scaled.entries.every((entry) => after.history[entry.key] == entry.value)) {
        return scale;
      }
    }
    return null;
  }

  /// [history] rescaled the way the editor does it (`Habit.updateDetails`).
  static Map<DateTime, int> _scaled(Map<DateTime, int> history, double scale) => {
        for (final e in history.entries)
          if ((e.value * scale).round() > 0) e.key: (e.value * scale).round(),
      };

  /// The habit [merged] describes, or null when it was deleted or hasn't
  /// all it needs yet. [local] is this device's copy: days of a Health-linked
  /// habit that no device has a record of (filled in from this phone's
  /// Health) are kept from it. [healthOn] is what this phone's Health shows
  /// on a day of a Health-linked habit (null: not known): such a day never
  /// shows less, and one only Health filled in shows this phone's number.
  static Habit? build(MergedHabit merged, {Habit? local, DateTime? now, int? Function(DateTime day)? healthOn}) {
    if (merged.isDeleted) return null;
    final fields = merged.fields;
    if (fields['name']?.value == null || fields['amount']?.value == null || fields['schedule']?.value == null) {
      return null;
    }
    final at = now ?? clock.now();
    final json = <String, dynamic>{
      'id': merged.id,
      'progress': 0,
      'lastUpdatedDate': at.toIso8601String(),
      'streak': StreakData.empty().toJson(),
    };
    for (final entry in fields.entries) {
      final value = entry.value.value;
      if (value == null) continue;
      if (groups.containsKey(entry.key)) {
        for (final field in (value as Map<String, dynamic>).entries) {
          if (field.key != _generation) json[field.key] = field.value;
        }
      } else if (entry.key.startsWith('k.')) {
        json[entry.key.substring(2)] = value;
      }
    }
    json['category'] ??= '';

    // The day it counts from, moved back by any day logged after it was set
    final startRecord = fields[start];
    var startDate = DateTime.tryParse(startRecord?.value as String? ?? '') ?? at;
    final generation = generationOf(merged);
    final days = merged.days.keys.toList()..sort();
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    for (final day in days) {
      final date = SyncKeys.parseDay(day);
      if (!date.isBefore(startDay)) break;
      final newest = merged.newestOn(day);
      if (newest == null || startRecord == null || !(newest > startRecord.stamp)) continue;
      final kept = merged.total(day, generation) > 0 || merged.days[day]!.mark(SyncKeys.twoMinuteMark) == true;
      if (kept) {
        startDate = date;
        break;
      }
    }
    final from = DateTime(startDate.year, startDate.month, startDate.day);

    final history = <String, int>{};
    final twoMinute = <String>[];
    final frozen = <String>[];
    final notes = <String, String>{};
    for (final day in days) {
      if (SyncKeys.parseDay(day).isBefore(from)) continue;
      final record = merged.days[day]!;
      final total = merged.total(day, generation);
      if (total > 0) history[SyncKeys.parseDay(day).toIso8601String()] = total;
      if (record.mark(SyncKeys.twoMinuteMark) == true) twoMinute.add(day);
      if (record.mark(SyncKeys.frozenMark) == true) frozen.add(day);
      final note = record.mark(SyncKeys.noteMark);
      if (note is String && note.isNotEmpty) notes[day] = note;
    }
    final linked = json['health'] != null;
    if (linked && (local != null || healthOn != null)) {
      final dates = {
        for (final day in days) SyncKeys.parseDay(day),
        for (final date in local?.history.keys ?? const <DateTime>[]) DateTime(date.year, date.month, date.day),
      };
      for (final date in dates) {
        if (date.isBefore(from)) continue;
        final record = merged.days[SyncKeys.day(date)];
        // A day logged on some device (a cleared record holds no value: its
        // number was only that device's Health)
        final recorded = record != null && (record.counts.isNotEmpty || record.value?.value != null);
        final health = healthOn?.call(date);
        final key = date.toIso8601String();
        final value = recorded
            // What was logged, never under this phone's own Health
            ? math.max(history[key] ?? 0, health ?? 0)
            // Only Health's: this phone's own, or what it had when that's unknown
            : health ?? local?.history[date] ?? 0;
        if (value > 0) {
          history[key] = value;
        } else {
          history.remove(key);
        }
      }
    }
    json['history'] = history;
    if (twoMinute.isNotEmpty) json['twoMinuteDays'] = twoMinute;
    if (frozen.isNotEmpty) json['frozen'] = frozen;
    if (notes.isNotEmpty) json['dayNotes'] = notes;
    json['metadata'] = {
      'createdDate': startDate.toIso8601String(),
      'lastModifiedDate': at.toIso8601String(),
      'version': 1,
      'icon': fields[icon]?.value,
      'customFields': fields[custom]?.value ?? const <String, dynamic>{},
    };

    final Habit habit;
    try {
      habit = HabitModel.fromJson(json).toDomain();
    } on HabitModelException {
      return null;
    }
    return clampToCap(habit).refresh(at);
  }

  /// [habit] with no period holding more than it can (two devices' taps
  /// may add up past it): each period's days in date order, trimming the
  /// day that crosses the cap. The same on every device.
  static Habit clampToCap(Habit habit) {
    final cap = habit.maxPeriodTotal;
    final days = habit.history.keys.toList()..sort();
    final totals = <DateTime, int>{};
    Map<DateTime, int>? clamped;
    for (final day in days) {
      final period = habit.resetFrequency == ResetFrequency.never ? DateTime(0) : habit.schedule.periodStart(day);
      final so = totals[period] ?? 0;
      final value = habit.history[day]!;
      final allowed = (cap - so).clamp(0, value);
      totals[period] = so + allowed;
      if (allowed != value) {
        clamped ??= Map.of(habit.history);
        if (allowed == 0) {
          clamped.remove(day);
        } else {
          clamped[day] = allowed;
        }
      }
    }
    return clamped == null ? habit : habit.copyWith(history: clamped);
  }
}
