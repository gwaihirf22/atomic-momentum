import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/demo/demo_persona.dart';
import 'package:atomic_momentum/core/demo/demo_world.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/home_widget_bridge.dart';
import 'package:atomic_momentum/core/services/notification_service.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/main.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/tour/tour_bubble.dart';
import 'package:atomic_momentum/presentation/tour/world_scope.dart';
import 'package:atomic_momentum/screens/habit_editor_screen.dart';
import 'package:atomic_momentum/screens/ios_main_navigation.dart';

import '../helpers/fake_health_source.dart';
import '../helpers/fake_home_widget_bridge.dart';
import '../helpers/fake_notifications_plugin.dart';

void main() {
  late FakeNotificationsPlugin plugin;
  late FakeHomeWidgetBridge bridge;
  late FakeHealthSource health;
  late WorldController worlds;

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({'themeMode': 'sepia'});
    plugin = FakeNotificationsPlugin();
    NotificationService.debugOverride(plugin: plugin);
    await initializeDependencies(seedDefaultHabit: false);
    health = FakeHealthSource.install();
    bridge = FakeHomeWidgetBridge();
    sl.unregister<HomeWidgetBridge>();
    sl.registerSingleton<HomeWidgetBridge>(bridge);
    worlds = WorldController(seed: (now) async => DemoSeed.build(now));
  });

  tearDown(() async {
    NotificationService.debugReset();
    await resetDependencies();
  });

  /// The person's storage, but for which greetings they've seen: back from
  /// the example habits, their own Habits screen greets them anew.
  Map<String, Object?> stored() {
    final prefs = get<SharedPreferences>();
    return {for (final key in prefs.getKeys()..remove('greetingsSeen')) key: prefs.get(key)};
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('the example world shows the example habits, and leaves the person\'s own untouched', (tester) async {
    await tester.pumpWidget(MomentumApp(worlds: worlds));
    await tester.pumpAndSettle();
    final real = Provider.of<HabitProvider>(tester.element(find.byType(IOSMainNavigation)), listen: false);
    await real.createHabit(CreateHabitParams(
        name: 'My habit', target: 1, color: HabitColor.green, categoryId: BuiltInCategoryIds.body));
    // The person on their Calendar
    await tester.tap(find.byKey(const Key('tab_calendar')));
    await tester.pumpAndSettle();
    final before = jsonEncode(stored());
    final scheduled = Map.of(plugin.scheduled);
    final widgetSaves = bridge.saved.length;

    await tester.runAsync(() => worlds.enterDemo());
    await settle(tester);
    expect(worlds.world.isDemo, isTrue);
    expect(find.byType(ExampleHabitsPill), findsOneWidget);
    expect(find.text(DemoPersona.water), findsWidgets);
    expect(find.text('My habit'), findsNothing);

    // Use it: +, and Add habit on the root navigator sees the example world
    final demo = worlds.world.demo!;
    final water = demo.idOf(DemoPersona.water);
    await tester.tap(find.byKey(Key('incrementHabit_$water')));
    await settle(tester);
    expect(demo.habits.getHabitById(water)!.progressForPeriodContaining(DateTime.now()), DemoPersona.waterToday + 1);
    await tester.tap(find.byKey(const Key('addHabitButton')));
    await settle(tester);
    final editor = tester.element(find.byType(HabitEditorScreen));
    expect(Provider.of<HabitProvider>(editor, listen: false), same(demo.habits));
    worlds.world.nav.popAllToRoot();
    await settle(tester);

    // Done: back to the person's own Calendar
    await tester.tap(find.byType(ExampleHabitsPill));
    await settle(tester);
    expect(worlds.world.isDemo, isFalse);
    expect(find.byType(ExampleHabitsPill), findsNothing);
    expect(worlds.world.nav.current.value, AppTab.calendar);
    await tester.tap(find.byKey(const Key('tab_habits')));
    await settle(tester);
    expect(find.text('My habit'), findsWidgets);
    expect(find.text(DemoPersona.water), findsNothing);

    // Nothing of theirs changed; nothing scheduled; widgets never saw an example
    expect(jsonEncode(stored()), before);
    expect(plugin.scheduled.keys.toSet(), scheduled.keys.toSet());
    for (final snapshot in bridge.saved.skip(widgetSaves)) {
      expect(snapshot, isNot(contains(DemoPersona.water)));
    }
    expect(health.accessRequests, isEmpty);
    expect(health.accessChecks, 0);
  });
}
