import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/main.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/screens/add_habit_screen.dart';
import 'package:atomic_momentum/screens/builder_add_screen.dart';
import 'package:atomic_momentum/screens/habit_editor_screen.dart';
import 'package:atomic_momentum/screens/story_habit_screen.dart';
import '../helpers/habit_card_actions.dart';

/// The habit editor: Story or Builder, switched live at the top of the page
/// without losing anything entered.
void main() {
  Future<void> setUpApp([Map<String, Object> prefs = const {}]) async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues(prefs);
    await initializeDependencies(seedDefaultHabit: false);
  }

  tearDown(resetDependencies);

  HabitProvider appHabits(WidgetTester tester) =>
      Provider.of<HabitProvider>(tester.element(find.byKey(const Key('tab_habits'), skipOffstage: false)), listen: false);

  Future<void> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MomentumApp());
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> switchStyle(WidgetTester tester) => tap(tester, 'switchHabitStyle');

  String switchLabel(WidgetTester tester) =>
      tester.widget<Text>(find.descendant(of: find.byKey(const Key('switchHabitStyle')), matching: find.byType(Text))).data!;

  group('opening in Story (the default)', () {
    setUp(setUpApp);

    testWidgets('a new habit starts in Story, with a small switch to Builder', (tester) async {
      final semantics = tester.ensureSemantics();
      await launch(tester);
      await tap(tester, 'addHabitButton');
      expect(find.byType(StoryHabitScreen), findsOneWidget);
      expect(switchLabel(tester), 'Switch to Builder');
      expect(tester.getSize(find.byKey(const Key('switchHabitStyle'))).height, greaterThanOrEqualTo(44));
      expect(tester.getSemantics(find.byKey(const Key('switchHabitStyle'))),
          matchesSemantics(label: 'Switch to Builder', isButton: true, hasTapAction: true));
      semantics.dispose();
    });

    testWidgets('what Story has goes to Builder, and back, and then saves', (tester) async {
      await launch(tester);
      await tap(tester, 'addHabitButton');

      await tap(tester, 'storyName');
      await tester.enterText(find.byKey(const Key('habitNameField')), 'Drink water');
      await tap(tester, 'storySheetDone');
      await tap(tester, 'storyAmount');
      await tester.enterText(find.byKey(const Key('habitTargetField')), '8');
      await tester.enterText(find.byKey(const Key('habitUnitsField')), 'glasses');
      await tap(tester, 'storySheetDone');

      await switchStyle(tester);
      expect(find.byType(BuilderAddScreen), findsOneWidget);
      expect(find.byType(StoryHabitScreen), findsNothing);
      expect(switchLabel(tester), 'Switch to Story');
      expect(find.widgetWithText(TextFormField, 'Drink water'), findsOneWidget);
      await tap(tester, 'builderNext');
      expect(find.widgetWithText(TextFormField, '8'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'glasses'), findsOneWidget);

      // A change in Builder shows in the sentence
      await tester.enterText(find.byKey(const Key('habitTargetField')), '6');
      await switchStyle(tester);
      expect(find.byType(StoryHabitScreen), findsOneWidget);
      expect(find.text('drink water'), findsOneWidget);
      expect(find.text('6 glasses'), findsOneWidget);

      await tap(tester, 'saveHabitButton');
      expect(find.byType(HabitEditorScreen), findsNothing);
      final habit = appHabits(tester).habits.single;
      expect(habit.name, 'Drink water');
      expect(habit.target, 6);
      expect(habit.units, 'glasses');
    });

    testWidgets("a Builder quick pick reads as Story's sentence", (tester) async {
      await launch(tester);
      await tap(tester, 'addHabitButton');
      await switchStyle(tester);
      await tap(tester, 'quickPick_Read');
      await switchStyle(tester);
      expect(find.text('read'), findsOneWidget);
      expect(find.text('10 pages'), findsOneWidget);
      expect(find.text('read one page'), findsOneWidget);
    });

    testWidgets('switching alone is not a change: closing does not ask', (tester) async {
      await launch(tester);
      await tap(tester, 'addHabitButton');
      await switchStyle(tester);
      await switchStyle(tester);
      await Navigator.of(tester.element(find.byType(StoryHabitScreen))).maybePop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('discardChanges')), findsNothing);
      expect(find.byType(HabitEditorScreen), findsNothing);
    });

    testWidgets('editing switches between the sentence and the one-page form', (tester) async {
      await launch(tester);
      await appHabits(tester).createHabit(const CreateHabitParams(
        name: 'Drink water',
        target: 8,
        units: 'glasses',
        color: HabitColor.blue,
        categoryId: 'body',
      ));
      await tester.pumpAndSettle();
      await swipeToEdit(tester, appHabits(tester).habits.single.id);

      expect(find.byType(StoryHabitScreen), findsOneWidget);
      await switchStyle(tester);
      expect(find.byType(AddHabitScreen), findsOneWidget, reason: 'Builder edits on one page');
      expect(find.text('Edit Habit'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('habitTargetField')), '6');
      await switchStyle(tester);
      expect(find.text('6 glasses'), findsOneWidget);

      await tap(tester, 'saveHabitButton');
      expect(appHabits(tester).habits.single.target, 6);
    });
  });

  group('opening in Builder (chosen in Settings)', () {
    setUp(() => setUpApp({'addHabitStyle': 'builder'}));

    testWidgets('a new habit starts in Builder, with a switch to Story', (tester) async {
      await launch(tester);
      await tap(tester, 'addHabitButton');
      expect(find.byType(BuilderAddScreen), findsOneWidget);
      expect(switchLabel(tester), 'Switch to Story');
    });
  });
}
