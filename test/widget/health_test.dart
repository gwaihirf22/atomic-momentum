import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/health_source.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/habit_goal.dart';
import 'package:atomic_momentum/domain/entities/health_link.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/screens/add_habit_screen.dart';
import 'package:atomic_momentum/screens/habit_detail_screen.dart';
import 'package:atomic_momentum/screens/settings_screen.dart';

import '../helpers/fake_health_source.dart';

/// Habits filled in from Apple Health / Health Connect.
void main() {
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

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: get<ThemeProvider>()),
        ChangeNotifierProvider<HabitProvider>.value(value: habits),
        ChangeNotifierProvider<CategoryProvider>.value(value: get<CategoryProvider>()),
        ChangeNotifierProvider<SettingsProvider>.value(value: get<SettingsProvider>()),
      ],
      child: MaterialApp(home: home),
    ));
    await tester.pumpAndSettle();
  }

  Future<String> addLinked(HealthMetric metric, {int? target}) async {
    await habits.createHabit(CreateHabitParams(
      name: metric.label,
      target: target ?? metric.defaultTarget,
      units: metric.unit,
      color: HabitColor.green,
      categoryId: BuiltInCategoryIds.body,
      health: HealthLink(metric: metric, linkedOn: yesterday),
    ));
    return habits.habits.last.id;
  }

  testWidgets('linking a new habit to steps sets its units and an 8,000 target, and asks for access', (tester) async {
    await pump(tester, const AddHabitScreen());
    await tester.enterText(find.byKey(const Key('habitNameField')), 'Walk');
    await tester.ensureVisible(find.byKey(const Key('healthSwitch')));
    await tester.tap(find.byKey(const Key('healthSwitch')));
    await tester.pumpAndSettle();

    expect(health.accessRequests.single, {HealthMetric.steps});
    expect(tester.widget<EditableText>(find.descendant(of: find.byKey(const Key('habitUnitsField')), matching: find.byType(EditableText))).controller.text, 'steps');
    expect(find.text('Set by Steps'), findsOneWidget);

    await tester.tap(find.byKey(const Key('healthMetric_sleepHours')));
    await tester.pumpAndSettle();
    expect(find.text('Set by Sleep'), findsOneWidget);
    await tester.tap(find.byKey(const Key('healthMetric_steps')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('saveHabitButton')));
    await tester.tap(find.byKey(const Key('saveHabitButton')));
    await tester.pumpAndSettle();
    final walk = habits.habits.single;
    expect(walk.target, 8000);
    expect(walk.units, 'steps');
    expect(walk.health?.metric, HealthMetric.steps);
  });

  testWidgets('a habit being broken has no Health section; nor does a phone without Health', (tester) async {
    await pump(tester, const AddHabitScreen());
    expect(find.byKey(const Key('healthSection')), findsOneWidget);

    health.available = HealthAvailability.unsupported;
    await pump(tester, const SizedBox());
    await pump(tester, const AddHabitScreen());
    expect(find.byKey(const Key('healthSection')), findsNothing);
  });

  test('a sync fills in days from Health, never lowering one, and a second changes nothing', () async {
    final id = await addLinked(HealthMetric.steps);
    await habits.setDays(id, {yesterday: 9000});
    health.values[HealthMetric.steps] = {today: 6500, yesterday: 4000};

    await habits.syncHealth(force: true);
    final walk = habits.habits.single;
    expect(walk.history[today], 6500);
    expect(walk.history[yesterday], 9000, reason: 'the higher number wins');
    expect(habits.lastHealthSync, isNotNull);

    final before = habits.habits.single;
    await habits.syncHealth(force: true);
    expect(habits.habits.single, before);
  });

  test('syncs close together are skipped unless forced; break habits are never filled in', () async {
    final id = await addLinked(HealthMetric.water);
    health.values[HealthMetric.water] = {today: 3};
    await habits.syncHealth(force: true);
    final reads = health.reads;
    await habits.syncHealth();
    expect(health.reads, reads, reason: 'within a minute');
    expect(habits.habits.firstWhere((h) => h.id == id).history[today], 3);

    await habits.createHabit(const CreateHabitParams(
      name: 'Snacks',
      target: 0,
      color: HabitColor.red,
      categoryId: BuiltInCategoryIds.body,
      goal: HabitGoal.quit,
    ));
    expect(habits.habits.firstWhere((h) => h.name == 'Snacks').health, isNull);
  });

  testWidgets('the habit page says where the numbers come from', (tester) async {
    final id = await addLinked(HealthMetric.sleepHours);
    await pump(tester, HabitDetailScreen(habitId: id));
    expect(find.textContaining('From Apple Health · sleep'), findsOneWidget);
  });

  testWidgets('Settings syncs now and counts linked habits', (tester) async {
    await addLinked(HealthMetric.steps);
    health.values[HealthMetric.steps] = {today: 1200};
    await pump(tester, const SettingsScreen());
    await tester.scrollUntilVisible(find.byKey(const Key('healthSyncNow')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('1 habit linked'), findsOneWidget);
    await tester.tap(find.byKey(const Key('healthSyncNow')));
    await tester.pumpAndSettle();
    expect(habits.habits.single.history[today], 1200);
  });

  testWidgets('on Android without Health Connect, Settings offers to install it', (tester) async {
    health
      ..isAndroid = true
      ..available = HealthAvailability.needsHealthConnect;
    await pump(tester, const SettingsScreen());
    await tester.scrollUntilVisible(find.byKey(const Key('healthInstall')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Install Health Connect'), findsOneWidget);
    expect(find.byKey(const Key('healthSyncNow')), findsNothing);
  });
}
