import 'package:atomic_momentum/core/services/reminder_service.dart';
import 'package:atomic_momentum/domain/services/reminder_planner.dart';

/// Records reminders instead of handing them to the OS.
class FakeReminderScheduler implements ReminderScheduler {
  final List<PlannedReminder> scheduled = [];
  int cancelCount = 0;
  final Set<String> cancelledHabitIds = {};

  @override
  Future<void> cancelAll(Iterable<String> habitIds) async {
    scheduled.clear();
    cancelCount++;
    cancelledHabitIds.addAll(habitIds);
  }

  @override
  Future<void> schedule(PlannedReminder reminder) async => scheduled.add(reminder);

  List<PlannedReminder> forHabit(String id) => scheduled.where((r) => r.habitId == id).toList();
}
