import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/background/background_refresh.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/health_link.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/presentation/health/health_live.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';

import '../helpers/fake_health_source.dart';
import '../helpers/fake_health_watch.dart';

/// Habits filled in from Health follow it while the app is open: Health
/// saying it changed, or every few minutes anyway.
void main() {
  late HabitProvider habits;
  late FakeHealthSource health;
  late FakeHealthWatch watch;

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    health = FakeHealthSource.install();
    habits = get<HabitProvider>();
    watch = FakeHealthWatch();
  });

  tearDown(resetDependencies);

  DateTime today() {
    final now = clock.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<String> addHabit(String name, {HealthMetric? metric}) async {
    final now = clock.now();
    await habits.createHabit(CreateHabitParams(
      name: name,
      target: metric?.defaultTarget ?? 1,
      units: metric?.unit ?? 'times',
      color: HabitColor.green,
      categoryId: BuiltInCategoryIds.body,
      health: metric == null ? null : HealthLink(metric: metric, linkedOn: DateTime(now.year, now.month, now.day - 1)),
    ));
    return habits.habits.last.id;
  }

  int stepsToday(String id) => habits.getHabitById(id)!.history[today()] ?? 0;

  testWidgets('watches what linked habits read, and nothing once none are linked', (tester) async {
    final live = HealthLive(habits: habits, watch: watch)..start();
    final read = await addHabit('Read');
    expect(watch.watched, isEmpty, reason: 'no habit reads Health');

    final walk = await addHabit('Walk', metric: HealthMetric.steps);
    await addHabit('Water', metric: HealthMetric.water);
    expect(watch.watched, [
      {HealthMetric.steps},
      {HealthMetric.steps, HealthMetric.water},
    ]);

    await habits.deleteHabit(walk);
    expect(watch.watched.last, {HealthMetric.water});
    await habits.updateHabitProgress(read, 1);
    expect(watch.watched, hasLength(3), reason: 'a tap changes nothing it watches');
    live.dispose();
  });

  testWidgets('Health changing is read a moment later, once for a burst', (tester) async {
    final walk = await addHabit('Walk', metric: HealthMetric.steps);
    final live = HealthLive(habits: habits, watch: watch)..start();
    await habits.syncHealth(force: true);
    final reads = health.reads;

    health.values[HealthMetric.steps] = {today(): 1164};
    watch
      ..change()
      ..change();
    await tester.pump(const Duration(seconds: 2));
    watch.change();
    await tester.pump(const Duration(seconds: 4));
    expect(stepsToday(walk), 0, reason: 'still settling');

    await tester.pump(const Duration(seconds: 2));
    expect(stepsToday(walk), 1164);
    expect(health.reads, reads + 1);
    live.dispose();
  });

  testWidgets('reads every few minutes while open, and not in the background', (tester) async {
    final walk = await addHabit('Walk', metric: HealthMetric.steps);
    final live = HealthLive(habits: habits, watch: watch)..start();
    await habits.syncHealth(force: true);

    health.values[HealthMetric.steps] = {today(): 858};
    await tester.pump(const Duration(minutes: 4));
    expect(stepsToday(walk), 0);
    await tester.pump(const Duration(minutes: 1, seconds: 1));
    expect(stepsToday(walk), 858);

    live.foreground = false;
    health.values[HealthMetric.steps] = {today(): 2000};
    watch.change();
    await tester.pump(const Duration(minutes: 11));
    expect(stepsToday(walk), 858, reason: 'iOS wakes the app for Health in the background instead');

    live.foreground = true;
    await tester.pump(const Duration(minutes: 5, seconds: 1));
    expect(stepsToday(walk), 2000);
    live.dispose();
  });

  testWidgets('without linked habits nothing is read', (tester) async {
    await addHabit('Read');
    final live = HealthLive(habits: habits, watch: watch)..start();
    final reads = health.reads;
    watch.change();
    await tester.pump(const Duration(minutes: 20));
    expect(health.reads, reads);
    live.dispose();
  });

  test('Health waking the app in the background reads it; a push from iCloud does not', () async {
    final walk = await addHabit('Walk', metric: HealthMetric.steps);
    await habits.syncHealth(force: true);
    health.values[HealthMetric.steps] = {today(): 4200};
    final reads = health.reads;

    await BackgroundRefresh.run(habits: habits, reason: BackgroundRefresh.push);
    expect(health.reads, reads);
    await BackgroundRefresh.run(habits: habits, reason: BackgroundRefresh.health);
    expect(stepsToday(walk), 4200);
  });
}
