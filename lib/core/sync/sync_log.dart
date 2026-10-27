import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What sync did on this device, newest last: joins, what went up and came
/// down, what was brought in, what woke it, what went wrong. Kept here only
/// (never synced, kept when sync is turned off), for Settings → Momentum
/// Plus → Sync log in builds with Developer tools, so a problem between
/// devices can be traced afterwards.
class SyncLog {
  static const key = 'sync_log_v1';

  /// The most kept; older lines go first.
  static const most = 200;

  final SharedPreferences _prefs;

  SyncLog(this._prefs) {
    final raw = _prefs.getStringList(key) ?? const [];
    for (final line in raw) {
      try {
        final entry = jsonDecode(line);
        if (entry is List && entry.length == 2 && entry[0] is int && entry[1] is String) {
          _entries.add((at: DateTime.fromMillisecondsSinceEpoch(entry[0] as int), text: entry[1] as String));
        }
      } catch (_) {
        // A line this version can't read is left out
      }
    }
  }

  final List<({DateTime at, String text})> _entries = [];

  /// Every line kept, oldest first.
  List<({DateTime at, String text})> get entries => List.unmodifiable(_entries);

  /// Adds a line, stamped now, and saves.
  void add(String text) {
    _entries.add((at: clock.now(), text: text));
    if (_entries.length > most) _entries.removeRange(0, _entries.length - most);
    _prefs.setStringList(key, [for (final e in _entries) jsonEncode([e.at.millisecondsSinceEpoch, e.text])]);
  }

  /// The whole log as text (newest first), to copy.
  String get text => [for (final e in _entries.reversed) '${stampOf(e.at)}  ${e.text}'].join('\n');

  /// "Oct 26 21:05:32"
  static String stampOf(DateTime at) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    String two(int n) => n.toString().padLeft(2, '0');
    return '${months[at.month - 1]} ${at.day} ${two(at.hour)}:${two(at.minute)}:${two(at.second)}';
  }
}
