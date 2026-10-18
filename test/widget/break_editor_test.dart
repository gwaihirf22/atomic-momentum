import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/habit_goal.dart';
import 'package:atomic_momentum/domain/entities/reminder_settings.dart';
import 'package:atomic_momentum/domain/services/reminder_planner.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/main.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/screens/builder_add_screen.dart';
import 'package:atomic_momentum/screens/story_habit_screen.dart';

import '../helpers/habit_card_actions.dart';

/// Adding a habit to break: the Build | Break pill frames Story and Builder.
void main() {
  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
  });

  tearDown(resetDependencies);

  HabitProvider appHabits(WidgetTester tester) =>
      Provider.of<HabitProvider>(tester.element(find.byKey(const Key('tab_habits'), skipOffstage: false)), listen: false);

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> openEditor(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MomentumApp());
    await tester.pumpAndSettle();
    await tap(tester, 'addHabitButton');
  }

  Future<void> chooseBreak(WidgetTester tester) async {
    await tap(tester, 'habitGoalBreak');
    await tap(tester, 'breakGotIt');
  }

  String sentence(WidgetTester tester) => tester
      .widgetList<Text>(find.descendant(of: find.byKey(const Key('storySentence')), matching: find.byType(Text)))
      .map((t) => t.data)
      .join(' ');

  testWidgets('Break explains itself each time; Cancel stays on Build', (tester) async {
    await openEditor(tester);
    await tap(tester, 'habitGoalBreak');
    expect(find.text('Breaking a habit'), findsOneWidget);
    await tap(tester, 'breakCancel');
    expect(find.byKey(const Key('storyHardDay')), findsOneWidget, reason: 'still building');

    await chooseBreak(tester);
    expect(sentence(tester), contains('quit'));
    expect(find.byKey(const Key('storyHardDay')), findsNothing, reason: 'no two-minute version for breaking');

    await tap(tester, 'habitGoalBuild');
    await tap(tester, 'habitGoalBreak');
    expect(find.text('Breaking a habit'), findsOneWidget, reason: 'asked again');
    await tap(tester, 'breakGotIt');
  });

  testWidgets('Story: "I will quit smoking, checking in at 9:00 PM" saves a quit habit with a check-in', (tester) async {
    await openEditor(tester);
    await chooseBreak(tester);
    await tap(tester, 'storyName');
    await tester.enterText(find.byKey(const Key('habitNameField')), 'Smoking');
    await tap(tester, 'storySheetDone');
    expect(sentence(tester), contains('smoking'));
    expect(sentence(tester), contains('checking in at 9:00 PM'));

    await tap(tester, 'saveHabitButton');
    final habit = appHabits(tester).habits.single;
    expect(habit.goal, HabitGoal.quit);
    expect(habit.target, 0);
    expect(habit.twoMinute, isNull);
    expect(habit.reminder!.mode, ReminderMode.custom);
    expect(habit.reminder!.daysOfWeek, hasLength(7));
    expect(habit.reminder!.time, const TimeOfDay(hour: 21, minute: 0));
    expect(habit.reminder!.customMessage, ReminderPlanner.checkInBody);
  });

  testWidgets('Story: a limit reads "keep alcohol to 2 drinks a day"', (tester) async {
    await openEditor(tester);
    await chooseBreak(tester);
    await tap(tester, 'storyName');
    await tester.enterText(find.byKey(const Key('habitNameField')), 'Alcohol');
    await tap(tester, 'storySheetDone');
    await tap(tester, 'storyStrictness');
    await tap(tester, 'strictLimit');
    await tester.enterText(find.byKey(const Key('habitTargetField')), '2');
    await tester.enterText(find.byKey(const Key('habitUnitsField')), 'drinks');
    await tap(tester, 'storySheetDone');

    expect(sentence(tester), allOf(contains('keep'), contains('2 drinks'), contains('a day')));
    await tap(tester, 'saveHabitButton');
    final habit = appHabits(tester).habits.single;
    expect(habit.goal, HabitGoal.limit);
    expect(habit.target, 2);
    expect(habit.units, 'drinks');
  });

  testWidgets('Builder keeps Break across the switch, with break steps and picks', (tester) async {
    await openEditor(tester);
    await chooseBreak(tester);
    await tap(tester, 'switchHabitStyle');
    expect(find.byType(BuilderAddScreen), findsOneWidget);
    expect(find.text('What do you want to break?'), findsOneWidget);

    await tap(tester, 'quickPick_Alcohol');
    await tap(tester, 'builderNext');
    expect(find.text('How strict?'), findsOneWidget);
    expect(tester.widget<ChoiceChip>(find.byKey(const Key('strictLimit'))).selected, isTrue);
    await tap(tester, 'builderNext');
    expect(find.text('Stay honest'), findsOneWidget);
    expect(find.text('Check in to log any slips'), findsOneWidget);

    await tap(tester, 'saveHabitButton');
    final habit = appHabits(tester).habits.single;
    expect(habit.name, 'Alcohol');
    expect(habit.goal, HabitGoal.limit);
    expect(habit.target, 2);
  });

  testWidgets('going back to Build restores a smart reminder', (tester) async {
    await openEditor(tester);
    await chooseBreak(tester);
    await tap(tester, 'habitGoalBuild');
    await tap(tester, 'storyName');
    await tester.enterText(find.byKey(const Key('habitNameField')), 'Read');
    await tap(tester, 'storySheetDone');
    await tap(tester, 'storyAmount');
    await tester.enterText(find.byKey(const Key('habitTargetField')), '10');
    await tap(tester, 'storySheetDone');
    await tap(tester, 'saveHabitButton');

    final habit = appHabits(tester).habits.single;
    expect(habit.goal, HabitGoal.build);
    expect(habit.reminder!.isSmart, isTrue);
    expect(habit.reminder!.customMessage, isNull);
  });

  testWidgets("editing a habit being broken shows its goal, which can't change", (tester) async {
    await openEditor(tester);
    Navigator.of(tester.element(find.byType(StoryHabitScreen))).pop();
    await tester.pumpAndSettle();
    await appHabits(tester).createHabit(const CreateHabitParams(
      name: 'Smoking',
      target: 0,
      color: HabitColor.red,
      categoryId: BuiltInCategoryIds.body,
      goal: HabitGoal.quit,
    ));
    await tester.pumpAndSettle();
    await swipeToEdit(tester, appHabits(tester).habits.single.id);

    expect(find.byKey(const Key('habitGoalBreak')), findsNothing);
    expect(find.byKey(const Key('habitGoalLabel')), findsOneWidget);
    expect(sentence(tester), contains('quit'));
  });
}
