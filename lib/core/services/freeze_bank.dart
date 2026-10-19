import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What [FreezeBank.credit] did with newly earned milestones.
class FreezeCredit {
  /// Milestones that each added a freeze.
  final List<String> added;

  /// Milestones earned while the bank was full (nothing added).
  final List<String> full;

  const FreezeCredit({this.added = const [], this.full = const []});

  static const none = FreezeCredit();

  bool get isEmpty => added.isEmpty && full.isEmpty;
}

/// The person's freezes: one bank for every habit. It starts with [start],
/// holds at most [cap], and fills up from streak milestones and habits
/// formed. Spending one keeps a habit's period exactly as it was; a freeze
/// that turned out not to be needed comes back.
///
/// Also remembers, for good, the day the first freeze was spent and the day
/// the bank had stayed full for [fundDays] days (achievements read them, and
/// shouldn't vanish if the bank changes later).
class FreezeBank extends ChangeNotifier {
  static const key = 'freeze_bank_v1';
  static const start = 3;
  static const cap = 5;

  /// Days the bank has to stay full for "Rainy-day fund".
  static const fundDays = 30;

  final SharedPreferences _prefs;

  int _available = start;
  final Set<String> _credited = {};
  bool _started = false;
  DateTime? _fullSince;
  DateTime? _firstSpentOn;
  DateTime? _fundReachedOn;

  FreezeBank(this._prefs) {
    _load();
  }

  int get available => _available;
  bool get isFull => _available >= cap;
  bool get isEmpty => _available <= 0;

  /// The day the first freeze was spent, or null.
  DateTime? get firstSpentOn => _firstSpentOn;

  /// The day the bank had been full for [fundDays] days in a row, or null.
  DateTime? get fundReachedOn => _fundReachedOn;

  /// Since when the bank has been full (null while it isn't).
  DateTime? get fullSince => _fullSince;

  /// Takes a freeze out; false if there are none.
  Future<bool> spend(DateTime now) async {
    if (_available <= 0) return false;
    _available--;
    _fullSince = null;
    _firstSpentOn ??= _day(now);
    await _save();
    return true;
  }

  /// Puts [count] freezes back (no further than [cap]).
  Future<void> refund(DateTime now, [int count = 1]) async {
    if (count <= 0) return;
    _available = (_available + count).clamp(0, cap);
    _noteFull(now);
    await _save();
  }

  /// Adds a freeze for each milestone in [earned] not credited before, up to
  /// [cap]. The very first time (existing people, or a new install), what's
  /// already earned is filed quietly: everyone starts with [start].
  Future<FreezeCredit> credit(Iterable<String> earned, DateTime now) async {
    final fresh = [for (final id in earned) if (!_credited.contains(id)) id];
    if (!_started) {
      _started = true;
      _credited.addAll(fresh);
      _noteFull(now);
      await _save();
      return FreezeCredit.none;
    }
    if (fresh.isEmpty) {
      if (_noteFull(now)) await _save();
      return FreezeCredit.none;
    }
    final added = <String>[];
    final full = <String>[];
    for (final id in fresh) {
      _credited.add(id);
      if (_available < cap) {
        _available++;
        added.add(id);
      } else {
        full.add(id);
      }
    }
    _noteFull(now);
    await _save();
    return FreezeCredit(added: added, full: full);
  }

  /// Keeps [fullSince] and [fundReachedOn] up to date at [now]; true if
  /// anything changed.
  bool _noteFull(DateTime now) {
    final today = _day(now);
    var changed = false;
    if (!isFull) {
      changed = _fullSince != null;
      _fullSince = null;
      return changed;
    }
    if (_fullSince == null) {
      _fullSince = today;
      changed = true;
    }
    final since = _fullSince!;
    final reached = DateTime(since.year, since.month, since.day + fundDays);
    if (_fundReachedOn == null && !today.isBefore(reached)) {
      _fundReachedOn = reached;
      changed = true;
    }
    return changed;
  }

  /// Brings the full-bank days up to [now] (call on each look at
  /// achievements).
  Future<void> check(DateTime now) async {
    if (_noteFull(now)) await _save();
  }

  /// Reads the bank again (after something else rewrote the stored one).
  void reload() {
    _available = start;
    _credited.clear();
    _started = false;
    _fullSince = null;
    _firstSpentOn = null;
    _fundReachedOn = null;
    _load();
    notifyListeners();
  }

  void _load() {
    final raw = _prefs.getString(key);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _available = ((json['available'] as num?)?.toInt() ?? start).clamp(0, cap);
      _credited.addAll([for (final id in json['credited'] as List? ?? const []) if (id is String) id]);
      _started = json['started'] == true;
      _fullSince = _parse(json['fullSince']);
      _firstSpentOn = _parse(json['firstSpentOn']);
      _fundReachedOn = _parse(json['fundReachedOn']);
    } catch (_) {
      // Unreadable: start over with a full start, never lose more than that
    }
  }

  Future<void> _save() async {
    notifyListeners();
    await _prefs.setString(
      key,
      jsonEncode({
        'available': _available,
        'credited': _credited.toList()..sort(),
        'started': _started,
        if (_fullSince != null) 'fullSince': _dayKey(_fullSince!),
        if (_firstSpentOn != null) 'firstSpentOn': _dayKey(_firstSpentOn!),
        if (_fundReachedOn != null) 'fundReachedOn': _dayKey(_fundReachedOn!),
      }),
    );
  }

  static DateTime? _parse(Object? value) {
    final parsed = value is String ? DateTime.tryParse(value) : null;
    return parsed == null ? null : _day(parsed);
  }

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
