import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/data/datasources/local_habit_datasource.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/domain/usecases/delete_habit_usecase.dart';
import 'package:atomic_momentum/domain/usecases/get_habits_usecase.dart';
import 'package:atomic_momentum/domain/usecases/update_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/screens/add_habit_screen.dart';
import 'package:atomic_momentum/screens/habit_detail_screen.dart';
import 'package:atomic_momentum/screens/habit_editor_screen.dart';
import 'package:atomic_momentum/presentation/widgets/hold_undo_strip.dart';
import 'package:atomic_momentum/presentation/widgets/recent_periods_bar.dart';
import 'package:atomic_momentum/screens/home_screen.dart';

import '../helpers/failing_habit_repository.dart';
import '../helpers/real_fonts.dart';
import '../helpers/habit_card_actions.dart';

void main() {
  late HabitProvider habitProvider;
  late String waterId;

  // Real text widths, so sizes match a phone
  setUpAll(loadRealFonts);

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    habitProvider = get<HabitProvider>();

    await habitProvider.createHabit(const CreateHabitParams(
      name: 'Drink Water',
      target: 3,
      units: 'glasses',
      color: HabitColor.blue,
      categoryId: BuiltInCategoryIds.body,
      icon: 'water',
    ));
    waterId = habitProvider.habits.single.id;
  });

  tearDown(() async {
    await resetDependencies();
  });

  Future<void> pumpHome(WidgetTester tester, {double width = 375}) async {
    tester.view.physicalSize = Size(width, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: get<ThemeProvider>()),
        ChangeNotifierProvider<HabitProvider>.value(value: habitProvider),
        ChangeNotifierProvider<CategoryProvider>.value(value: get<CategoryProvider>()),
        ChangeNotifierProvider<SettingsProvider>.value(value: get<SettingsProvider>()),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ));
    await tester.pumpAndSettle();
  }

  Finder card() => find.byKey(Key('habitCard_$waterId'));

  final now = DateTime.now();
  DateTime daysAgo(int n) => DateTime(now.year, now.month, now.day - n);

  group('holding the ring', () {
    Finder ring() => find.byKey(Key('habitIcon_$waterId'));
    Finder undo() => find.byKey(Key('undoHold_$waterId'));

    testWidgets('finishes the habit, with a firm haptic and Undo over the card', (tester) async {
      final haptics = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments as String);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await habitProvider.updateHabitProgress(waterId, 1);
      await pumpHome(tester);

      await tester.longPress(ring());
      await tester.pump(const Duration(milliseconds: 300));

      expect(habitProvider.habits.single.progress, 3);
      expect(habitProvider.habits.single.isCompleted, isTrue);
      expect(haptics.last, 'HapticFeedbackType.heavyImpact');
      expect(undo(), findsOneWidget);
      expect(find.text('Marked done'), findsOneWidget);
      await tester.pump(HoldUndo.duration);
      await tester.pumpAndSettle();
    });

    testWidgets('Undo puts back exactly what was there', (tester) async {
      await habitProvider.updateHabitProgress(waterId, 1);
      await pumpHome(tester);
      await tester.longPress(ring());
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(undo());
      await tester.pumpAndSettle();
      expect(habitProvider.habits.single.progress, 1);
      expect(undo(), findsNothing);
    });

    testWidgets('after the countdown the strip goes and the change stays', (tester) async {
      await pumpHome(tester);
      await tester.longPress(ring());
      await tester.pump(const Duration(milliseconds: 300));
      expect(undo(), findsOneWidget);

      await tester.pump(HoldUndo.duration);
      await tester.pumpAndSettle();
      expect(undo(), findsNothing);
      expect(habitProvider.habits.single.isCompleted, isTrue);
    });

    testWidgets('while Undo shows, tapping the card does not open Edit', (tester) async {
      await pumpHome(tester);
      await tester.longPress(ring());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Marked done'));
      await tester.pumpAndSettle();
      expect(find.byType(HabitEditorScreen), findsNothing);
      await tester.pump(HoldUndo.duration);
      await tester.pumpAndSettle();
    });

    testWidgets('on a finished habit, clears it; Undo brings it back', (tester) async {
      await habitProvider.updateHabitProgress(waterId, 3);
      await pumpHome(tester);

      await tester.longPress(ring());
      await tester.pump(const Duration(milliseconds: 300));
      expect(habitProvider.habits.single.progress, 0);
      expect(find.text('Cleared'), findsOneWidget);

      await tester.tap(undo());
      await tester.pumpAndSettle();
      expect(habitProvider.habits.single.progress, 3);
    });

    testWidgets('clearing a weekly habit empties the whole week, and Undo restores every day', (tester) async {
      await habitProvider.createHabit(const CreateHabitParams(
        name: 'Swim',
        target: 2,
        color: HabitColor.teal,
        categoryId: BuiltInCategoryIds.body,
        resetFrequency: ResetFrequency.weekly,
      ));
      final swim = habitProvider.habits.firstWhere((h) => h.name == 'Swim');
      // The week starts today (its reset day), so log twice today
      await habitProvider.updateHabitProgress(swim.id, 2);
      await pumpHome(tester);

      await tester.longPress(find.byKey(Key('habitIcon_${swim.id}')));
      await tester.pump(const Duration(milliseconds: 300));
      final cleared = habitProvider.habits.firstWhere((h) => h.id == swim.id);
      expect(cleared.progressForPeriodContaining(DateTime.now()), 0);

      await tester.tap(find.byKey(Key('undoHold_${swim.id}')));
      await tester.pumpAndSettle();
      expect(habitProvider.habits.firstWhere((h) => h.id == swim.id).progress, 2);
    });

    testWidgets('VoiceOver: "Mark done", then "Clear", and the ring says what holding does', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpHome(tester);

      expect(tester.getSemantics(ring()),
          matchesSemantics(
            label: 'Drink Water, Body, 0/3 glasses',
            hint: 'Adds one',
            onLongPressHint: 'Finish',
            isButton: true,
            hasTapAction: true,
            hasLongPressAction: true,
          ));

      Future<void> perform(String label) async {
        final cardNode = tester.getSemantics(card());
        final action = cardNode.getSemanticsData().customSemanticsActionIds!
            .map(CustomSemanticsAction.getAction)
            .firstWhere((action) => action!.label == label)!;
        tester.binding.pipelineOwner.semanticsOwner!
            .performAction(cardNode.id, SemanticsAction.customAction, CustomSemanticsAction.getIdentifier(action));
        await tester.pump(const Duration(milliseconds: 300));
      }

      await perform('Mark done');
      expect(habitProvider.habits.single.isCompleted, isTrue);
      await tester.pump(HoldUndo.duration);
      await tester.pumpAndSettle();

      await perform('Clear');
      expect(habitProvider.habits.single.progress, 0);
      await tester.pump(HoldUndo.duration);
      await tester.pumpAndSettle();
      semantics.dispose();
    });
  });

  testWidgets('the card shows the last seven days, read out for VoiceOver', (tester) async {
    final semantics = tester.ensureSemantics();
    await habitProvider.updateProgressForDate(waterId, daysAgo(2), 3);
    await habitProvider.updateProgressForDate(waterId, daysAgo(1), 1);
    await pumpHome(tester);

    final bars = find.byKey(Key('habitRecent_$waterId'));
    expect(bars, findsOneWidget);
    // The habit was made today, but logging earlier days tracks it from then
    // Read as part of the card
    expect(tester.getSemantics(bars).label, contains('Last 3 days: 1 done, 1 partly done'));
    expect(tester.getRect(bars).right, lessThanOrEqualTo(tester.getRect(card()).right));
    // Only the three tracked days are drawn
    expect(tester.getSize(bars).width, closeTo(3 * RecentPeriodsBar.barWidth + 2 * RecentPeriodsBar.gap, 0.1));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('a brand-new habit has no days to show yet', (tester) async {
    await pumpHome(tester);
    expect(find.byKey(Key('habitRecent_$waterId')), findsNothing);
  });

  testWidgets('on wider phones the card is one compact row', (tester) async {
    await habitProvider.updateProgressForDate(waterId, daysAgo(1), 3);
    await pumpHome(tester, width: 402);
    expect(find.byKey(Key('habitMomentum_$waterId')), findsOneWidget);

    final rect = tester.getRect(card());
    expect(rect.height, lessThanOrEqualTo(80));
    final stepper = tester.getRect(find.byKey(Key('incrementHabit_$waterId')));
    final name = tester.getRect(find.descendant(of: card(), matching: find.text('Drink Water')));
    expect(stepper.center.dy, closeTo(rect.center.dy, 4), reason: 'stepper beside the text');
    expect(name.right, lessThan(stepper.left));
    expect(tester.takeException(), isNull);
  });

  testWidgets('on an iPhone SE (375pt) the stats and stepper move under the name', (tester) async {
    await habitProvider.updateProgressForDate(waterId, daysAgo(1), 3);
    await pumpHome(tester);

    final rect = tester.getRect(card());
    expect(rect.right, lessThanOrEqualTo(375));
    final name = tester.getRect(find.descendant(of: card(), matching: find.text('Drink Water')));
    final stepper = tester.getRect(find.byKey(Key('incrementHabit_$waterId')));
    final momentum = tester.getRect(find.byKey(Key('habitMomentum_$waterId')));
    expect(stepper.top, greaterThan(name.bottom), reason: 'stepper on the second row');
    expect(momentum.top, greaterThan(name.bottom));
    expect(find.descendant(of: card(), matching: find.textContaining('0/3 glasses')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the subtitle shows only what is informative', (tester) async {
    await habitProvider.createHabit(const CreateHabitParams(
      name: 'Read',
      target: 2,
      units: 'chapters',
      color: HabitColor.teal,
      categoryId: BuiltInCategoryIds.mind,
      scheduledWeekdays: [DateTime.monday, DateTime.wednesday, DateTime.friday],
    ));
    await habitProvider.createHabit(const CreateHabitParams(
      name: 'Call a friend',
      target: 2,
      units: 'calls',
      color: HabitColor.green,
      categoryId: BuiltInCategoryIds.social,
      resetFrequency: ResetFrequency.weekly,
    ));
    final handle = tester.ensureSemantics();
    await pumpHome(tester);

    String subtitle(String name) {
      final habit = habitProvider.habits.firstWhere((h) => h.name == name);
      final card = find.byKey(Key('habitCard_${habit.id}'));
      return tester
          .widgetList<RichText>(find.descendant(of: card, matching: find.byType(RichText)))
          .map((t) => t.text.toPlainText())
          .firstWhere((t) => t.startsWith('0/'));
    }

    // Every day is the default, and the category shows in the icon and color
    expect(subtitle('Drink Water'), '0/3 glasses');
    expect(subtitle('Call a friend'), '0/2 calls  ·  Weekly');
    expect(subtitle('Read'), startsWith('0/2 chapters  ·  Mon, Wed, Fri'));
    expect(find.descendant(of: card(), matching: find.textContaining('Body')), findsNothing);

    // VoiceOver still hears the category
    expect(find.bySemanticsLabel(RegExp('Drink Water, Body, 0/3 glasses')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('streaks show a flat flame, not an emoji', (tester) async {
    await habitProvider.updateProgressForDate(waterId, daysAgo(1), 3);
    await pumpHome(tester);

    final streak = find.byKey(Key('habitStreak_$waterId'));
    expect(find.descendant(of: streak, matching: find.byIcon(Icons.local_fire_department)), findsOneWidget);
    expect(find.descendant(of: streak, matching: find.text('1')), findsOneWidget);
    expect(find.textContaining('🔥'), findsNothing);
  });

  testWidgets('momentum shows its score with a rising arrow after a good week', (tester) async {
    for (var i = 1; i <= 7; i++) {
      await habitProvider.updateProgressForDate(waterId, daysAgo(i), 3);
    }
    await pumpHome(tester);

    final habit = habitProvider.getHabitById(waterId)!;
    expect(habit.momentum.rounded, greaterThan(10));
    final chip = find.byKey(Key('habitMomentum_$waterId'));
    expect(find.descendant(of: chip, matching: find.byIcon(Icons.bolt)), findsOneWidget);
    expect(find.descendant(of: chip, matching: find.text('${habit.momentum.rounded}')), findsOneWidget);
    expect(find.descendant(of: chip, matching: find.byIcon(CupertinoIcons.arrow_up)), findsOneWidget);
  });

  testWidgets('after a miss the flame turns to an amber outline with "Don\'t miss twice"', (tester) async {
    // Yesterday missed; the two days before were done
    await habitProvider.updateProgressForDate(waterId, daysAgo(3), 3);
    await habitProvider.updateProgressForDate(waterId, daysAgo(2), 3);
    await pumpHome(tester);

    final streak = find.byKey(Key('habitStreak_$waterId'));
    expect(find.descendant(of: streak, matching: find.text('2')), findsOneWidget);
    expect(find.descendant(of: streak, matching: find.byIcon(Icons.local_fire_department_outlined)),
        findsOneWidget);
    expect(find.byKey(Key('habitAtRisk_$waterId')), findsOneWidget);
    expect(find.text("Don't miss twice"), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Doing today clears it
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(Key('incrementHabit_$waterId')));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(Key('habitAtRisk_$waterId')), findsNothing);
    expect(find.descendant(of: streak, matching: find.byIcon(Icons.local_fire_department)), findsOneWidget);
  });

  testWidgets('a brand-new habit shows no momentum or streak yet', (tester) async {
    await pumpHome(tester);
    expect(find.byKey(Key('habitMomentum_$waterId')), findsNothing);
    expect(find.byKey(Key('habitStreak_$waterId')), findsNothing);
  });

  testWidgets('momentum and the at-risk streak are described to VoiceOver', (tester) async {
    final handle = tester.ensureSemantics();
    await habitProvider.updateProgressForDate(waterId, daysAgo(3), 3);
    await habitProvider.updateProgressForDate(waterId, daysAgo(2), 3);
    await pumpHome(tester);

    // The card reads as one element, so these are part of its label
    expect(find.bySemanticsLabel(RegExp(r'Momentum \d+, rising')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp("2 day streak, missed once, don't miss twice")), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the ring and the stepper change progress; done shows a check', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(Key('habitIcon_$waterId')));
    await tester.pumpAndSettle();
    expect(habitProvider.getHabitById(waterId)!.progress, 1);

    await tester.tap(find.byKey(Key('incrementHabit_$waterId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('incrementHabit_$waterId')));
    await tester.pumpAndSettle();
    expect(habitProvider.getHabitById(waterId)!.isCompleted, isTrue);
    expect(find.descendant(of: find.byKey(Key('habitIcon_$waterId')), matching: find.byIcon(Icons.check)),
        findsOneWidget);

    await tester.tap(find.byKey(Key('decrementHabit_$waterId')));
    await tester.pumpAndSettle();
    expect(habitProvider.getHabitById(waterId)!.progress, 2);
  });

  testWidgets("tapping the card opens the habit's page; Edit is in the swipe actions", (tester) async {
    await pumpHome(tester);

    await tester.tap(find.descendant(of: card(), matching: find.text('Drink Water')));
    await tester.pumpAndSettle();
    expect(find.byType(HabitDetailScreen), findsOneWidget);
    expect(find.byType(HabitEditorScreen), findsNothing);

    Navigator.of(tester.element(find.byType(HabitDetailScreen))).pop();
    await tester.pumpAndSettle();
    await swipeToEdit(tester, waterId);
    expect(find.byType(HabitEditorScreen), findsOneWidget);
    expect(find.text('Edit Habit'), findsOneWidget);
  });

  for (final width in [375.0, 402.0]) {
    testWidgets('at ${width.toInt()}pt, greyed-out buttons and the area around them never open the habit page',
        (tester) async {
      await pumpHome(tester, width: width);
      final card = tester.getRect(find.byKey(Key('habitCard_$waterId')));
      final minus = find.byKey(Key('decrementHabit_$waterId'));

      // Nothing logged yet, so - is greyed out
      await tester.tap(minus);
      await tester.pumpAndSettle();
      expect(find.byType(HabitDetailScreen), findsNothing);

      // Just right of +, at the card's edge, level with the stepper
      final plus = tester.getRect(find.byKey(Key('incrementHabit_$waterId')));
      await tester.tapAt(Offset(card.right - 3, plus.center.dy));
      await tester.pumpAndSettle();
      expect(find.byType(HabitDetailScreen), findsNothing);

      // Fill it up: now + is greyed out too
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(Key('incrementHabit_$waterId')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(Key('incrementHabit_$waterId')));
      await tester.pumpAndSettle();
      expect(find.byType(HabitDetailScreen), findsNothing);
      expect(habitProvider.getHabitById(waterId)!.progress, 3);

      // The name still opens the page
      await tester.tap(find.descendant(of: find.byKey(Key('habitCard_$waterId')), matching: find.text('Drink Water')));
      await tester.pumpAndSettle();
      expect(find.byType(HabitDetailScreen), findsOneWidget);
    });
  }

  testWidgets('quick taps all count: + is never locked while a save is running', (tester) async {
    await pumpHome(tester);
    final plus = find.byKey(Key('incrementHabit_$waterId'));

    // One frame between taps: no waiting for saves to finish
    for (var i = 0; i < 3; i++) {
      await tester.tap(plus);
      await tester.pump();
    }
    expect(find.descendant(of: card(), matching: find.textContaining('3/3 glasses')), findsOneWidget);

    await tester.pumpAndSettle();
    final saved = await tester.runAsync(() => get<LocalHabitDataSource>().getHabits());
    expect(saved!.single.progress, 3);
  });

  testWidgets('swiping left reveals Edit and Delete; Delete asks first', (tester) async {
    await pumpHome(tester);

    await tester.drag(card(), const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('editHabit_$waterId')), findsOneWidget);

    await tester.tap(find.byKey(Key('deleteHabit_$waterId')));
    await tester.pumpAndSettle();
    expect(find.text('Delete "Drink Water"?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmDeleteHabit')));
    await tester.pumpAndSettle();

    expect(habitProvider.habits, isEmpty);
  });

  testWidgets('Edit and Delete are offered to VoiceOver as actions', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpHome(tester);

    final data = tester.getSemantics(card()).getSemanticsData();
    final labels = data.customSemanticsActionIds!
        .map((id) => CustomSemanticsAction.getAction(id)!.label)
        .toSet();
    expect(labels, containsAll(['Edit', 'Delete']));
    handle.dispose();
  });

  testWidgets('the Edit Habit screen has a Delete Habit button at the bottom', (tester) async {
    await pumpHome(tester);
    await swipeToEdit(tester, waterId);

    final delete = find.byKey(const Key('deleteHabitFromForm'));
    await tester.scrollUntilVisible(delete, 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmDeleteHabit')));
    await tester.pumpAndSettle();

    expect(habitProvider.habits, isEmpty);
    expect(find.byType(HabitEditorScreen), findsNothing);
  });

  testWidgets('a new habit has no Delete button', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: get<ThemeProvider>()),
        ChangeNotifierProvider<HabitProvider>.value(value: habitProvider),
        ChangeNotifierProvider<CategoryProvider>.value(value: get<CategoryProvider>()),
        ChangeNotifierProvider<SettingsProvider>.value(value: get<SettingsProvider>()),
      ],
      child: const MaterialApp(home: AddHabitScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('deleteHabitFromForm')), findsNothing);
  });

  testWidgets('a failed save shows an error with Retry on the Habits screen', (tester) async {
    final repository = FailingHabitRepository(get<LocalHabitDataSource>());
    habitProvider = HabitProvider(
      getHabitsUseCase: GetHabitsUseCase(repository),
      createHabitUseCase: CreateHabitUseCase(repository),
      updateHabitUseCase: UpdateHabitUseCase(repository),
      deleteHabitUseCase: DeleteHabitUseCase(repository),
    );
    await tester.runAsync(habitProvider.loadHabits);
    repository.failSaves = true;
    await pumpHome(tester);

    await tester.tap(find.byKey(Key('incrementHabit_$waterId')));
    await tester.pumpAndSettle();

    expect(find.textContaining("Couldn't update Drink Water"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(habitProvider.getHabitById(waterId)!.progress, 0);
  });
}
