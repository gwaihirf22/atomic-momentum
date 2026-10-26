import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/demo/demo_persona.dart';
import 'package:atomic_momentum/core/demo/demo_world.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/notification_service.dart';
import 'package:atomic_momentum/data/datasources/shared_preferences_datasource.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/main.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/intro/momentum_mark.dart';
import 'package:atomic_momentum/presentation/tour/spotlight.dart';
import 'package:atomic_momentum/presentation/tour/tour.dart';
import 'package:atomic_momentum/presentation/tour/tour_bubble.dart';
import 'package:atomic_momentum/presentation/tour/tour_controller.dart';
import 'package:atomic_momentum/presentation/tour/tours.dart';
import 'package:atomic_momentum/presentation/tour/world_scope.dart';
import 'package:atomic_momentum/screens/categories_screen.dart';
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

  Future<void> addHabits(List<String> names) async {
    final habits = get<HabitProvider>();
    await habits.loadHabits();
    for (final name in names) {
      await habits.createHabit(
          CreateHabitParams(name: name, target: 1, color: HabitColor.blue, categoryId: BuiltInCategoryIds.mind));
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

    test('"Replay tours" starts the next launch over, from the welcome, once', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesDataSource.habitsKey: '[{"id":"x"}]',
        TourStore.key: ['calendar', 'habits', 'insights'],
      });
      final prefs = await SharedPreferences.getInstance();
      final store = TourStore(prefs);
      expect(await TourStart.forLaunch(prefs), TourStart.none);
      await store.setReplayNextLaunch(true);
      // A launch from a notification goes to the habit, and keeps the ask
      expect(await TourStart.forLaunch(prefs, fromNotification: true), TourStart.none);
      expect(store.replayNextLaunch, isTrue);
      // The next: the welcome and the Habits tour, though there are habits, and every tour comes back
      expect(await TourStart.forLaunch(prefs), TourStart.firstRun);
      expect(store.seen, isEmpty);
      expect(store.replayNextLaunch, isFalse, reason: 'the switch is off again');
      expect(await TourStart.forLaunch(prefs), TourStart.none, reason: 'once');
    });

    testWidgets('the switch is in Settings → Help', (tester) async {
      // The phone layout (the default 800×600 test window would show the iPad's sidebar)
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
      // Settings' own tour seen, so it doesn't cover the switch
      await setUpWith({TourStore.key: ['habits', 'settings']});
      await tester.pumpWidget(MomentumApp(worlds: worlds));
      await settle(tester);
      await tester.tap(find.byKey(const Key('tab_settings')));
      await settle(tester);
      final tile = find.byKey(const Key('replayTours'));
      expect(tile, findsOneWidget);
      await tester.tap(tile);
      await settle(tester);
      expect(TourStore(get<SharedPreferences>()).replayNextLaunch, isTrue);
      await tester.tap(tile);
      await settle(tester);
      expect(TourStore(get<SharedPreferences>()).replayNextLaunch, isFalse);
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
    await settle(tester);
    // It opens with the app saying hello
    expect(find.text("Hi! I'm Momentum."), findsOneWidget);
    expect(find.byType(MomentumMark), findsOneWidget);
    expect(find.text('Show me around'), findsOneWidget);

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
      if (step.before.any((m) => m is OpenCardActions)) {
        // Tapped Next rather than swiping: the card opens itself to show them
        final read = worlds.world.demo!.idOf(DemoPersona.read);
        final delete = tester.getRect(find.byKey(Key('deleteHabit_$read')));
        expect(delete.width, greaterThan(20), reason: 'Delete shows while it is explained');
      }
      await tester.tap(find.byType(TourNextButton));
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
    await tester.tap(find.text('Show me around')); // the welcome
    await settle(tester);
    await tester.tap(find.text('Next')); // example habits
    await settle(tester);
    await tester.tap(find.text('Next')); // momentum
    await settle(tester);
    await tester.tap(find.text('Next')); // a card's parts
    await settle(tester);
    final demo = worlds.world.demo!;
    String id(String name) => demo.idOf(name);
    // Only + works here: the card won't swipe open, − and the ring do nothing
    final plus = find.byKey(Key('incrementHabit_${id(DemoPersona.water)}'));
    await tester.dragFrom(tester.getCenter(plus), const Offset(-200, 0));
    await settle(tester);
    expect(find.byKey(Key('editHabit_${id(DemoPersona.water)}')), findsNothing, reason: 'no swipe actions');
    final logged = demo.habits.getHabitById(id(DemoPersona.water))!.progress;
    await tester.tap(find.byKey(Key('decrementHabit_${id(DemoPersona.water)}')), warnIfMissed: false);
    await settle(tester);
    expect(demo.habits.getHabitById(id(DemoPersona.water))!.progress, logged, reason: '− does nothing');
    expect(tours.stepIndex, 4);
    await tester.tap(find.byKey(Key('incrementHabit_${id(DemoPersona.water)}')));
    await settle(tester);
    expect(tours.stepIndex, 5, reason: '+ moved it on');
    await tester.longPress(find.byKey(Key('habitIcon_${id(DemoPersona.read)}')));
    await settle(tester);
    expect(tours.stepIndex, 6, reason: 'holding the ring moved it on');
    expect(demo.habits.getHabitById(id(DemoPersona.read))!.isCompleted, isTrue);
    await tester.tap(find.byKey(Key('twoMinute_${id(DemoPersona.meditate)}')));
    await settle(tester);
    expect(tours.stepIndex, 7, reason: '2 min moved it on');

    // Freeze: swiping only opens the button; tapping it moves on
    await tester.drag(find.byKey(Key('habitCard_${id(DemoPersona.gym)}')), const Offset(200, 0));
    await settle(tester);
    expect(tours.stepIndex, 7, reason: 'a swipe alone stays, so Freeze can be tapped');
    await tester.tap(find.byKey(Key('freezeHabit_${id(DemoPersona.gym)}')));
    await settle(tester);
    expect(tours.stepIndex, 8, reason: 'tapping Freeze moved it on');
    final today = DateTime.now();
    expect(demo.habits.getHabitById(id(DemoPersona.gym))!.isFrozenOn(today), isTrue);

    // Swipe left: Edit and Delete show, and stay while they're explained
    await tester.drag(find.byKey(Key('habitCard_${id(DemoPersona.read)}')), const Offset(-200, 0));
    await settle(tester);
    expect(tours.stepIndex, 9, reason: 'the left swipe moved it on');
    expect(find.byKey(Key('deleteHabit_${id(DemoPersona.read)}')).hitTestable(), findsNothing,
        reason: 'nothing in the spotlight takes a tap while Edit and Delete are explained');
    await tester.tap(find.text('Next'));
    await settle(tester);
    expect(tours.stepIndex, 10, reason: 'categories');
    expect(demo.habits.habits.map((h) => h.name), contains(DemoPersona.read));
    await tester.tap(find.text('Next')); // categories
    await settle(tester);
    await tester.tap(find.text('Next')); // the tab bar
    await settle(tester);
    // The person's own app: tapping Add habit ends it and opens the editor,
    // whose own tour follows
    await tester.tap(find.byKey(const Key('addHabitButton')));
    await settle(tester);
    expect(tours.tour?.id, TourId.editor);
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
    // The phone layout (the default 800×600 test window would show the iPad's sidebar)
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await setUpWith({TourStore.key: ['habits', 'settings']});
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
    await tester.scrollUntilVisible(find.byKey(const Key('toursShowAgain')), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.byKey(const Key('toursShowAgain')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('toursShowAgainYes')));
    await settle(tester);
    expect(TourStore(get<SharedPreferences>()).seen, isEmpty);
  });

  group('every tour finds each of its targets', () {
    for (final id in Tours.all.keys.where((id) => id != TourId.habits && id != TourId.editor)) {
      for (final (size, scale) in const [(Size(375, 667), 1.35), (Size(390, 844), 1.0)]) {
        testWidgets('${id.name} at ${size.width.toInt()}pt, ${(scale * 100).round()}%', (tester) async {
          await setUpWith({TourStore.key: ['habits']});
          // Arrange points at a habit
          if (id == TourId.arrange) await addHabits(['Drink water', 'Read 20 pages']);
          tester.view.physicalSize = size * 3;
          tester.view.devicePixelRatio = 3;
          tester.view.padding = const FakeViewPadding(top: 20 * 3);
          tester.platformDispatcher.textScaleFactorTestValue = scale * sfWidthAllowance;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpWidget(MomentumApp(worlds: worlds));
          await settle(tester);
          final tours = toursIn(tester);
          final tour = Tours.all[id]!;
          unawaited(tours.start(id));
          for (var i = 0; i < tour.steps.length; i++) {
            await settle(tester);
            await settle(tester);
            final step = tour.steps[i];
            expect(tours.stepIndex, i);
            expect(tester.takeException(), isNull, reason: 'step ${i + 1}');
            final spotlight = tester.widget<TourSpotlight>(find.byType(TourSpotlight));
            if (step.anchor != null) {
              expect(spotlight.target, isNotNull, reason: 'step ${i + 1} finds ${step.anchor!.name}');
            }
            final bubble = tester.getRect(find.byType(TourBubble));
            expect(bubble.top, greaterThanOrEqualTo(0), reason: 'step ${i + 1}');
            final text = tester.state<ScrollableState>(
                find.descendant(of: find.byType(TourBubble), matching: find.byType(Scrollable)));
            expect(text.position.maxScrollExtent, 0, reason: 'step ${i + 1}: all its words show');
            expect(bubble.bottom, lessThanOrEqualTo(size.height), reason: 'step ${i + 1}');
            await tester.tap(find.byType(TourNextButton));
          }
          await settle(tester);
          expect(tours.isRunning, isFalse);
          expect(worlds.world.isDemo, isFalse);
        });
      }
    }
  });

  // Every step's spotlight, poked at like a curious first-timer: taps all
  // over it, a hold, sideways drags. Only the step's own gesture may do
  // anything (and then the tour moves on); nothing else may open a page or
  // sheet, or lose the step's target.
  group('nothing in a spotlight takes a tour off course', () {
    int routes() =>
        find.byWidgetPredicate((w) => w.runtimeType.toString().startsWith('_ModalScope')).evaluate().length;

    for (final id in Tours.all.keys) {
      testWidgets(id.name, (tester) async {
        await setUpWith({TourStore.key: ['habits']});
        if (id == TourId.arrange) await addHabits(['Drink water', 'Read 20 pages']);
        tester.view.physicalSize = const Size(390, 844) * 3;
        tester.view.devicePixelRatio = 3;
        tester.view.padding = const FakeViewPadding(top: 20 * 3);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MomentumApp(worlds: worlds));
        await settle(tester);
        final tours = toursIn(tester);
        if (id == TourId.editor) {
          // It comes with the first new habit
          await tester.tap(find.byKey(const Key('addHabitButton')));
        } else {
          unawaited(tours.start(id));
        }
        await settle(tester);
        expect(tours.tour?.id, id);

        Future<void> after() async {
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 700));
          await tester.pump(const Duration(milliseconds: 700));
        }

        while (tours.tour?.id == id) {
          await settle(tester);
          final index = tours.stepIndex;
          final where = '${id.name} step ${index + 1}';
          final target = tester.widget<TourSpotlight>(find.byType(TourSpotlight)).target;
          final before = routes();
          final probes = <Future<void> Function()>[
            if (target != null) ...[
              for (final fx in const [0.15, 0.5, 0.85])
                for (final fy in const [0.2, 0.5, 0.8])
                  () => tester.tapAt(Offset(target.left + target.width * fx, target.top + target.height * fy)),
              () => tester.longPressAt(target.center),
              () => tester.dragFrom(target.center, const Offset(160, 0)),
              () => tester.dragFrom(target.center, const Offset(-160, 0)),
            ],
          ];
          var moved = false;
          for (final probe in probes) {
            await probe();
            await after();
            if (tours.tour?.id != id || tours.stepIndex != index) {
              moved = true;
              // On to its next step (or done, and perhaps the next screen's tour)
              expect(tours.tour?.id != id || tours.stepIndex == index + 1, isTrue, reason: '$where: one step at a time');
              expect(Tours.all[id]!.steps[index].wait, isNotNull, reason: '$where moved on by itself');
              break;
            }
            expect(routes(), before, reason: '$where: nothing opens');
            expect(tester.widget<TourSpotlight>(find.byType(TourSpotlight)).target, isNotNull,
                reason: '$where keeps its target');
          }
          if (moved || tours.tour?.id != id) continue;
          await tester.tap(find.byType(TourNextButton));
        }
      });
    }
  });

  testWidgets("a tab's first visit brings its tour, once; not before the Habits tour", (tester) async {
    await setUpWith({TourStore.key: <String>[]});
    await tester.pumpWidget(MomentumApp(worlds: worlds));
    await settle(tester);
    final tours = toursIn(tester);
    await tester.tap(find.byKey(const Key('tab_insights')));
    await settle(tester);
    expect(tours.isRunning, isFalse, reason: 'the Habits tour comes first');

    await TourStore(get<SharedPreferences>()).markSeen(TourId.habits);
    await tester.tap(find.byKey(const Key('tab_calendar')));
    await settle(tester);
    expect(tours.tour?.id, TourId.calendar);
    expect(worlds.world.isDemo, isTrue);
    await tester.tap(find.text('Skip'));
    await settle(tester);
    expect(worlds.world.nav.current.value, AppTab.calendar, reason: 'back on their own Calendar');
    await tester.tap(find.byKey(const Key('tab_habits')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('tab_calendar')));
    await settle(tester);
    expect(tours.isRunning, isFalse, reason: 'once only');
  });

  testWidgets('Arrange with no habits to arrange brings no tour', (tester) async {
    await setUpWith({TourStore.key: ['habits']});
    await tester.pumpWidget(MomentumApp(worlds: worlds));
    await settle(tester);
    await tester.longPress(find.byKey(const Key('categoryRing_mind')));
    await settle(tester);
    expect(find.byType(CategoriesScreen), findsOneWidget);
    expect(toursIn(tester).isRunning, isFalse);
  });

  testWidgets("Arrange's first visit brings its tour, once", (tester) async {
    await setUpWith({TourStore.key: ['habits']});
    await addHabits(['Drink water', 'Read 20 pages']);
    await tester.pumpWidget(MomentumApp(worlds: worlds));
    await settle(tester);
    final tours = toursIn(tester);
    await tester.longPress(find.byKey(const Key('categoryRing_mind')));
    await settle(tester);
    expect(tours.tour?.id, TourId.arrange);
    for (var i = 0; i < Tours.arrange.steps.length; i++) {
      await settle(tester);
      final step = Tours.arrange.steps[i];
      if (step.anchor != null) {
        expect(tester.widget<TourSpotlight>(find.byType(TourSpotlight)).target, isNotNull, reason: 'step ${i + 1}');
      }
      await tester.tap(find.byType(TourNextButton));
    }
    await settle(tester);
    expect(tours.isRunning, isFalse);
    expect(find.byType(CategoriesScreen), findsOneWidget, reason: 'still on Arrange, no second one opened');
    await tester.pageBack();
    await settle(tester);
    await tester.longPress(find.byKey(const Key('categoryRing_mind')));
    await settle(tester);
    expect(tours.isRunning, isFalse, reason: 'once only');
  });

  testWidgets('the first new habit, in Story, brings the editor tour', (tester) async {
    await setUpWith({TourStore.key: ['habits']});
    await tester.pumpWidget(MomentumApp(worlds: worlds));
    await settle(tester);
    final tours = toursIn(tester);
    await tester.tap(find.byKey(const Key('addHabitButton')));
    await settle(tester);
    expect(tours.tour?.id, TourId.editor);
    for (var i = 0; i < Tours.editor.steps.length; i++) {
      await settle(tester);
      expect(tester.widget<TourSpotlight>(find.byType(TourSpotlight)).target, isNotNull, reason: 'step ${i + 1}');
      await tester.tap(find.byType(TourNextButton));
    }
    await settle(tester);
    expect(tours.isRunning, isFalse);
    expect(find.byType(HabitEditorScreen), findsOneWidget, reason: 'still adding their habit');
  });

  group('a tour gives way', () {
    Future<TourController> running(WidgetTester tester) async {
      await setUpWith({TourStore.key: ['habits']});
      await tester.pumpWidget(MomentumApp(worlds: worlds));
      await settle(tester);
      final tours = toursIn(tester);
      unawaited(tours.start(TourId.insights));
      await settle(tester);
      await settle(tester);
      return tours;
    }

    testWidgets("to Android's back: a step back, and on the first, Skip", (tester) async {
      final tours = await running(tester);
      unawaited(tours.next());
      await settle(tester);
      expect(tours.stepIndex, 1);
      unawaited(tester.binding.handlePopRoute());
      await settle(tester);
      expect(tours.stepIndex, 0);
      unawaited(tester.binding.handlePopRoute());
      await settle(tester);
      expect(tours.isRunning, isFalse);
      expect(worlds.world.isDemo, isFalse);
    });

    testWidgets('to a notification tapped mid-tour', (tester) async {
      final tours = await running(tester);
      NotificationService.focusRequests.value = HabitFocusRequest('someone');
      addTearDown(() => NotificationService.focusRequests.value = null);
      await settle(tester);
      expect(tours.isRunning, isFalse);
      expect(worlds.world.isDemo, isFalse);
    });

    testWidgets('to a return after more than ten minutes away', (tester) async {
      final tours = await running(tester);
      final away = DateTime.now();
      withClock(Clock.fixed(away), () => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused));
      withClock(Clock.fixed(away.add(const Duration(minutes: 5))),
          () => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));
      await settle(tester);
      expect(tours.isRunning, isTrue, reason: 'five minutes is fine');
      withClock(Clock.fixed(away), () => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused));
      withClock(Clock.fixed(away.add(const Duration(minutes: 11))),
          () => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));
      await settle(tester);
      expect(tours.isRunning, isFalse);
    });
  });

  testWidgets('closing the app mid-tour leaves nothing running', (tester) async {
    await setUpWith({TourStore.key: ['habits']});
    await tester.pumpWidget(MomentumApp(worlds: WorldController(seed: (now) async => DemoSeed.build(now))));
    await settle(tester);
    unawaited(toursIn(tester).start(TourId.habitPage));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(Container());
    await settle(tester);
    expect(tester.takeException(), isNull);
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
              // Every word shows: the text never has to scroll
              final text = tester.state<ScrollableState>(
                  find.descendant(of: find.byType(TourBubble), matching: find.byType(Scrollable)));
              expect(text.position.maxScrollExtent, 0, reason: 'step ${i + 1}: all its words show');
              expect(bubble.bottom, lessThanOrEqualTo(size.height), reason: 'step ${i + 1} on screen');
              expect(bubble.left, greaterThanOrEqualTo(0));
              expect(bubble.right, lessThanOrEqualTo(size.width));
              await tester.tap(find.byType(TourNextButton));
            }
            await settle(tester);
            expect(tours.isRunning, isFalse);
          });
        }
      }
    }
  });
}
