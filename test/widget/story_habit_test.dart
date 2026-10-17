import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/entities/two_minute_version.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/main.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/screens/add_habit_screen.dart';
import 'package:atomic_momentum/screens/story_habit_screen.dart';

/// Story: a habit written as one sentence, for adding and editing.
void main() {
  Future<void> setUpApp({bool story = true}) async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({'addHabitStyle': story ? 'story' : 'builder'});
    await initializeDependencies(seedDefaultHabit: false);
  }

  tearDown(resetDependencies);

  HabitProvider appHabits(WidgetTester tester) =>
      Provider.of<HabitProvider>(tester.element(find.byKey(const Key('addHabitOrb'), skipOffstage: false)), listen: false);

  Future<void> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MomentumApp());
    await tester.pumpAndSettle();
  }

  Future<void> openStory(WidgetTester tester) async {
    await launch(tester);
    await tester.tap(find.byKey(const Key('addHabitOrb')));
    await tester.pumpAndSettle();
    expect(find.byType(StoryHabitScreen), findsOneWidget);
  }

  Future<void> tapPart(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> done(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('storySheetDone')));
    await tester.pumpAndSettle();
  }

  group('adding', () {
    setUp(setUpApp);

    testWidgets('the orb opens Story when it is chosen; empty parts invite filling in', (tester) async {
      await openStory(tester);
      expect(find.text('name your habit'), findsOneWidget);
      expect(find.text('how much'), findsOneWidget);
      expect(find.text('every day'), findsOneWidget);
      expect(find.text('add a tiny version'), findsOneWidget);
    });

    testWidgets('each part opens its sheet, and the sentence shows the change; then it saves', (tester) async {
      await openStory(tester);

      await tapPart(tester, 'storyName');
      expect(find.byKey(const Key('storySheet_name')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('habitNameField')), 'Drink water');
      await tester.tap(find.byKey(const Key('iconSwatch_water')));
      await done(tester);
      expect(find.text('drink water'), findsOneWidget);

      await tapPart(tester, 'storyAmount');
      await tester.enterText(find.byKey(const Key('habitTargetField')), '8');
      await tester.enterText(find.byKey(const Key('habitUnitsField')), 'glasses');
      await done(tester);
      expect(find.text('8 glasses'), findsOneWidget);

      await tapPart(tester, 'storySchedule');
      await tester.tap(find.byKey(const Key('frequency_weekly')));
      await done(tester);
      expect(find.text('each week'), findsOneWidget);

      await tapPart(tester, 'storyTiny');
      await tester.enterText(find.byKey(const Key('twoMinuteField')), 'Fill one glass');
      await done(tester);
      expect(find.text('fill one glass'), findsOneWidget);

      await tapPart(tester, 'storyReminder');
      await tester.tap(find.byKey(const Key('reminderSwitch')));
      await done(tester);
      expect(find.text('with no reminder'), findsOneWidget);

      await tester.tap(find.byKey(const Key('saveHabitButton')));
      await tester.pumpAndSettle();
      expect(find.byType(StoryHabitScreen), findsNothing);

      final habit = appHabits(tester).habits.single;
      expect(habit.name, 'Drink water');
      expect(habit.target, 8);
      expect(habit.units, 'glasses');
      expect(habit.metadata.icon, 'water');
      expect(habit.resetFrequency, ResetFrequency.weekly);
      expect(habit.twoMinute!.description, 'Fill one glass');
      expect(habit.reminder, isNull);
    });

    testWidgets('saving with no name opens the name, saying what is missing', (tester) async {
      await openStory(tester);
      await tester.tap(find.byKey(const Key('saveHabitButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('storySheet_name')), findsOneWidget);
      expect(find.text('Please enter a habit name'), findsOneWidget);
      expect(appHabits(tester).habits, isEmpty);
    });

    testWidgets('Done waits until the part is right', (tester) async {
      await openStory(tester);
      await tapPart(tester, 'storyAmount');
      await tester.enterText(find.byKey(const Key('habitTargetField')), '0');
      await done(tester);
      expect(find.byKey(const Key('storySheet_amount')), findsOneWidget);
      expect(find.text('Target must be a positive number'), findsOneWidget);
    });

    testWidgets('the parts are buttons VoiceOver reads with their values', (tester) async {
      final semantics = tester.ensureSemantics();
      await openStory(tester);
      expect(tester.getSemantics(find.byKey(const Key('storySchedule'))),
          matchesSemantics(label: 'How often: every day', hint: 'Change', isButton: true, hasTapAction: true));
      expect(tester.getSemantics(find.byKey(const Key('storyName'))),
          matchesSemantics(label: 'Habit: not set', hint: 'Change', isButton: true, hasTapAction: true));
      semantics.dispose();
    });

    testWidgets('habits that never reset have no hard-day sentence', (tester) async {
      await openStory(tester);
      await tapPart(tester, 'storySchedule');
      await tester.tap(find.byKey(const Key('frequency_never')));
      await done(tester);
      expect(find.text('in total'), findsOneWidget);
      expect(find.byKey(const Key('storyHardDay')), findsNothing);
    });
  });

  group('editing in Story', () {
    setUp(setUpApp);

    Future<String> addWater(WidgetTester tester) async {
      await appHabits(tester).createHabit(const CreateHabitParams(
        name: 'Drink water',
        target: 8,
        units: 'glasses',
        color: HabitColor.blue,
        categoryId: 'body',
        twoMinute: TwoMinuteVersion(description: 'Fill one glass'),
      ));
      await tester.pumpAndSettle();
      return appHabits(tester).habits.single.id;
    }

    testWidgets('tapping a card edits it as a sentence; changes save', (tester) async {
      await launch(tester);
      final id = await addWater(tester);
      await tester.tap(find.byKey(Key('habitCard_$id')));
      await tester.pumpAndSettle();

      expect(find.byType(StoryHabitScreen), findsOneWidget);
      expect(find.text('drink water'), findsOneWidget);
      expect(find.text('8 glasses'), findsOneWidget);
      expect(find.text('fill one glass'), findsOneWidget);

      await tapPart(tester, 'storyAmount');
      await tester.enterText(find.byKey(const Key('habitTargetField')), '6');
      await done(tester);
      await tester.tap(find.byKey(const Key('saveHabitButton')));
      await tester.pumpAndSettle();

      expect(find.byType(StoryHabitScreen), findsNothing);
      expect(appHabits(tester).habits.single.target, 6);
    });

    testWidgets('a habit can be deleted from its sentence', (tester) async {
      await launch(tester);
      final id = await addWater(tester);
      await tester.tap(find.byKey(Key('habitCard_$id')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('deleteHabitFromForm')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmDeleteHabit')));
      await tester.pumpAndSettle();
      expect(find.byType(StoryHabitScreen), findsNothing);
      expect(appHabits(tester).habits, isEmpty);
    });

  });

  group('editing in Builder', () {
    setUp(() => setUpApp(story: false));

    testWidgets('stays on one page', (tester) async {
      await launch(tester);
      await appHabits(tester).createHabit(const CreateHabitParams(
        name: 'Read',
        target: 10,
        color: HabitColor.teal,
        categoryId: 'mind',
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('habitCard_${appHabits(tester).habits.single.id}')));
      await tester.pumpAndSettle();
      expect(find.byType(AddHabitScreen), findsOneWidget);
      expect(find.byType(StoryHabitScreen), findsNothing);
    });
  });
}
