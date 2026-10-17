import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_goal.dart';
import '../../domain/entities/reset_frequency.dart';

/// How a habit being broken reads on cards, Calendar rows and its page.
class BreakWording {
  const BreakWording._();

  static String _slips(int n) => n == 1 ? '1 slip' : '$n slips';

  static String _period(Habit habit, {required bool current}) => switch (habit.resetFrequency) {
        ResetFrequency.weekly => current ? 'this week' : 'that week',
        ResetFrequency.monthly => current ? 'this month' : 'that month',
        _ => current ? 'today' : '',
      };

  /// "Clean today", "1 slip today", "1 of 2 drinks today", "3 of 5 this
  /// week". [current]: the period under way (else a past day, on Calendar).
  static String status(Habit habit, DateTime day, {bool current = true}) {
    final used = habit.progressForPeriodContaining(day);
    final when = _period(habit, current: current);
    final suffix = when.isEmpty ? '' : ' $when';
    if (habit.goal == HabitGoal.quit) return used == 0 ? 'Clean$suffix' : '${_slips(used)}$suffix';
    final units = habit.units.isEmpty ? '' : ' ${habit.units}';
    return '$used of ${habit.target}$units$suffix';
  }

  /// Under the habit page's number: "slips" or "of 2 drinks allowed".
  static String underNumber(Habit habit, int used) {
    if (habit.goal == HabitGoal.quit) return used == 1 ? 'slip' : 'slips';
    final units = habit.units.isEmpty ? '' : ' ${habit.units}';
    return 'of ${habit.target}$units allowed';
  }

  /// "12 days clean", "3 weeks clean".
  static String streak(Habit habit, int count) {
    final unit = habit.resetFrequency.periodUnit;
    return '$count ${count == 1 ? unit : '${unit}s'} clean';
  }
}
