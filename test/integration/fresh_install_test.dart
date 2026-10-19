import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';

/// A new install starts with no habits: sample habits only come from
/// Settings → Developer in test builds, never on their own (they'd get
/// reminders, and come back whenever every habit was deleted).
void main() {
  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(resetDependencies);

  test('a fresh install loads no habits', () async {
    await initializeDependencies();
    final habits = get<HabitProvider>();
    await habits.loadHabits();
    expect(habits.habits, isEmpty);
  });

  test('deleting every habit leaves it empty after the next launch', () async {
    await initializeDependencies();
    final habits = get<HabitProvider>();
    await habits.loadHabits();
    expect(await habits.addSampleHabits(), greaterThan(0));
    for (final id in habits.habits.map((h) => h.id).toList()) {
      await habits.deleteHabit(id);
    }
    await habits.loadHabits();
    expect(habits.habits, isEmpty);
  });
}
