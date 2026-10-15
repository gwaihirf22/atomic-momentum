import 'package:equatable/equatable.dart';
import '../entities/habit.dart';
import '../entities/streak_warning_settings.dart';

/// A notification to show before a streak runs out.
class StreakWarning extends Equatable {
  final DateTime at;
  final String title;
  final String body;

  const StreakWarning({required this.at, required this.title, required this.body});

  @override
  List<Object?> get props => [at, title, body];
}

/// Decides whether and when to warn that a habit's streak is about to expire.
class StreakWarningPlanner {
  const StreakWarningPlanner._();

  /// Returns null when no warning is needed: warnings are off, there is no
  /// streak at stake, or the warning time has already passed.
  static StreakWarning? plan(Habit habit, StreakWarningSettings settings, DateTime now) {
    if (!settings.enabled) return null;

    final deadline = habit.streakDeadline(now);
    if (deadline == null) return null;

    final at = deadline.subtract(settings.leadTime);
    if (!at.isAfter(now)) return null;

    final streak = habit.streak.current;
    final streakText = '$streak-${habit.resetFrequency.periodUnit} streak';

    return StreakWarning(
      at: at,
      title: '🔥 Keep your ${habit.name} streak alive',
      // Lead times are at most a day, so the warning always lands on the
      // period's last day and the deadline is that night's midnight
      body: 'Complete "${habit.name}" before midnight tonight to keep your $streakText.',
    );
  }
}
