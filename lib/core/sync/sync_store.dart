import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/sync/hlc.dart';
import '../../domain/sync/sync_records.dart';

/// What sync keeps on this device, and never syncs: whether it's on, this
/// device's id and clock, its own records, a copy of the other devices',
/// what was last synced of everything that isn't a habit, and which of its
/// buckets still have to go.
class SyncStore {
  static const onKey = 'sync_on_v1';
  static const deviceKey = 'sync_device_v1';
  static const clockKey = 'sync_clock_v1';
  static const ownKey = 'sync_own_v1';
  static const othersKey = 'sync_others_v1';
  static const baseKey = 'sync_base_v1';
  static const dirtyKey = 'sync_dirty_v1';
  static const lastKey = 'sync_last_v1';

  static const keys = [onKey, deviceKey, clockKey, ownKey, othersKey, baseKey, dirtyKey, lastKey];

  final SharedPreferences _prefs;

  SyncStore(this._prefs) {
    _load();
  }

  bool isOn = false;
  String? device;
  Hlc clock = Hlc.zero;
  Records own = {};
  Map<String, Records> others = {};
  Map<String, Object?> base = {};
  Set<String> dirty = {};
  DateTime? lastSynced;

  /// A new id for this device: random, so a copy restored from a backup
  /// onto another phone can be told apart once it notices (see SyncService).
  static String newDeviceId([Random? random]) {
    final r = random ?? Random.secure();
    return List.generate(12, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  void _load() {
    isOn = _prefs.getBool(onKey) ?? false;
    device = _prefs.getString(deviceKey);
    final stamp = _prefs.getString(clockKey);
    clock = stamp == null ? Hlc.zero : Hlc.decode(stamp);
    own = _records(_prefs.getString(ownKey));
    final others = _json(_prefs.getString(othersKey));
    this.others = {
      for (final entry in (others is Map<String, dynamic> ? others : const <String, dynamic>{}).entries)
        entry.key: _recordsFrom(entry.value),
    };
    final base = _json(_prefs.getString(baseKey));
    this.base = base is Map<String, dynamic> ? base : {};
    dirty = (_prefs.getStringList(dirtyKey) ?? const []).toSet();
    final last = _prefs.getInt(lastKey);
    lastSynced = last == null ? null : DateTime.fromMillisecondsSinceEpoch(last);
  }

  Future<void> save() async {
    await _prefs.setBool(onKey, isOn);
    if (device != null) await _prefs.setString(deviceKey, device!);
    await _prefs.setString(clockKey, clock.encode());
    await _prefs.setString(ownKey, jsonEncode(_toJson(own)));
    await _prefs.setString(othersKey, jsonEncode({for (final e in others.entries) e.key: _toJson(e.value)}));
    await _prefs.setString(baseKey, jsonEncode(base));
    await _prefs.setStringList(dirtyKey, dirty.toList()..sort());
    if (lastSynced != null) await _prefs.setInt(lastKey, lastSynced!.millisecondsSinceEpoch);
  }

  /// Forgets everything (sync turned off): turned on again, this device
  /// joins afresh with a new id.
  Future<void> clear() async {
    for (final key in keys) {
      await _prefs.remove(key);
    }
    _load();
  }

  static Map<String, Object?> _toJson(Records records) => {for (final e in records.entries) e.key: e.value.toJson()};

  static Records _records(String? raw) => _recordsFrom(_json(raw));

  static Records _recordsFrom(Object? json) {
    if (json is! Map<String, dynamic>) return {};
    final records = <String, Stamped>{};
    for (final entry in json.entries) {
      try {
        records[entry.key] = Stamped.fromJson(entry.value);
      } catch (_) {
        // A record this version can't read is left out, not fatal
      }
    }
    return records;
  }

  static Object? _json(String? raw) {
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }
}
