import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/domain/entities/habit_category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/screens/add_habit_screen.dart';
import 'package:atomic_momentum/screens/calendar_screen.dart';
import 'package:atomic_momentum/screens/settings_screen.dart';

void main() {
  late HabitProvider habitProvider;

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    habitProvider = get<HabitProvider>();
  });

  tearDown(() async {
    await resetDependencies();
  });

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    // Tall surface so whole forms render without scrolling
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: get<ThemeProvider>()),
        ChangeNotifierProvider<HabitProvider>.value(value: habitProvider),
        ChangeNotifierProvider<CategoryProvider>.value(value: get<CategoryProvider>()),
        ChangeNotifierProvider<SettingsProvider>.value(value: get<SettingsProvider>()),
      ],
      child: MaterialApp(home: screen),
    ));
    await tester.pumpAndSettle();
  }

  const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  group('Add habit: reset day', () {
    Future<void> chooseFrequency(WidgetTester tester, String label) async {
      await tester.tap(find.byType(DropdownButtonFormField<ResetFrequency>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    testWidgets('is hidden for daily habits and defaults to today for weekly', (tester) async {
      await pumpScreen(tester, const AddHabitScreen());

      expect(find.byKey(const Key('resetDayTile')), findsNothing);

      await chooseFrequency(tester, 'Weekly');

      final todayName = weekdays[DateTime.now().weekday - 1];
      expect(find.text('Resets every $todayName'), findsOneWidget);
    });

    testWidgets('can be changed with the pop-out calendar and is saved', (tester) async {
      await pumpScreen(tester, const AddHabitScreen());
      await chooseFrequency(tester, 'Monthly');

      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);

      // Pick a day in the month the picker opens on, then confirm
      final pickDay = DateTime.now().day == 10 ? 11 : 10;
      await tester.tap(find.text('$pickDay'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Resets on the ${pickDay}th of each month'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'Budget review');
      await tester.enterText(find.byType(TextFormField).at(1), '1');
      await tester.tap(find.text('Add Habit'));
      await tester.pumpAndSettle();

      final saved = habitProvider.habits.single;
      expect(saved.resetFrequency, ResetFrequency.monthly);
      expect(saved.resetAnchor.day, pickDay);
    });
  });

  group('Calendar: editing a day', () {
    testWidgets('adding to the selected day updates history and streak', (tester) async {
      await habitProvider.createHabit(const CreateHabitParams(
        name: 'Journal',
        target: 1,
        color: HabitColor.indigo,
        category: HabitCategory.mind,
      ));
      final id = habitProvider.habits.single.id;

      await pumpScreen(tester, const CalendarScreen());

      expect(find.text('Logged: 0/1'), findsOneWidget);
      await tester.tap(find.byKey(Key('incrementDay_$id')));
      await tester.pumpAndSettle();

      final habit = habitProvider.getHabitById(id)!;
      expect(habit.progress, 1);
      expect(habit.streak.current, 1);
      expect(find.text('Logged: 1/1'), findsOneWidget);

      await tester.tap(find.byKey(Key('decrementDay_$id')));
      await tester.pumpAndSettle();
      expect(habitProvider.getHabitById(id)!.streak.current, 0);
    });
  });

  group('Settings: streak warnings', () {
    testWidgets('shows the default and persists changes', (tester) async {
      await pumpScreen(tester, const SettingsScreen());

      expect(find.text('Streak warnings'), findsOneWidget);
      expect(find.text('4 hours before'), findsOneWidget);

      await tester.tap(find.byKey(const Key('streakWarningLeadTime')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 day before').last);
      await tester.pumpAndSettle();

      expect(get<SettingsProvider>().streakWarnings.leadTime, const Duration(hours: 24));

      await tester.tap(find.byKey(const Key('streakWarningsSwitch')));
      await tester.pumpAndSettle();
      expect(get<SettingsProvider>().streakWarnings.enabled, isFalse);
    });
  });
}
