import 'package:clock/clock.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/habit.dart';
import '../../domain/services/health_days.dart';
import 'health_source.dart';

/// Reads Health for habits linked to it and works out which days to fill
/// in (HealthMerge: the higher number wins). The provider applies them.
class HealthSyncService {
  /// When this phone last synced (it's the phone's, not the habit's).
  static const lastSyncKey = 'health_last_sync_v1';

  /// Syncs closer together than this are skipped unless forced.
  static const minGap = Duration(seconds: 60);

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
      final values = await source.dailyValues(metric, HealthMerge.firstDay(habit, today), today);
      final days = HealthMerge.daysToSet(habit, values, today);
      if (days.isNotEmpty) result[habit.id] = days;
    }
    await _prefs.setInt(lastSyncKey, now.millisecondsSinceEpoch);
    return result;
  }
}
