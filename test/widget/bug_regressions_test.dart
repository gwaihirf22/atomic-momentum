import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/theme/ios_colors.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/reminder_settings.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/main.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/screens/add_habit_screen.dart';
import 'package:atomic_momentum/screens/home_screen.dart';

void main() {
  late HabitProvider habitProvider;

  Future<void> setUpApp({Map<String, Object> prefs = const {}}) async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues(prefs);
    await initializeDependencies(seedDefaultHabit: false);
    habitProvider = get<HabitProvider>();
  }

  tearDown(() async {
    await resetDependencies();
  });

  // Setup runs in setUp (real async), not inside testWidgets (fake async),
  // where platform-channel futures never complete
  group('with an empty app', () {
    setUp(() => setUpApp());

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
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

  testWidgets('turning a reminder off while editing actually disables it', (tester) async {
    await tester.runAsync(() => habitProvider.createHabit(CreateHabitParams(
      name: 'Vitamins',
      target: 1,
      color: HabitColor.green,
      categoryId: BuiltInCategoryIds.body,
      reminder: ReminderSettings.daily(time: const TimeOfDay(hour: 8, minute: 30)),
    )));
    final habit = habitProvider.habits.single;
    expect(habit.hasReminder, isTrue);

    await pumpScreen(tester, AddHabitScreen(editHabit: habit));
    await tester.tap(find.byKey(const Key('reminderSwitch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update Habit'));
    await tester.pumpAndSettle();

    final updated = habitProvider.getHabitById(habit.id)!;
    expect(updated.hasReminder, isFalse);
    // The chosen time is kept so turning it back on restores it
    expect(updated.reminder?.time, const TimeOfDay(hour: 8, minute: 30));
  });

  testWidgets('habit card controls are at least 44pt tap targets', (tester) async {
    await tester.runAsync(() => habitProvider.createHabit(const CreateHabitParams(
      name: 'Floss',
      target: 1,
      color: HabitColor.teal,
      categoryId: BuiltInCategoryIds.body,
    )));
    final id = habitProvider.habits.single.id;

    await pumpScreen(tester, const HomeScreen());

    for (final key in ['habitIcon_$id', 'decrementHabit_$id', 'incrementHabit_$id']) {
      final size = tester.getSize(find.byKey(Key(key)));
      expect(size.width, greaterThanOrEqualTo(44), reason: '$key width');
      expect(size.height, greaterThanOrEqualTo(44), reason: '$key height');
    }
  });
  });

  group('with dark mode saved', () {
    setUp(() => setUpApp(prefs: {'isDarkMode': true}));

  testWidgets('dark mode applies to Material screens', (tester) async {
    await tester.pumpWidget(const MomentumApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    final calendarContext = tester.element(find.byKey(const Key('calendarDayTitle')));
    expect(Theme.of(calendarContext).brightness, Brightness.dark);
    expect(Theme.of(calendarContext).scaffoldBackgroundColor, IOSColors.systemBackgroundDark);

    // Day numbers must be readable on the dark background
    final dayText = tester.widget<Text>(find.text('${DateTime.now().day == 15 ? 14 : 15}').first);
    expect(dayText.style?.color, isNot(Colors.black87));
  });
  });
}
