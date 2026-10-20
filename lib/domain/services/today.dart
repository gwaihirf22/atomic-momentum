import '../entities/habit.dart';

/// What today asks of the person's habits being built, as the Habits screen
/// shows them: those due today (not frozen, not on vacation), how many are
/// done (in full, or with the two-minute version), the longest streak going
/// and a habit one miss from losing its streak.
class Today {
  final int due;
  final int done;
  final ({Habit habit, int length})? bestStreak;
  final Habit? atRisk;

  const Today({required this.due, required this.done, this.bestStreak, this.atRisk});

  /// Everything due today is done.
  bool get allDone => due > 0 && done >= due;

  static Today of(List<Habit> habits, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    var due = 0, done = 0;
    ({Habit habit, int length})? best;
    Habit? atRisk;
    for (final habit in habits) {
      if (!habit.schedule.isPeriodic || habit.isBreak) continue;
      final kept = habit.isCompleted || habit.isTwoMinuteOn(today);
      if (habit.isDueOn(today) && !habit.skipsPeriod(habit.schedule.periodStart(today))) {
        due++;
        if (kept) done++;
      }
      final streak = habit.streak;
      if (streak.current > 0 && (best == null || streak.current > best.length)) {
        best = (habit: habit, length: streak.current);
      }
      if (streak.atRisk && !kept) atRisk ??= habit;
    }
    return Today(due: due, done: done, bestStreak: best, atRisk: atRisk);
  }
}
