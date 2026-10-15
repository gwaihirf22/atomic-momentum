import 'package:atomic_momentum/core/services/streak_warning_service.dart';
import 'package:atomic_momentum/domain/services/streak_warning_planner.dart';

/// Records streak warnings instead of handing them to the OS.
class FakeStreakWarningScheduler implements StreakWarningScheduler {
  final Map<String, StreakWarning> scheduled = {};
  final List<String> cancelled = [];
  bool throwOnSchedule = false;

  @override
  Future<void> schedule(String habitId, StreakWarning warning) async {
    if (throwOnSchedule) throw StateError('plugin unavailable');
    scheduled[habitId] = warning;
  }

  @override
  Future<void> cancel(String habitId) async {
    scheduled.remove(habitId);
    cancelled.add(habitId);
  }
}
