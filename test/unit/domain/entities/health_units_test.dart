import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/health_link.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/presentation/habit_form/habit_draft.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import '../../../helpers/fake_health_source.dart';

/// Units for habits filled in from Health: exact conversions, and linking
/// that never turns 2000 ml into 2000 glasses.
void main() {
  group('HealthUnit', () {
    test('converts exactly both ways', () {
      expect(HealthUnit.glasses.toBase(8), 2000);
      expect(HealthUnit.ml.fromBase(2000), 2000);
      expect(HealthUnit.glasses.fromBase(2000), 8);
      expect(HealthUnit.flOz.toBase(64), closeTo(1892.7, 0.1));
      expect(HealthUnit.flOz.fromBase(750), 25);
      expect(HealthUnit.cups.fromBase(HealthUnit.flOz.toBase(64)), 8, reason: '8 cups of 8 oz');
      expect(HealthUnit.hours.fromBase(410), 7, reason: '6 h 50 m, to the nearest hour');
      expect(HealthUnit.minutes.fromBase(410), 410);
    });

    test('recognises the words people type, only among the metric\'s units', () {
      final water = HealthMetric.water.units;
      expect(HealthUnit.match('ml', water), HealthUnit.ml);
      expect(HealthUnit.match(' Ounces ', water), HealthUnit.flOz);
      expect(HealthUnit.match('fl oz', water), HealthUnit.flOz);
      expect(HealthUnit.match('glass', water), HealthUnit.glasses);
      expect(HealthUnit.match('bottles', water), isNull);
      expect(HealthUnit.match('liters', water), isNull, reason: 'whole liters would round too much');
      expect(HealthUnit.match('mins', HealthMetric.sleepHours.units), HealthUnit.minutes);
      expect(HealthUnit.match('hours', HealthMetric.steps.units), isNull);
    });

    test('each metric has a sensible target in each of its units', () {
      expect(HealthMetric.sleepHours.defaultTargetIn(HealthUnit.minutes), 420);
      expect(HealthMetric.water.defaultTargetIn(HealthUnit.ml), 2000);
      expect(HealthMetric.water.defaultTargetIn(HealthUnit.flOz), 64);
      expect(HealthMetric.mindfulMinutes.defaultTargetIn(HealthUnit.minutes), 10);
    });

    test('a link keeps its unit when saved; old links and wrong units fall back to the usual one', () {
      final ml = HealthLink(metric: HealthMetric.water, unit: HealthUnit.ml, linkedOn: DateTime(2026, 10, 18));
      expect(HealthLink.fromJson(ml.toJson()), ml);
      expect(HealthLink.fromJson({'metric': 'water', 'linkedOn': '2026-10-18'})!.unit, HealthUnit.glasses);
      expect(HealthLink(metric: HealthMetric.steps, unit: HealthUnit.ml, linkedOn: DateTime(2026)).unit, HealthUnit.steps);
    });
  });

  group('linking in the editor', () {
    HabitDraft draftWith(String units, String target) =>
        HabitDraft.newHabit(categoryId: BuiltInCategoryIds.body, reminderTime: const TimeOfDay(hour: 9, minute: 0))
          ..units.text = units
          ..target.text = target;

    test('units the habit already has are kept, with its target', () {
      final draft = draftWith('ml', '2000')..setHealth(HealthMetric.water);
      expect(draft.health!.unit, HealthUnit.ml);
      expect(draft.target.text, '2000');
      expect(draft.healthUnitReplaced, isNull);
    });

    test('an unknown unit takes the usual one and its default target, and says so', () {
      final draft = draftWith('bottles', '3')..setHealth(HealthMetric.water);
      expect(draft.health!.unit, HealthUnit.glasses);
      expect(draft.target.text, '8');
      expect(draft.units.text, 'glasses');
      expect(draft.healthUnitReplaced, 'bottles');
    });

    test('no unit, no guessing: the metric\'s default', () {
      final draft = draftWith('', '1')..setHealth(HealthMetric.steps);
      expect(draft.target.text, '8000');
      expect(draft.healthUnitReplaced, isNull);
    });

    test('choosing another unit converts the target', () {
      final draft = draftWith('glasses', '8')..setHealth(HealthMetric.water);
      draft.setHealth(HealthMetric.water, unit: HealthUnit.ml);
      expect(draft.target.text, '2000');
      draft.setHealth(HealthMetric.water, unit: HealthUnit.flOz);
      expect(draft.target.text, '68');
      final sleep = draftWith('hours', '7')..setHealth(HealthMetric.sleepHours, unit: HealthUnit.minutes);
      expect(sleep.target.text, '420');
    });
  });

  group('past days and Health in other units', () {
    late HabitProvider habits;
    late FakeHealthSource health;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    setUp(() async {
      await resetDependencies();
      SharedPreferences.setMockInitialValues({});
      await initializeDependencies(seedDefaultHabit: false);
      health = FakeHealthSource.install();
      habits = get<HabitProvider>();
    });

    tearDown(resetDependencies);

    Future<String> addWater({String units = 'glasses', int target = 8, HealthUnit? linkedIn}) async {
      await habits.createHabit(CreateHabitParams(
        name: 'Water',
        target: target,
        units: units,
        color: HabitColor.blue,
        categoryId: BuiltInCategoryIds.body,
        health: linkedIn == null ? null : HealthLink(metric: HealthMetric.water, unit: linkedIn, linkedOn: yesterday),
      ));
      return habits.habits.single.id;
    }

    test('switching a linked habit from glasses to ml converts its past days', () async {
      final id = await addWater(linkedIn: HealthUnit.glasses);
      await habits.setDays(id, {yesterday: 6});
      final draft = HabitDraft.fromHabit(habits.habits.single, defaultReminderTime: const TimeOfDay(hour: 9, minute: 0))
        ..setHealth(HealthMetric.water, unit: HealthUnit.ml);
      expect(draft.historyScale, 250);
      expect(await draft.save(habits), isTrue);
      final water = habits.habits.single;
      expect(water.target, 2000);
      expect(water.units, 'ml');
      expect(water.history[yesterday], 1500);
    });

    test('linking a habit counted in ml keeps its days as they are; choosing glasses converts them', () async {
      final id = await addWater(units: 'ml', target: 2000);
      await habits.setDays(id, {yesterday: 1500});
      final keep = HabitDraft.fromHabit(habits.habits.single, defaultReminderTime: const TimeOfDay(hour: 9, minute: 0))
        ..setHealth(HealthMetric.water);
      expect(keep.historyScale, isNull);
      final convert = HabitDraft.fromHabit(habits.habits.single, defaultReminderTime: const TimeOfDay(hour: 9, minute: 0))
        ..setHealth(HealthMetric.water, unit: HealthUnit.glasses);
      expect(convert.target.text, '8');
      expect(convert.historyScale, closeTo(1 / 250, 1e-9));
      expect(await convert.save(habits), isTrue);
      expect(habits.habits.single.history[yesterday], 6);
    });

    test('ml from Health fill in a habit counted in fl oz, and + logs exact ml back', () async {
      final id = await addWater(units: 'fl oz', target: 64, linkedIn: HealthUnit.flOz);
      health.values[HealthMetric.water] = {today: 750};
      await habits.syncHealth(force: true);
      expect(habits.habits.single.history[today], 25);

      final draft = HabitDraft.fromHabit(habits.habits.single, defaultReminderTime: const TimeOfDay(hour: 9, minute: 0))
        ..setHealth(HealthMetric.water, logToHealth: true);
      await draft.save(habits);
      await habits.updateHabitProgress(id, 35);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(health.logged.single.end.difference(health.logged.single.start).inSeconds, 296, reason: '10 fl oz ≈ 296 ml');
    });
  });
}
