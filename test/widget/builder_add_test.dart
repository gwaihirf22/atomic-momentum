import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/main.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/screens/builder_add_screen.dart';

/// Builder: a new habit in three steps, opened by the orb (the default style).
void main() {
  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
  });

  tearDown(resetDependencies);

  Future<void> openBuilder(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MomentumApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addHabitOrb')));
    await tester.pumpAndSettle();
    expect(find.byType(BuilderAddScreen), findsOneWidget);
  }

  // The app's own provider (get<HabitProvider>() makes a new one)
  HabitProvider appHabits(WidgetTester tester) =>
      Provider.of<HabitProvider>(tester.element(find.byKey(const Key('addHabitOrb'), skipOffstage: false)), listen: false);

  String stepTitle(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('builderStepTitle'))).data!;

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('builderNext')));
    await tester.pumpAndSettle();
  }

  testWidgets('three steps in order, with progress for VoiceOver', (tester) async {
    final semantics = tester.ensureSemantics();
    await openBuilder(tester);
    expect(stepTitle(tester), "What's the habit?");
    expect(tester.getSemantics(find.byKey(const Key('builderProgress'))), matchesSemantics(label: 'Step 1 of 3'));

    await tester.enterText(find.byKey(const Key('habitNameField')), 'Stretch');
    await next(tester);
    expect(stepTitle(tester), 'How often?');
    expect(tester.getSemantics(find.byKey(const Key('builderProgress'))), matchesSemantics(label: 'Step 2 of 3'));

    await tester.enterText(find.byKey(const Key('habitTargetField')), '1');
    await next(tester);
    expect(stepTitle(tester), 'Make it easy');
    expect(find.byKey(const Key('builderNext')), findsNothing);
    expect(find.byKey(const Key('saveHabitButton')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('Next needs a name, then a target', (tester) async {
    await openBuilder(tester);
    await next(tester);
    expect(find.text('Please enter a habit name'), findsOneWidget);
    expect(stepTitle(tester), "What's the habit?");

    await tester.enterText(find.byKey(const Key('habitNameField')), 'Stretch');
    await next(tester);
    await next(tester);
    expect(find.text('Please enter a target number'), findsOneWidget);
    expect(stepTitle(tester), 'How often?');
  });

  testWidgets('a quick pick fills every step, and finishing saves it', (tester) async {
    await openBuilder(tester);
    await tester.tap(find.byKey(const Key('quickPick_Drink water')));
    await tester.pumpAndSettle();
    expect(find.text('Drink water'), findsWidgets);
    expect(find.textContaining('8 glasses every day'), findsOneWidget, reason: 'the next steps preview it');

    await next(tester);
    expect(find.byKey(const Key('builderAmountSummary')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('builderAmountSummary'))).data, '8 glasses every day');

    await next(tester);
    expect(find.widgetWithText(TextFormField, 'Fill one glass'), findsOneWidget);

    await tester.tap(find.byKey(const Key('saveHabitButton')));
    await tester.pumpAndSettle();

    expect(find.byType(BuilderAddScreen), findsNothing);
    final habit = appHabits(tester).habits.single;
    expect(habit.name, 'Drink water');
    expect(habit.target, 8);
    expect(habit.units, 'glasses');
    expect(habit.metadata.icon, 'water');
    expect(habit.color, HabitColor.blue);
    expect(habit.categoryId, 'body');
    expect(habit.twoMinute!.description, 'Fill one glass');
    expect(habit.twoMinute!.minimum, 1);
    expect(habit.reminder!.isSmart, isTrue, reason: 'new habits remind by default');
  });

  testWidgets('back keeps what was entered', (tester) async {
    await openBuilder(tester);
    await tester.enterText(find.byKey(const Key('habitNameField')), 'Stretch');
    await next(tester);
    await tester.enterText(find.byKey(const Key('habitTargetField')), '2');

    await tester.tap(find.byKey(const Key('builderBack')));
    await tester.pumpAndSettle();
    expect(stepTitle(tester), "What's the habit?");
    expect(find.widgetWithText(TextFormField, 'Stretch'), findsOneWidget);

    await next(tester);
    expect(find.widgetWithText(TextFormField, '2'), findsOneWidget);
  });

  testWidgets('the system back gesture steps back too', (tester) async {
    await openBuilder(tester);
    await tester.enterText(find.byKey(const Key('habitNameField')), 'Stretch');
    await next(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(stepTitle(tester), "What's the habit?");
    expect(find.byKey(const Key('discardChanges')), findsNothing);
  });

  testWidgets('closing asks only when something was entered', (tester) async {
    await openBuilder(tester);
    await tester.tap(find.byKey(const Key('cancelHabitForm')));
    await tester.pumpAndSettle();
    expect(find.byType(BuilderAddScreen), findsNothing, reason: 'nothing to lose');

    await tester.tap(find.byKey(const Key('addHabitOrb')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('habitNameField')), 'Stretch');
    await next(tester);
    await tester.tap(find.byKey(const Key('cancelHabitForm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('discardChanges')), findsOneWidget);
    await tester.tap(find.byKey(const Key('discardChanges')));
    await tester.pumpAndSettle();
    expect(find.byType(BuilderAddScreen), findsNothing);
    expect(appHabits(tester).habits, isEmpty);
  });

  testWidgets('More icons opens every icon, and the choice shows on step 1', (tester) async {
    await openBuilder(tester);
    expect(find.byKey(const Key('iconSwatch_star')), findsNothing, reason: 'past the first ten');
    await tester.tap(find.byKey(const Key('iconSwatch_more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('iconSwatch_star')).last);
    await tester.tap(find.byKey(const Key('iconSheetDone')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('iconSwatch_star')), findsOneWidget, reason: 'the chosen icon always shows');
  });
}
