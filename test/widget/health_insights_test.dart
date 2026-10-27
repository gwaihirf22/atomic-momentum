import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/health_link.dart';
import 'package:atomic_momentum/domain/repositories/habit_repository.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/screens/insights_screen.dart';

import '../helpers/fake_plus_store.dart';

/// Health insights on Insights (Momentum Plus).
void main() {
  late HabitProvider habits;
  late FakePlusStore plus;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime daysAgo(int n) => DateTime(today.year, today.month, today.day - n);

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    habits = get<HabitProvider>();
    plus = FakePlusStore.install(unlocked: true);
  });

  tearDown(resetDependencies);

  /// Sleep linked to Health: 8 hours on even days, 5 on odd ones, for 60
  /// days; Read kept on the good-sleep days only (when [linked]).
  Future<void> seed({bool linked = true}) async {
    for (final name in ['Sleep', 'Read']) {
      await withClock(
        Clock.fixed(daysAgo(60)),
        () => habits.createHabit(CreateHabitParams(
          name: name,
          target: name == 'Sleep' ? 7 : 1,
          units: name == 'Sleep' ? 'hours' : '',
          color: HabitColor.indigo,
          categoryId: BuiltInCategoryIds.body,
        )),
      );
    }
    await habits.loadHabits();
    final repo = get<HabitRepository>();
    for (final h in habits.habits) {
      final sleep = h.name == 'Sleep';
      var updated = h.copyWith(history: {
        for (var i = 60; i >= 1; i--)
          if (sleep || i.isEven) daysAgo(i): sleep ? (i.isEven ? 8 : 5) : 1,
      });
      if (sleep && linked) {
        updated = updated.updateDetails(
          health: HealthLink(metric: HealthMetric.sleepHours, unit: HealthUnit.hours, linkedOn: daysAgo(60)),
        );
      }
      await repo.saveHabit(updated);
    }
    await habits.loadHabits();
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: get<ThemeProvider>()),
        ChangeNotifierProvider<HabitProvider>.value(value: habits),
        ChangeNotifierProvider<CategoryProvider>.value(value: get<CategoryProvider>()),
        ChangeNotifierProvider<SettingsProvider>.value(value: get<SettingsProvider>()),
      ],
      child: const MaterialApp(home: InsightsScreen()),
    ));
    await tester.pumpAndSettle();
  }

  final card = find.byKey(const Key('insightsHealth'));

  testWidgets('with Plus, says how sleep goes with the other habits, in plain words', (tester) async {
    await seed();
    await pump(tester);
    expect(card, findsOneWidget);
    expect(find.textContaining('On days with 7 hours of sleep or more, you keep 100% of your other habits'),
        findsOneWidget);
    expect(find.textContaining('Otherwise, 0%'), findsOneWidget);

    await tester.tap(find.descendant(of: card, matching: find.byKey(const Key('info_healthInsights'))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nothing leaves it'), findsOneWidget);
  });

  testWidgets('nothing linked: how to start', (tester) async {
    await seed(linked: false);
    await pump(tester);
    expect(find.descendant(of: card, matching: find.textContaining('Link a habit to sleep')), findsOneWidget);
  });

  testWidgets('without Plus, no card', (tester) async {
    plus.unlocked = false;
    await seed();
    await pump(tester);
    expect(card, findsNothing);
  });
}
