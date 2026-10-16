import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
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

void main() {
  late HabitProvider habitProvider;
  late String waterId;

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

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
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

  testWidgets('the card is a compact single row that fits a 375pt phone', (tester) async {
    await pumpHome(tester);

    final rect = tester.getRect(card());
    expect(rect.height, lessThanOrEqualTo(80));
    expect(rect.right, lessThanOrEqualTo(375));
    expect(find.descendant(of: card(), matching: find.text('Drink Water')), findsOneWidget);
    expect(find.descendant(of: card(), matching: find.textContaining('0/3 glasses')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('streaks show a flat flame, not an emoji', (tester) async {
    final now = DateTime.now();
    await habitProvider.updateProgressForDate(waterId, DateTime(now.year, now.month, now.day - 1), 3);
    await pumpHome(tester);

    final streak = find.byKey(Key('habitStreak_$waterId'));
    expect(find.descendant(of: streak, matching: find.byIcon(Icons.local_fire_department)), findsOneWidget);
    expect(find.descendant(of: streak, matching: find.text('1')), findsOneWidget);
    expect(find.textContaining('🔥'), findsNothing);
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
    expect(find.text('Delete Habit'), findsOneWidget);
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

    expect(find.textContaining('Failed to update Drink Water'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(habitProvider.getHabitById(waterId)!.progress, 0);
  });
}
