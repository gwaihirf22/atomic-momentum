import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/data/models/habit_model.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/health_link.dart';
import '../../../helpers/test_data.dart';

/// A habit's link to Health.
void main() {
  final link = HealthLink(metric: HealthMetric.water, logToHealth: true, linkedOn: DateTime(2026, 10, 18));

  test('survives saving and loading, in both formats', () {
    final habit = TestData.createTestHabit().copyWith(health: link);
    expect(Habit.fromJson(habit.toJson()).health, link);
    final stored = HabitModel.fromDomain(habit).toJson();
    expect(stored['health'], {'metric': 'water', 'log': true, 'linkedOn': '2026-10-18'});
    expect(HabitModel.fromJson(stored).toDomain().health, link);
  });

  test('habits saved before Health load unlinked; unknown metrics drop the link', () {
    final json = HabitModel.fromDomain(TestData.createTestHabit()).toJson();
    expect(json.containsKey('health'), isFalse);
    expect(HabitModel.fromJson(json).toDomain().health, isNull);
    expect(HealthLink.fromJson({'metric': 'heartRate', 'linkedOn': '2026-10-18'}), isNull);
    expect(HealthLink.fromJson('steps'), isNull);
  });

  test('editing keeps the link; it can be changed or removed', () {
    final habit = TestData.createTestHabit().copyWith(health: link);
    expect(habit.updateDetails(name: 'Water').health, link);
    final steps = link.copyWith(metric: HealthMetric.steps);
    expect(habit.updateDetails(health: steps).health, steps);
    expect(habit.updateDetails(removeHealth: true).health, isNull);
  });

  test('only writable metrics log back; steps allow a 100,000 target', () {
    expect(link.logsToHealth, isTrue);
    expect(link.copyWith(metric: HealthMetric.steps).logsToHealth, isFalse);
    expect(Habit.maxTargetFor(link.copyWith(metric: HealthMetric.steps)), 100000);
    expect(Habit.maxTargetFor(link), 1000);
    expect(Habit.maxTargetFor(null), 1000);
  });

  test('which metrics Health Connect has', () {
    expect(HealthMetric.mindfulMinutes.availableOn(isAndroid: true), isFalse);
    expect(HealthMetric.values.every((m) => m.availableOn(isAndroid: false)), isTrue);
  });
}
