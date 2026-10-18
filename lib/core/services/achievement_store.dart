import 'package:shared_preferences/shared_preferences.dart';

/// Which achievements have been celebrated, so each is shown once.
/// Achievements themselves are worked out from history; only this is kept.
class AchievementStore {
  static const key = 'achievements_seen_v1';

  final SharedPreferences _prefs;

  AchievementStore(this._prefs);

  /// False until the first check: achievements earned before then (from
  /// history the app already had) are filed away without a celebration.
  bool get started => _prefs.containsKey(key);

  Set<String> get seen => (_prefs.getStringList(key) ?? const []).toSet();

  Future<void> markSeen(Iterable<String> ids) => _prefs.setStringList(key, {...seen, ...ids}.toList()..sort());
}
