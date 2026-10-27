import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/habit_goal.dart';
import 'package:atomic_momentum/domain/entities/habit_metadata.dart';
import 'package:atomic_momentum/domain/entities/health_link.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/entities/streak_data.dart';
import 'package:atomic_momentum/domain/services/health_insights.dart';

void main() {
  final now = DateTime(2026, 6, 30, 20);
  final start = DateTime(2026, 4, 1);
  DateTime day(int i) => DateTime(start.year, start.month, start.day + i);
  const days = 90; // April 1 to June 29

  Habit habit(
    String id, {
    int target = 1,
    String units = '',
    Map<DateTime, int> history = const {},
    HealthLink? health,
    HabitGoal goal = HabitGoal.build,
  }) =>
      Habit(
        id: id,
        name: id,
        progress: 0,
        target: goal == HabitGoal.quit ? 0 : target,
        units: units,
        color: HabitColor.teal,
        categoryId: BuiltInCategoryIds.body,
        lastUpdatedDate: now,
        resetFrequency: ResetFrequency.daily,
        history: history,
        streak: StreakData.empty(),
        metadata: HabitMetadata(createdDate: start, lastModifiedDate: start, version: 1, customFields: const {}),
        resetAnchorDate: start,
        health: health,
        goal: goal,
      ).refresh(now);

  /// Slept 8 hours on even days, 5 on odd ones.
  Habit sleep({HealthUnit unit = HealthUnit.hours}) => habit(
        'Sleep',
        target: unit == HealthUnit.hours ? 7 : 420,
        units: unit.label,
        health: HealthLink(metric: HealthMetric.sleepHours, unit: unit, linkedOn: start),
        history: {
          for (var i = 0; i < days; i++) day(i): unit.fromBase(i.isEven ? 480 : 300),
        },
      );

  /// Kept on [kept] days of the 90.
  Habit read(bool Function(int i) kept) => habit('Read', history: {
        for (var i = 0; i < days; i++)
          if (kept(i)) day(i): 1,
      });

  test('after good sleep, more kept: said plainly, with both sides', () {
    final findings = HealthInsights.of([sleep(), read((i) => i.isEven || i % 3 == 0)], now: now);
    expect(findings, hasLength(1));
    final f = findings.single;
    expect(f.metric, HealthMetric.sleepHours);
    expect(f.line, 7);
    expect(f.rateAbove, 1.0);
    expect(f.rateBelow, closeTo(1 / 3, 0.02));
    expect(f.daysAbove, 45);
    expect(f.daysBelow, 45);
  });

  test('sleep counted in minutes draws the same line', () {
    final f = HealthInsights.of([sleep(unit: HealthUnit.minutes), read((i) => i.isEven)], now: now).single;
    expect(f.line, 420);
    expect(f.rateAbove, 1.0);
    expect(f.rateBelow, 0.0);
  });

  test('no difference, nothing to say', () {
    expect(HealthInsights.of([sleep(), read((i) => i % 4 < 2)], now: now), isEmpty);
  });

  test('too few days on one side, nothing to say', () {
    final mostlyGood = habit(
      'Sleep',
      target: 7,
      units: 'hours',
      health: HealthLink(metric: HealthMetric.sleepHours, unit: HealthUnit.hours, linkedOn: start),
      history: {for (var i = 0; i < days; i++) day(i): i < 10 ? 5 : 8},
    );
    expect(HealthInsights.of([mostlyGood, read((i) => i >= 10)], now: now), isEmpty);
  });

  test('steps use the habit\'s own target as the line', () {
    final walk = habit(
      'Walk',
      target: 8000,
      units: 'steps',
      health: HealthLink(metric: HealthMetric.steps, linkedOn: start),
      history: {for (var i = 0; i < days; i++) day(i): i.isEven ? 9000 : 3000},
    );
    final f = HealthInsights.of([walk, read((i) => i.isEven)], now: now).single;
    expect(f.metric, HealthMetric.steps);
    expect(f.line, 8000);
  });

  test('only habits filled in from sleep, steps or exercise drive anything; others alone, nothing', () {
    final water = habit(
      'Water',
      target: 8,
      units: 'glasses',
      health: HealthLink(metric: HealthMetric.water, linkedOn: start),
      history: {for (var i = 0; i < days; i++) day(i): i.isEven ? 8 : 2},
    );
    expect(HealthInsights.driversIn([water, read((i) => true)]), isEmpty);
    expect(HealthInsights.of([water, read((i) => i.isEven)], now: now), isEmpty);
    expect(HealthInsights.of([sleep()], now: now), isEmpty, reason: 'no other habits to compare');
  });

  test('a habit being broken counts as kept on its clean days', () {
    final smoking = habit('Smoking', goal: HabitGoal.quit, history: {
      for (var i = 0; i < days; i++)
        if (i.isOdd) day(i): 1,
    });
    final f = HealthInsights.of([sleep(), smoking], now: now).single;
    expect(f.rateAbove, 1.0, reason: 'clean after good sleep');
    expect(f.rateBelow, 0.0);
  });
}
