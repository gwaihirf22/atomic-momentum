import 'package:intl/intl.dart';

import '../../domain/entities/health_link.dart';
import '../../domain/services/health_insights.dart';

/// Health insights in words: one plain sentence per finding.
abstract final class HealthInsightWords {
  static final _number = NumberFormat.decimalPattern();

  static String _percent(double rate) => '${(100 * rate).round()}%';

  /// "7 hours of sleep", "8,000 steps", "30 minutes of exercise".
  static String line(HealthFinding f) {
    final unit = f.driver.health!.unit;
    return switch (f.metric) {
      HealthMetric.sleepHours =>
        unit == HealthUnit.minutes ? '${(f.line / 60).round()} hours of sleep' : '${f.line} hours of sleep',
      HealthMetric.steps => '${_number.format(f.line)} steps',
      _ => '${_number.format(f.line)} ${unit.label} of exercise',
    };
  }

  /// "On days with 7 hours of sleep or more, you keep 82% of your habits.
  /// Otherwise, 64%."
  static String sentence(HealthFinding f) =>
      'On days with ${line(f)} or more, you keep ${_percent(f.rateAbove)} of your other habits. '
      'Otherwise, ${_percent(f.rateBelow)}.';

  /// "From 45 days with and 52 without."
  static String basis(HealthFinding f) => 'From ${f.daysAbove} days with and ${f.daysBelow} without.';

  static String noDrivers(String health) =>
      'Link a habit to sleep, steps or exercise from $health, and I\'ll show how they go with the rest.';

  static const notYet =
      'Nothing clear yet. I need two weeks on each side of the line, and a real difference, before I say anything.';
}
