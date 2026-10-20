import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/demo/demo_persona.dart';
import 'package:atomic_momentum/core/demo/demo_world.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/achievement_store.dart';
import 'package:atomic_momentum/data/datasources/shared_preferences_datasource.dart';
import 'package:atomic_momentum/main.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/presentation/tour/tour.dart';
import 'package:atomic_momentum/presentation/tour/tour_controller.dart';
import 'package:atomic_momentum/screens/achievements_screen.dart';
import 'package:atomic_momentum/screens/ios_main_navigation.dart';
import 'package:clock/clock.dart';

/// App Store screenshots: the tours' example habits (200 days of good use,
/// every kind of habit) as the person's own, on each screen the listing
/// shows, in Sepia, Charged and Light. Storage is in memory; the device's own
/// habits are never touched.
///
/// Run with tool/store_screens.sh; the pictures land in build/store_screens/.
/// Each one is the whole simulator screen, status bar included: the test
/// prints `STORE_SHOT <name>` and holds still while the script takes it
/// (`simctl io`); the app's own screenshots leave the status bar out and
/// only reach the driver once the test is over.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<HabitProvider> launch(WidgetTester tester, Appearance theme) async {
    final seed = DemoSeed.build(clock.now());
    await resetDependencies();
    SharedPreferences.setMockInitialValues({
      SharedPreferencesDataSource.habitsKey: seed.habits,
      AchievementStore.key: seed.seen,
      // Every tour seen: nothing covers the screens
      TourStore.key: [for (final id in TourId.values) id.name],
    });
    await initializeDependencies(seedDefaultHabit: false);
    await tester.pumpWidget(Container());
    await tester.pumpWidget(const MomentumApp(tourStart: TourStart.none));
    await _wait(tester, 1500);
    final nav = tester.element(find.byType(IOSMainNavigation));
    await Provider.of<ThemeProvider>(nav, listen: false).setAppearance(theme);
    await _wait(tester, 800);
    return Provider.of<HabitProvider>(nav, listen: false);
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await _wait(tester, 900);
    // ignore: avoid_print
    print('STORE_SHOT $name');
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 4)));
  }

  Future<void> tab(WidgetTester tester, AppTab tab) async {
    IOSMainNavigation.tabRequests.value = tab;
    await _wait(tester, 900);
  }

  Future<void> openHabit(WidgetTester tester, HabitProvider habits, String name) async {
    final id = habits.habits.firstWhere((h) => h.name == name).id;
    final card = find.byKey(Key('habitCard_$id'));
    await tester.scrollUntilVisible(card, 200, scrollable: find.byType(Scrollable).first);
    await _wait(tester, 400);
    await tester.tap(card);
    await _wait(tester, 1200);
  }

  /// Back from a page inside a tab (the deepest navigator).
  Future<void> back(WidgetTester tester) async {
    await tester.state<NavigatorState>(find.byType(Navigator).last).maybePop();
    await _wait(tester, 900);
  }

  /// Closes what's open over the tabs (Add and Edit).
  Future<void> close(WidgetTester tester) async {
    await Navigator.of(tester.element(find.byType(IOSMainNavigation, skipOffstage: false)), rootNavigator: true)
        .maybePop();
    await _wait(tester, 900);
  }

  testWidgets('the App Store screenshots', (tester) async {
    for (final theme in [Appearance.sepia, Appearance.dark, Appearance.light]) {
      final t = theme == Appearance.dark ? 'charged' : theme.name;
      final habits = await launch(tester, theme);

      await shot(tester, '${t}_01_habits');
      await openHabit(tester, habits, DemoPersona.water);
      await shot(tester, '${t}_02_habit_page');
      await back(tester);
      await openHabit(tester, habits, DemoPersona.meditate);
      await shot(tester, '${t}_03_never_miss_twice');
      await tester.tap(find.byKey(const Key('detailEditTop')));
      await _wait(tester, 1500);
      await shot(tester, '${t}_04_two_minute');
      await close(tester);
      await back(tester);

      await tab(tester, AppTab.insights);
      await shot(tester, '${t}_05_insights');
      await tab(tester, AppTab.calendar);
      await shot(tester, '${t}_06_calendar');
      await tab(tester, AppTab.inspire);
      await shot(tester, '${t}_07_inspire');
      await tab(tester, AppTab.insights);
      unawaited(tester.state<NavigatorState>(find.byType(Navigator).last)
          .push(MaterialPageRoute<void>(builder: (_) => const AchievementsScreen())));
      await _wait(tester, 1200);
      await shot(tester, '${t}_08_achievements');
      await back(tester);
      await tab(tester, AppTab.habits);
    }
  }, timeout: const Timeout(Duration(minutes: 15)));
}

/// Lets frames run for [ms].
Future<void> _wait(WidgetTester tester, int ms) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
