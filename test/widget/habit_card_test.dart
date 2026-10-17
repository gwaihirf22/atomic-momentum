import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
import 'package:atomic_momentum/screens/home_screen.dart';

import '../helpers/failing_habit_repository.dart';
import '../helpers/real_fonts.dart';

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

  testWidgets('tapping the card opens Edit Habit', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.descendant(of: card(), matching: find.text('Drink Water')));
    await tester.pumpAndSettle();

    expect(find.byType(AddHabitScreen), findsOneWidget);
    expect(find.text('Edit Habit'), findsOneWidget);
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
    await tester.tap(find.descendant(of: card(), matching: find.text('Drink Water')));
    await tester.pumpAndSettle();

    final delete = find.byKey(const Key('deleteHabitFromForm'));
    await tester.scrollUntilVisible(delete, 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmDeleteHabit')));
    await tester.pumpAndSettle();

    expect(habitProvider.habits, isEmpty);
    expect(find.byType(AddHabitScreen), findsNothing);
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
