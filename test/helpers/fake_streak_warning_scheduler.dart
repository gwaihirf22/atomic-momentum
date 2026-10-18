import 'package:atomic_momentum/core/services/streak_warning_service.dart';
import 'package:atomic_momentum/domain/services/streak_warning_planner.dart';

/// Records streak warnings instead of handing them to the OS.
class FakeStreakWarningScheduler implements StreakWarningScheduler {
  /// Every pending warning, by habit and kind.
  final Map<String, Map<StreakWarningKind, StreakWarning>> byKind = {};
  final List<String> cancelled = [];
  bool throwOnSchedule = false;

  /// The pending "don't miss twice" warning for each habit.
  Map<String, StreakWarning> get scheduled => {
        for (final entry in byKind.entries)
          if (entry.value[StreakWarningKind.secondMiss] != null)
            entry.key: entry.value[StreakWarningKind.secondMiss]!,
      };

  @override
  Future<void> schedule(String habitId, StreakWarning warning) async {
    if (throwOnSchedule) throw StateError('plugin unavailable');
    (byKind[habitId] ??= {})[warning.kind] = warning;
  }

  @override
  Future<void> cancel(String habitId) async {
    byKind.remove(habitId);
    cancelled.add(habitId);
  }

  /// Stands for the default sound: change it to make the service reschedule.
  @override
  String detailsKey = 'defaults';
}
