import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/demo/demo_persona.dart';
import 'package:atomic_momentum/core/demo/demo_world.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/notification_service.dart';
import 'package:atomic_momentum/data/datasources/shared_preferences_datasource.dart';
import 'package:atomic_momentum/main.dart';
import 'package:atomic_momentum/presentation/tour/spotlight.dart';
import 'package:atomic_momentum/presentation/tour/tour.dart';
import 'package:atomic_momentum/presentation/tour/tour_bubble.dart';
import 'package:atomic_momentum/presentation/tour/tour_controller.dart';
import 'package:atomic_momentum/presentation/tour/tours.dart';
import 'package:atomic_momentum/presentation/tour/world_scope.dart';
import 'package:atomic_momentum/screens/habit_editor_screen.dart';
import 'package:atomic_momentum/screens/ios_main_navigation.dart';

import '../helpers/fake_notifications_plugin.dart';
import '../helpers/real_fonts.dart';

void main() {
  late WorldController worlds;
  setUpAll(loadRealFonts);

  Future<void> setUpWith(Map<String, Object> values) async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({'themeMode': 'sepia', ...values});
    NotificationService.debugOverride(plugin: FakeNotificationsPlugin());
    await initializeDependencies(seedDefaultHabit: false);
    worlds = WorldController(seed: (now) async => DemoSeed.build(now));
  }

  tearDown(() async {
    NotificationService.debugReset();
    await resetDependencies();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  TourController toursIn(WidgetTester tester) =>
      Provider.of<TourController>(tester.element(find.byType(IOSMainNavigation)), listen: false);

  group('how a launch begins', () {
    test('a new install takes the tour; one with habits is offered it; after either, nothing', () async {
      SharedPreferences.setMockInitialValues({});
      expect(TourStart.of(await SharedPreferences.getInstance()), TourStart.firstRun);
      SharedPreferences.setMockInitialValues({SharedPreferencesDataSource.habitsKey: '[{"id":"x"}]'});
      expect(TourStart.of(await SharedPreferences.getInstance()), TourStart.offer);
      expect(TourStart.of(await SharedPreferences.getInstance(), fromNotification: true), TourStart.none);
      SharedPreferences.setMockInitialValues({TourStore.key: <String>[]});
      expect(TourStart.of(await SharedPreferences.getInstance()), TourStart.none);
    });
  });

  testWidgets('the first launch: the Habits tour, every step finding its target, then permission', (tester) async {
    await setUpWith({});
    var asked = 0;
    await tester.pumpWidget(MomentumApp(worlds: worlds, tourStart: TourStart.firstRun, onFirstTourDone: () => asked++));
    await settle(tester);
    final tours = toursIn(tester);
    expect(tours.tour?.id, TourId.habits);
    expect(worlds.world.isDemo, isTrue);

    for (var i = 0; i < Tours.habits.steps.length; i++) {
      await settle(tester);
      final step = Tours.habits.steps[i];
      expect(tours.stepIndex, i);
      expect(find.text(step.text), findsOneWidget, reason: 'step ${i + 1}');
      final spotlight = tester.widget<TourSpotlight>(find.byType(TourSpotlight));
      if (step.anchor != null) {
        expect(spotlight.target, isNotNull, reason: 'step ${i + 1} finds ${step.anchor!.name}');
      }
      expect(tester.takeException(), isNull);
      expect(asked, 0, reason: 'permission waits for the tour');
      await tester.tap(find.text(i == Tours.habits.steps.length - 1 ? 'Got it' : 'Next'));
    }
    await settle(tester);
    expect(tours.isRunning, isFalse);
    expect(worlds.world.isDemo, isFalse);
    expect(asked, 1);
    expect(TourStore(get<SharedPreferences>()).seen, {TourId.habits});
  });

  testWidgets('doing each thing for real moves the tour on just the same', (tester) async {
    await setUpWith({});
    await tester.pumpWidget(MomentumApp(worlds: worlds, tourStart: TourStart.firstRun));
    await settle(tester);
    final tours = toursIn(tester);
    await tester.tap(find.text('Next')); // welcome
    await settle(tester);
    await tester.tap(find.text('Next')); // momentum
    await settle(tester);
    final demo = worlds.world.demo!;
    await tester.tap(find.byKey(Key('incrementHabit_${demo.idOf(DemoPersona.water)}')));
    await settle(tester);
    expect(tours.stepIndex, 3, reason: '+ moved it on');
    await tester.longPress(find.byKey(Key('habitIcon_${demo.idOf(DemoPersona.read)}')));
    await settle(tester);
    expect(tours.stepIndex, 4, reason: 'holding the ring moved it on');
    expect(demo.habits.getHabitById(demo.idOf(DemoPersona.read))!.isCompleted, isTrue);
    await tester.tap(find.byKey(Key('twoMinute_${demo.idOf(DemoPersona.meditate)}')));
    await settle(tester);
    expect(tours.stepIndex, 5, reason: '2 min moved it on');
    await tester.drag(find.byKey(Key('habitCard_${demo.idOf(DemoPersona.gym)}')), const Offset(200, 0));
    await settle(tester);
    expect(tours.stepIndex, 6, reason: 'the swipe moved it on');
    await tester.tap(find.text('Next')); // the tab bar; the swipe is closed
    await settle(tester);
    // The person's own app: tapping Add habit ends it and opens the editor
    await tester.tap(find.byKey(const Key('addHabitButton')));
    await settle(tester);
    expect(tours.isRunning, isFalse);
    expect(find.byType(HabitEditorScreen), findsOneWidget);
  });

  testWidgets('someone with habits is offered it once: Not now, and it never asks again', (tester) async {
    await setUpWith({SharedPreferencesDataSource.habitsKey: '[]'});
    await tester.pumpWidget(MomentumApp(worlds: worlds, tourStart: TourStart.offer));
    await settle(tester);
    expect(find.text('Short tours show you around the app, on example habits. Take the Habits tour?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tourOfferNotNow')));
    await settle(tester);
    expect(find.byType(TourSpotlight), findsNothing);
    final prefs = get<SharedPreferences>();
    expect(TourStore(prefs).seen, {TourId.habits});
    expect(TourStart.of(prefs), TourStart.none);
    expect(worlds.world.isDemo, isFalse);
  });

  testWidgets('or Start takes it', (tester) async {
    await setUpWith({});
    await tester.pumpWidget(MomentumApp(worlds: worlds, tourStart: TourStart.offer));
    await settle(tester);
    await tester.tap(find.byKey(const Key('tourOfferStart')));
    await settle(tester);
    expect(toursIn(tester).tour?.id, TourId.habits);
    expect(worlds.world.isDemo, isTrue);
    expect(jsonEncode(TourStore(get<SharedPreferences>()).seen.map((t) => t.name).toList()), '[]');
  });

  testWidgets('Settings → Help → Tours plays a tour again, and Show tours again resets them', (tester) async {
    await setUpWith({TourStore.key: ['habits']});
    await tester.pumpWidget(MomentumApp(worlds: worlds));
    await settle(tester);
    final tours = toursIn(tester);
    await tester.tap(find.byKey(const Key('tab_settings')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('openTours')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('playTour_habits')));
    await settle(tester);
    expect(tours.tour?.id, TourId.habits);
    expect(worlds.world.isDemo, isTrue);
    await tester.tap(find.text('Skip'));
    await settle(tester);
    expect(worlds.world.isDemo, isFalse);
    expect(worlds.world.nav.current.value, AppTab.settings, reason: 'back where they started it');

    await tester.tap(find.byKey(const Key('openTours')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('toursShowAgain')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('toursShowAgainYes')));
    await settle(tester);
    expect(TourStore(get<SharedPreferences>()).seen, isEmpty);
  });

  group('fits small phones and large text, in every theme', () {
    for (final size in const [Size(375, 667), Size(390, 844)]) {
      for (final scale in const [1.0, 1.35]) {
        for (final theme in const ['light', 'sepia', 'dark']) {
          testWidgets('${size.width.toInt()}pt, ${(scale * 100).round()}%, $theme', (tester) async {
            await setUpWith({'themeMode': theme});
            tester.view.physicalSize = size * 3;
            tester.view.devicePixelRatio = 3;
            tester.view.padding = const FakeViewPadding(top: 20 * 3);
            tester.platformDispatcher.textScaleFactorTestValue = scale * sfWidthAllowance;
            addTearDown(tester.view.reset);
            addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
            await tester.pumpWidget(MomentumApp(worlds: worlds, tourStart: TourStart.firstRun));
            await settle(tester);
            final tours = toursIn(tester);
            for (var i = 0; i < Tours.habits.steps.length; i++) {
              await settle(tester);
              final step = Tours.habits.steps[i];
              expect(tester.takeException(), isNull, reason: 'step ${i + 1}');
              final spotlight = tester.widget<TourSpotlight>(find.byType(TourSpotlight));
              if (step.anchor != null) expect(spotlight.target, isNotNull, reason: 'step ${i + 1}');
              final bubble = tester.getRect(find.byType(TourBubble));
              expect(bubble.top, greaterThanOrEqualTo(20), reason: 'step ${i + 1} below the status bar');
              expect(bubble.bottom, lessThanOrEqualTo(size.height), reason: 'step ${i + 1} on screen');
              expect(bubble.left, greaterThanOrEqualTo(0));
              expect(bubble.right, lessThanOrEqualTo(size.width));
              await tester.tap(find.text(i == Tours.habits.steps.length - 1 ? 'Got it' : 'Next'));
            }
            await settle(tester);
            expect(tours.isRunning, isFalse);
          });
        }
      }
    }
  });
}
