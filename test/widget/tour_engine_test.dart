import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/demo/demo_persona.dart';
import 'package:atomic_momentum/core/demo/demo_world.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/notification_service.dart';
import 'package:atomic_momentum/main.dart';
import 'package:atomic_momentum/presentation/tour/spotlight.dart';
import 'package:atomic_momentum/presentation/tour/tour.dart';
import 'package:atomic_momentum/presentation/tour/tour_anchor.dart';
import 'package:atomic_momentum/presentation/tour/tour_controller.dart';
import 'package:atomic_momentum/presentation/tour/world_scope.dart';
import 'package:atomic_momentum/screens/ios_main_navigation.dart';

import '../helpers/fake_notifications_plugin.dart';

/// A short tour of the kind the app's will be, to prove the engine.
const _tour = Tour(
  id: TourId.habits,
  title: 'Habits',
  world: TourWorld.example,
  tab: AppTab.habits,
  steps: [
    TourStep(anchor: TourAnchorId.overallMomentum, text: 'This is your momentum.'),
    TourStep(
      anchor: TourAnchorId.habitPlus,
      habit: DemoPersona.water,
      text: 'Tap + to log one more glass, or tap Next.',
      wait: TourWait.plus,
    ),
    TourStep(
      anchor: TourAnchorId.habitCard,
      habit: DemoPersona.meditate,
      text: "Swipe right to freeze a day you can't make, or tap Next.",
      wait: TourWait.swipeToFreeze,
    ),
    TourStep(
      anchor: TourAnchorId.addHabit,
      text: 'Your turn: add your first habit.',
      before: [ToOwnHabits()],
      nextLabel: 'Got it',
    ),
  ],
);

void main() {
  late WorldController worlds;

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({'themeMode': 'sepia'});
    NotificationService.debugOverride(plugin: FakeNotificationsPlugin());
    await initializeDependencies(seedDefaultHabit: false);
    worlds = WorldController(seed: (now) async => DemoSeed.build(now));
  });

  tearDown(() async {
    NotificationService.debugReset();
    await resetDependencies();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Map<String, Object?> stored() {
    final prefs = get<SharedPreferences>();
    // (and which greetings were seen: back from the example habits, their
    // own Habits screen greets them anew)
    return {
      for (final key in prefs.getKeys()
        ..remove(TourStore.key)
        ..remove('greetingsSeen'))
        key: prefs.get(key),
    };
  }

  Future<TourController> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(MomentumApp(worlds: worlds, tours: const {TourId.habits: _tour}));
    await tester.pumpAndSettle();
    return Provider.of<TourController>(tester.element(find.byType(IOSMainNavigation)), listen: false);
  }

  TourSpotlight spotlight(WidgetTester tester) => tester.widget<TourSpotlight>(find.byType(TourSpotlight));

  testWidgets('a tour on the example habits: Next, a real +, Next instead of a swipe, then the person\'s own app',
      (tester) async {
    final tours = await pumpApp(tester);
    final before = jsonEncode(stored());

    unawaited(tours.start(TourId.habits));
    await settle(tester);
    expect(worlds.world.isDemo, isTrue);
    expect(find.text('This is your momentum.'), findsOneWidget);
    // The spotlight is on the momentum ring
    final ring = tester.getRect(find.byKey(const Key('overallMomentum')));
    expect(spotlight(tester).target!.overlaps(ring), isTrue);

    await tester.tap(find.text('Next'));
    await settle(tester);
    expect(find.text('Tap + to log one more glass, or tap Next.'), findsOneWidget);
    // Doing it for real: the + inside the spotlight logs a glass and moves on
    final demo = worlds.world.demo!;
    final water = demo.idOf(DemoPersona.water);
    await tester.tap(find.byKey(Key('incrementHabit_$water')));
    await settle(tester);
    expect(demo.habits.getHabitById(water)!.progressForPeriodContaining(DateTime.now()), DemoPersona.waterToday + 1);
    expect(tours.stepIndex, 2);

    // Or Next, instead of the swipe
    expect(find.text('Next'), findsOneWidget, reason: 'every step can be moved on with Next');
    await tester.tap(find.text('Next'));
    await settle(tester);
    expect(worlds.world.isDemo, isFalse, reason: "the last step is in the person's own app");
    expect(find.text('Your turn: add your first habit.'), findsOneWidget);
    final orb = tester.getRect(find.byKey(const Key('addHabitButton')));
    expect(spotlight(tester).target!.overlaps(orb), isTrue);

    await tester.tap(find.text('Got it'));
    await settle(tester);
    expect(tours.isRunning, isFalse);
    expect(find.byType(TourSpotlight), findsNothing);
    expect(TourStore(get<SharedPreferences>()).seen, {TourId.habits});
    expect(jsonEncode(stored()), before, reason: 'only the seen list is written');
  });

  testWidgets('Skip ends it anywhere, back on the person\'s own habits', (tester) async {
    final tours = await pumpApp(tester);
    unawaited(tours.start(TourId.habits));
    await settle(tester);
    await tester.tap(find.text('Next'));
    await settle(tester);
    await tester.tap(find.text('Skip'));
    await settle(tester);
    expect(tours.isRunning, isFalse);
    expect(worlds.world.isDemo, isFalse);
    expect(TourStore(get<SharedPreferences>()).seen, {TourId.habits});
  });

  testWidgets('touches outside the spotlight never reach the app', (tester) async {
    final tours = await pumpApp(tester);
    unawaited(tours.start(TourId.habits));
    await settle(tester);
    await tester.tap(find.text('Next'));
    await settle(tester);
    final demo = worlds.world.demo!;
    final read = demo.idOf(DemoPersona.read);
    final before = demo.habits.getHabitById(read)!.progress;
    // Read's + is outside the spotlight (it's on Drink water's)
    await tester.tap(find.byKey(Key('incrementHabit_$read')), warnIfMissed: false);
    await settle(tester);
    expect(demo.habits.getHabitById(read)!.progress, before);
    expect(tours.stepIndex, 1);
  });
}
