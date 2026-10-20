import 'dart:async';

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
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/domain/usecases/update_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/screens/add_habit_screen.dart';
import 'package:atomic_momentum/screens/habit_detail_screen.dart';
import 'package:atomic_momentum/screens/settings_screen.dart';
import 'package:atomic_momentum/screens/story_habit_screen.dart';

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
    tester.view.physicalSize = const Size(390, 3600);
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
    expect(find.descendant(of: find.byKey(const Key('habitUnitsField')), matching: find.text('steps')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('habitUnitsField')), matching: find.byType(EditableText)), findsNothing,
        reason: 'chosen, never typed');
    expect(find.text('From Steps in Health'), findsOneWidget);

    await tester.tap(find.byKey(const Key('healthMetric_sleepHours')));
    await tester.pumpAndSettle();
    expect(find.text('From Sleep in Health'), findsOneWidget);
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
    health.values[HealthMetric.water] = {today: 750};
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

  Future<String> addPlain(String name, {String units = '', HabitGoal goal = HabitGoal.build, int target = 1}) async {
    await habits.createHabit(CreateHabitParams(
      name: name,
      target: target,
      units: units,
      color: HabitColor.green,
      categoryId: BuiltInCategoryIds.body,
      goal: goal,
    ));
    return habits.habits.last.id;
  }

  group("the habit page offers Health when the habit's name suggests it", () {
    testWidgets('Link opens Health set to the suggestion; Save links the habit', (tester) async {
      final id = await addPlain('Walk', target: 5000, units: 'steps');
      health.values[HealthMetric.steps] = {today: 3200};
      await pump(tester, HabitDetailScreen(habitId: id));
      expect(find.text('Fill in from Apple Health?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('detailHealthOfferLink')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('healthSection')), findsOneWidget);
      expect(health.accessRequests.last, {HealthMetric.steps});
      await tester.tap(find.byKey(const Key('detailHealthSave')));
      await tester.pumpAndSettle();

      final walk = habits.getHabitById(id)!;
      expect(walk.health?.metric, HealthMetric.steps);
      expect(walk.target, 5000, reason: 'its own target kept');
      expect(find.byKey(const Key('detailHealthOffer')), findsNothing, reason: 'linked now');
      expect(find.textContaining('From Apple Health · steps'), findsOneWidget);
    });

    testWidgets('Not now stops offering it for that habit, after a restart too', (tester) async {
      final id = await addPlain('Meditate', target: 10, units: 'minutes');
      await pump(tester, HabitDetailScreen(habitId: id));
      await tester.tap(find.byKey(const Key('detailHealthOfferNotNow')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detailHealthOffer')), findsNothing);
      expect(get<SettingsProvider>().healthCardDismissed, {id});
    });

    testWidgets('not for a habit being broken, a name Health knows nothing about, or a phone without Health',
        (tester) async {
      final quit = await addPlain('Smoking', goal: HabitGoal.quit, target: 0);
      await pump(tester, HabitDetailScreen(habitId: quit));
      expect(find.byKey(const Key('detailHealthOffer')), findsNothing);

      final call = await addPlain('Call Mum');
      await pump(tester, HabitDetailScreen(habitId: call));
      expect(find.byKey(const Key('detailHealthOffer')), findsNothing);

      health.available = HealthAvailability.unsupported;
      final walk = await addPlain('Walk', target: 5000, units: 'steps');
      await pump(tester, HabitDetailScreen(habitId: walk));
      expect(find.byKey(const Key('detailHealthOffer')), findsNothing);
    });
  });

  testWidgets("Sync now on a linked habit's page reads Health again", (tester) async {
    final id = await addLinked(HealthMetric.steps);
    await pump(tester, HabitDetailScreen(habitId: id));
    health.values[HealthMetric.steps] = {today: 4321};
    await tester.tap(find.byKey(const Key('detailHealthSyncNow')));
    await tester.pumpAndSettle();
    expect(habits.getHabitById(id)!.history[today], 4321);
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

  testWidgets('in development, Settings can add sample Health data and fill habits in', (tester) async {
    await addLinked(HealthMetric.steps);
    await pump(tester, const SettingsScreen());
    await tester.scrollUntilVisible(find.byKey(const Key('healthSampleData')), 300, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.byKey(const Key('healthSampleData')));
    await tester.pumpAndSettle();
    health.values[HealthMetric.steps] = {today: 3200};
    await tester.tap(find.byKey(const Key('healthSampleData')));
    await tester.pumpAndSettle();
    expect(health.samplesAdded, 1);
    expect(find.text('Sample data added to Apple Health'), findsOneWidget);
    expect(habits.habits.single.history[today], 3200);
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

  group('logging back to Health', () {
    Future<String> addWater() async {
      await habits.createHabit(CreateHabitParams(
        name: 'Water',
        target: 8,
        units: 'glasses',
        color: HabitColor.blue,
        categoryId: BuiltInCategoryIds.body,
        health: HealthLink(metric: HealthMetric.water, logToHealth: true, linkedOn: yesterday),
      ));
      return habits.habits.single.id;
    }

    Future<void> settle() => Future<void>.delayed(Duration.zero).then((_) => Future<void>.delayed(Duration.zero));

    test('+ logs to Health and − takes back what the app logged', () async {
      final id = await addWater();
      await habits.updateHabitProgress(id, 2);
      await settle();
      expect(health.logged.single.metric, HealthMetric.water);
      expect(health.values[HealthMetric.water]![today], 500, reason: '2 glasses of 250 ml');

      await habits.updateHabitProgress(id, 1);
      await settle();
      expect(health.removed, hasLength(1));
      expect(health.logged, hasLength(2), reason: 'took back 2, logged 1 again');
      expect(health.values[HealthMetric.water]![today], 250);
      expect(habits.takeHealthNotice(), isNull);
    });

    test('− on water that came from Health says so, and Health\'s number comes back', () async {
      final id = await addWater();
      health.values[HealthMetric.water] = {today: 750};
      await habits.syncHealth(force: true);
      expect(habits.habits.single.history[today], 3);
      expect(health.logged, isEmpty, reason: 'numbers from Health aren\'t logged back');

      await habits.updateHabitProgress(id, 2);
      for (var i = 0; i < 5; i++) {
        await settle();
      }
      // It stops at Health's number, at once, and says so
      expect(habits.takeHealthNotice(), 'Apple Health shows 3 glasses today. Change it in Apple Health.');
      expect(habits.habits.single.history[today], 3);
      expect(health.removed, isEmpty, reason: 'nothing of the app\'s to take back');
    });

    test('water the app logged comes out with −; what another app logged stays', () async {
      final id = await addWater();
      health.values[HealthMetric.water] = {today: 250};
      await habits.syncHealth(force: true);
      expect(habits.habits.single.history[today], 1);
      await habits.updateHabitProgress(id, 3);
      for (var i = 0; i < 5; i++) {
        await settle();
      }
      await habits.syncHealth(force: true);
      expect(habits.habits.single.history[today], 3);

      await habits.updateHabitProgress(id, 1);
      for (var i = 0; i < 5; i++) {
        await settle();
      }
      expect(habits.habits.single.history[today], 1);
      expect(habits.takeHealthNotice(), isNull);
      await habits.updateHabitProgress(id, 0);
      await settle();
      expect(habits.habits.single.history[today], 1, reason: "the other app's glass");
      expect(habits.takeHealthNotice(), 'Apple Health shows 1 glasses today. Change it in Apple Health.');
    });

    test('habits that don\'t log back never write', () async {
      final id = await addLinked(HealthMetric.steps);
      await habits.updateHabitProgress(id, 1000);
      await settle();
      expect(health.logged, isEmpty);
    });
  });

  group('the fixes found verifying Health', () {
    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    Future<String> addWater() async {
      await habits.createHabit(CreateHabitParams(
        name: 'Water',
        target: 8,
        units: 'glasses',
        color: HabitColor.blue,
        categoryId: BuiltInCategoryIds.body,
        health: HealthLink(metric: HealthMetric.water, logToHealth: true, linkedOn: yesterday),
      ));
      return habits.habits.single.id;
    }

    test('quick taps are logged to Health in order, and all come out again', () async {
      final id = await addWater();
      await habits.updateHabitProgress(id, 1);
      await habits.updateHabitProgress(id, 2);
      await habits.updateHabitProgress(id, 3);
      await settle();
      expect(health.values[HealthMetric.water]![today], 750);
      await habits.updateHabitProgress(id, 0);
      await settle();
      expect(health.values[HealthMetric.water]![today], 0);
      expect(habits.takeHealthNotice(), isNull);
    });

    test("a delete Health refuses is kept, said, and taken back next time", () async {
      final id = await addWater();
      await habits.updateHabitProgress(id, 2);
      await settle();
      health.removeWorks = false;
      await habits.updateHabitProgress(id, 0);
      await settle();
      expect(habits.takeHealthNotice(), "Couldn't take that back from Apple Health. Try again.");
      health.removeWorks = true;
      await habits.updateHabitProgress(id, 2);
      await settle();
      await habits.updateHabitProgress(id, 0);
      await settle();
      expect(health.values[HealthMetric.water]![today], 0, reason: 'both writes came out');
    });

    test('Calendar logs today to Health like the card does', () async {
      final id = await addWater();
      await habits.updateProgressForDate(id, today, 2);
      await settle();
      expect(health.values[HealthMetric.water]![today], 500);
    });

    test('a tap while Health is being read stays, if it\'s higher', () async {
      final id = await addLinked(HealthMetric.steps);
      health.values[HealthMetric.steps] = {today: 3000};
      health.holdReads = Completer<void>();
      final sync = habits.syncHealth(force: true);
      await habits.updateHabitProgress(id, 9000);
      health.holdReads!.complete();
      health.holdReads = null;
      await sync;
      expect(habits.habits.single.history[today], 9000);
    });

    testWidgets('where Health says reading isn\'t allowed, Settings and the habit page offer to ask again',
        (tester) async {
      final id = await addLinked(HealthMetric.steps);
      health.isAndroid = true;
      health.accessAllowed = false;
      await habits.syncHealth(force: true);
      expect(habits.healthAccessMissing, isTrue);

      await pump(tester, HabitDetailScreen(habitId: id));
      expect(find.byKey(const Key('detailHealthBlocked')), findsOneWidget);
      health.accessAllowed = true;
      await tester.tap(find.byKey(const Key('detailHealthAllow')));
      await tester.pumpAndSettle();
      expect(health.accessRequests, isNotEmpty);
      expect(habits.healthAccessMissing, isFalse);
      expect(find.byKey(const Key('detailHealthBlocked')), findsNothing);
    });

    testWidgets('a week of nothing from Health asks whether Momentum is allowed', (tester) async {
      final id = await addLinked(HealthMetric.steps);
      final weekAgo = DateTime(today.year, today.month, today.day - 6);
      await habits.startFrom(id, weekAgo);
      health.values[HealthMetric.steps] = {
        for (var i = 0; i < 7; i++) DateTime(today.year, today.month, today.day - i): 0,
      };
      // A link made a week ago (so a sync looks at all seven days)
      await habits.updateHabitDetails(id, UpdateHabitParams(health: HealthLink(metric: HealthMetric.steps, linkedOn: weekAgo)));
      await habits.syncHealth(force: true);
      await pump(tester, HabitDetailScreen(habitId: id));
      expect(find.textContaining('Is Momentum allowed to read your steps?'), findsOneWidget);
    });
  });

  group("Health's number is the floor", () {
    Future<void> settle() => Future<void>.delayed(Duration.zero).then((_) => Future<void>.delayed(Duration.zero));

    test('− on steps stops at what Health says, and says so; a sync changes nothing after', () async {
      final id = await addLinked(HealthMetric.steps);
      health.values[HealthMetric.steps] = {today: 6500};
      await habits.syncHealth(force: true);

      await habits.updateHabitProgress(id, 5000);
      await settle();
      expect(habits.habits.single.history[today], 6500);
      expect(habits.takeHealthNotice(), 'Apple Health shows 6,500 steps today. Change it in Apple Health.');
      final shown = habits.habits.single;
      await habits.syncHealth(force: true);
      expect(habits.habits.single.history, shown.history, reason: 'nothing to put back: it never went below');
    });

    test('above Health\'s number you can lower freely; below it, it stops', () async {
      final id = await addLinked(HealthMetric.steps);
      health.values[HealthMetric.steps] = {today: 6500};
      await habits.syncHealth(force: true);
      await habits.updateHabitProgress(id, 9000);
      await habits.updateHabitProgress(id, 7000);
      await settle();
      expect(habits.habits.single.history[today], 7000);
      expect(habits.takeHealthNotice(), isNull);
    });

    test('Calendar: a past day stops at Health\'s number too', () async {
      final id = await addLinked(HealthMetric.steps);
      // Counting since yesterday, so a sync looks at it
      await habits.startFrom(id, yesterday);
      health.values[HealthMetric.steps] = {yesterday: 4000};
      await habits.syncHealth(force: true);
      await habits.updateProgressForDate(id, yesterday, 1000);
      await settle();
      expect(habits.habits.single.history[yesterday], 4000);
      expect(habits.takeHealthNotice(), startsWith('Apple Health shows 4,000 steps on '));
    });

    test('a day a sync no longer looks at (over a week ago) can be lowered', () async {
      final id = await addLinked(HealthMetric.steps);
      final old = DateTime(today.year, today.month, today.day - 10);
      health.values[HealthMetric.steps] = {old: 4000};
      await habits.syncHealth(force: true);
      await habits.updateProgressForDate(id, old, 1000);
      await settle();
      expect(habits.habits.single.history[old], 1000);
      expect(habits.takeHealthNotice(), isNull);
    });

    test('a weekly habit: − comes off the earlier days, but not below Health\'s', () async {
      await habits.createHabit(CreateHabitParams(
        name: 'Workouts',
        target: 3,
        units: 'workouts',
        color: HabitColor.green,
        categoryId: BuiltInCategoryIds.body,
        resetFrequency: ResetFrequency.weekly,
        // Weeks start yesterday, so yesterday and today are one week
        resetAnchor: yesterday,
        health: HealthLink(metric: HealthMetric.workouts, linkedOn: yesterday),
      ));
      final id = habits.habits.single.id;
      await habits.startFrom(id, yesterday);
      health.values[HealthMetric.workouts] = {yesterday: 2};
      await habits.syncHealth(force: true);
      expect(habits.habits.single.progress, 2);

      await habits.updateHabitProgress(id, 1);
      await settle();
      expect(habits.habits.single.progress, 2);
      expect(habits.takeHealthNotice(), 'Apple Health shows 2 workouts this week. Change it in Apple Health.');
    });
  });

  group('choosing the right link', () {
    testWidgets('a habit called Run suggests Exercise, and the preview shows today\'s minutes', (tester) async {
      health.values[HealthMetric.exerciseMinutes] = {today: 34};
      await pump(tester, const AddHabitScreen());
      await tester.enterText(find.byKey(const Key('habitNameField')), 'Run');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('healthSuggestion')));
      expect(find.text('Exercise from Apple Health?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('healthSuggestionLink')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('healthSuggestion')), findsNothing);
      expect(find.text('Apple Health shows 34 minutes today.'), findsOneWidget);

      // A wrong link reads as nothing, and says so
      await tester.tap(find.byKey(const Key('healthMetric_workouts')));
      await tester.pumpAndSettle();
      expect(find.textContaining('has no workouts for today yet'), findsOneWidget);
    });

    testWidgets('an unknown unit is replaced (and says so); the unit chips convert the target', (tester) async {
      await pump(tester, const AddHabitScreen());
      await tester.enterText(find.byKey(const Key('habitNameField')), 'Drink water');
      await tester.enterText(find.byKey(const Key('habitTargetField')), '3');
      await tester.enterText(find.byKey(const Key('habitUnitsField')), 'bottles');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('healthSuggestionLink')));
      await tester.tap(find.byKey(const Key('healthSuggestionLink')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('healthUnitReplaced')), findsOneWidget);
      expect(find.textContaining('"bottles" isn\'t a unit Apple Health counts in, so the target is now 8 glasses'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('healthUnit_ml')));
      await tester.tap(find.byKey(const Key('healthUnit_ml')));
      await tester.pumpAndSettle();
      final target = tester.widget<EditableText>(
          find.descendant(of: find.byKey(const Key('habitTargetField')), matching: find.byType(EditableText)));
      expect(target.controller.text, '2000');
      expect(find.byKey(const Key('healthUnitReplaced')), findsNothing);
    });

    testWidgets('in Story, a linked habit\'s units are chips in "How much" (holding them is safe)', (tester) async {
      final id = await addLinked(HealthMetric.water);
      await pump(tester, StoryHabitScreen(editHabit: habits.habits.firstWhere((h) => h.id == id)));
      await tester.tap(find.byKey(const Key('storyAmount')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('unitsChip_glasses')), findsOneWidget);
      await tester.longPress(find.byKey(const Key('habitUnitsField')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('unitsChip_ml')));
      await tester.pumpAndSettle();
      final target = tester.widget<EditableText>(
          find.descendant(of: find.byKey(const Key('habitTargetField')), matching: find.byType(EditableText)));
      expect(target.controller.text, '2000');
    });

    testWidgets('a habit not about health suggests nothing', (tester) async {
      await pump(tester, const AddHabitScreen());
      await tester.enterText(find.byKey(const Key('habitNameField')), 'Read');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('healthSuggestion')), findsNothing);
    });

    testWidgets('a target of 20,000 is fine without Health', (tester) async {
      health.available = HealthAvailability.unsupported;
      await pump(tester, const AddHabitScreen());
      await tester.enterText(find.byKey(const Key('habitNameField')), 'Steps');
      await tester.enterText(find.byKey(const Key('habitTargetField')), '20000');
      await tester.ensureVisible(find.byKey(const Key('saveHabitButton')));
      await tester.tap(find.byKey(const Key('saveHabitButton')));
      await tester.pumpAndSettle();
      expect(habits.habits.single.target, 20000);
      expect(habits.habits.single.health, isNull);
    });
  });
}
