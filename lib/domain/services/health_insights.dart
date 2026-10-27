import '../entities/habit.dart';
import '../entities/health_link.dart';
import '../entities/reset_frequency.dart';
import 'insights.dart';

/// One thing Health shows about the rest of a person's habits: on days a
/// "driver" (sleep, steps, exercise) is at or past [line], [rateAbove] of
/// the other habits due were kept; on other days, [rateBelow].
class HealthFinding {
  /// The habit filled in from Health that drives it.
  final Habit driver;
  final HealthMetric metric;

  /// The line, in the driver's own units (7 hours; its step target).
  final int line;

  final double rateAbove;
  final double rateBelow;
  final int daysAbove;
  final int daysBelow;

  const HealthFinding({
    required this.driver,
    required this.metric,
    required this.line,
    required this.rateAbove,
    required this.rateBelow,
    required this.daysAbove,
    required this.daysBelow,
  });

  /// How far apart the two sides are, 0 to 1.
  double get gap => (rateAbove - rateBelow).abs();
}

/// Health insights (Momentum Plus), worked out on the phone from habits
/// already filled in from Health: a sleep-linked habit's day is the hours
/// slept, a steps-linked one the steps, an exercise-linked one the minutes.
/// Nothing new is read from Health, and nothing leaves the phone.
class HealthInsights {
  const HealthInsights._();

  /// Days needed on each side of the line before saying anything.
  static const minDays = 14;

  /// The least difference worth a word (10 points).
  static const minGap = 0.10;

  /// How far back it looks.
  static const lookback = 180;

  /// The metrics that drive a finding, and how a day's line is drawn.
  static const drivers = {HealthMetric.sleepHours, HealthMetric.steps, HealthMetric.exerciseMinutes};

  /// Sleep's line: 7 hours, in base minutes.
  static const sleepLineMinutes = 420;

  /// Habits that could drive a finding: filled in from sleep, steps or
  /// exercise, kept daily, and being built.
  static List<Habit> driversIn(List<Habit> habits) => [
        for (final h in habits)
          if (h.health != null &&
              drivers.contains(h.health!.metric) &&
              !h.isBreak &&
              h.resetFrequency == ResetFrequency.daily &&
              h.resetInterval == 1)
            h,
      ];

  /// The line for [driver], in its own units.
  static int lineFor(Habit driver) {
    final link = driver.health!;
    return link.metric == HealthMetric.sleepHours ? link.unit.fromBase(sleepLineMinutes) : driver.target;
  }

  static ({List<Habit> habits, DateTime day, int max, List<HealthFinding> findings})? _last;

  /// The findings at [now], clearest first, at most [max]. Remembered for
  /// the same habits and day (Insights asks on every build).
  static List<HealthFinding> of(List<Habit> habits, {required DateTime now, int max = 3}) {
    final today = DateTime(now.year, now.month, now.day);
    final last = _last;
    if (last != null && last.day == today && last.max == max && _same(last.habits, habits)) return last.findings;
    final findings = _work(habits, today, now, max);
    _last = (habits: List.of(habits), day: today, max: max, findings: findings);
    return findings;
  }

  static bool _same(List<Habit> a, List<Habit> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  static List<HealthFinding> _work(List<Habit> habits, DateTime today, DateTime now, int max) {
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final findings = <HealthFinding>[];
    for (final driver in driversIn(habits)) {
      final others = [for (final h in habits) if (!identical(h, driver) && h.schedule.isPeriodic) h];
      if (others.isEmpty) continue;
      // From when Health filled it in (and it was tracked), up to yesterday
      var from = DateTime(today.year, today.month, today.day - lookback);
      final linked = driver.health!.linkedOn;
      if (linked.isAfter(from)) from = linked;
      if (driver.trackedFrom.isAfter(from)) from = driver.trackedFrom;
      if (from.isAfter(yesterday)) continue;

      final line = lineFor(driver);
      final days = Insights.days(others, from: from, to: yesterday, now: now);
      var keptAbove = 0, dueAbove = 0, keptBelow = 0, dueBelow = 0, daysAbove = 0, daysBelow = 0;
      for (final day in days) {
        // No number that day: nothing known, not zero
        final value = driver.history[day.day];
        if (value == null || day.due == 0) continue;
        final kept = day.done + day.twoMinute;
        if (value >= line) {
          daysAbove++;
          dueAbove += day.due;
          keptAbove += kept;
        } else {
          daysBelow++;
          dueBelow += day.due;
          keptBelow += kept;
        }
      }
      if (daysAbove < minDays || daysBelow < minDays) continue;
      final finding = HealthFinding(
        driver: driver,
        metric: driver.health!.metric,
        line: line,
        rateAbove: keptAbove / dueAbove,
        rateBelow: keptBelow / dueBelow,
        daysAbove: daysAbove,
        daysBelow: daysBelow,
      );
      if (finding.gap >= minGap) findings.add(finding);
    }
    findings.sort((a, b) => b.gap.compareTo(a.gap));
    return findings.take(max).toList();
  }
}
