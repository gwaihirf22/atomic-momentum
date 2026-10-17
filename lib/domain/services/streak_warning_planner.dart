import 'package:equatable/equatable.dart';
import '../entities/habit.dart';
import '../entities/streak_warning_settings.dart';

enum StreakWarningKind {
  /// Before the second miss in a row, which would end the streak.
  secondMiss,

  /// Before a first miss, which only dents momentum (optional).
  firstMiss,
}

/// A notification to show before a streak is at stake.
class StreakWarning extends Equatable {
  final DateTime at;
  final String title;
  final String body;
  final StreakWarningKind kind;

  const StreakWarning({
    required this.at,
    required this.title,
    required this.body,
    this.kind = StreakWarningKind.secondMiss,
  });

  @override
  List<Object?> get props => [at, title, body, kind];
}

/// Decides whether and when to warn about a habit's streak.
///
/// Never miss twice: by default the only warning comes before the miss that
/// would end the streak. With [StreakWarningSettings.remindBeforeFirstMiss]
/// there's also a gentler nudge before a first miss.
class StreakWarningPlanner {
  const StreakWarningPlanner._();

  /// The warnings to schedule, soonest first; empty when warnings are off,
  /// there is no streak at stake, or the warning times have passed.
  static List<StreakWarning> plan(Habit habit, StreakWarningSettings settings, DateTime now) {
    if (!settings.enabled) return const [];

    final deadline = habit.streakDeadline(now);
    if (deadline == null) return const [];

    final name = habit.name;
    final streakText = habit.schedule.streakLabel(habit.streak.current);
    final tiny = habit.twoMinute?.description.trim() ?? '';
    // On a hard day, the tiny version still keeps the streak
    final easier = tiny.isEmpty ? '' : ' Short on time? Even 2 minutes counts: $tiny.';
    final warnings = <StreakWarning>[];

    if (settings.remindBeforeFirstMiss && !habit.streak.atRisk) {
      final at = habit.nextMissAt(now).subtract(settings.leadTime);
      if (at.isAfter(now)) {
        warnings.add(StreakWarning(
          at: at,
          kind: StreakWarningKind.firstMiss,
          title: 'Keep $name going',
          body: 'Complete "$name" before midnight tonight to keep your momentum.$easier',
        ));
      }
    }

    final at = deadline.subtract(settings.leadTime);
    if (at.isAfter(now)) {
      warnings.add(StreakWarning(
        at: at,
        title: "Don't miss twice: $name",
        // Lead times are at most a day, so the warning always lands on the
        // period's last day and the deadline is that night's midnight
        body: 'Complete "$name" before midnight tonight to keep your $streakText.$easier',
      ));
    }
    return warnings;
  }
}
