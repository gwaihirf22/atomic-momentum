import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/presentation/widgets/color_picker.dart';
import 'package:atomic_momentum/screens/add_habit_screen.dart';
import 'package:atomic_momentum/screens/settings_screen.dart';

/// Screens on iPhone use iOS controls (Material stays on Android, which the
/// other widget tests cover, since tests default to Android).
void main() {
  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
  });

  tearDown(() async {
    await resetDependencies();
  });

  Future<void> pumpOnIPhone(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(402, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: get<ThemeProvider>()),
        ChangeNotifierProvider<HabitProvider>.value(value: get<HabitProvider>()),
        ChangeNotifierProvider<CategoryProvider>.value(value: get<CategoryProvider>()),
        ChangeNotifierProvider<SettingsProvider>.value(value: get<SettingsProvider>()),
      ],
      child: MaterialApp(theme: ThemeData(platform: TargetPlatform.iOS), home: screen),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Settings is an inset grouped list with iOS switches; tapping a row toggles it', (tester) async {
    await pumpOnIPhone(tester, const SettingsScreen());

    expect(find.byType(CupertinoListSection), findsWidgets);
    expect(find.byType(SwitchListTile), findsNothing);
    final warnings = find.byKey(const Key('streakWarningsSwitch'));
    expect(find.descendant(of: warnings, matching: find.byType(CupertinoSwitch)), findsOneWidget);

    await tester.tap(find.text('Streak warnings'));
    await tester.pumpAndSettle();
    expect(get<SettingsProvider>().streakWarnings.enabled, isFalse);
  });

  testWidgets('Add Habit has an iOS navigation bar with Cancel', (tester) async {
    await pumpOnIPhone(tester, const AddHabitScreen());

    expect(find.byType(CupertinoNavigationBar), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('New Habit'), findsOneWidget);
    expect(find.byKey(const Key('cancelHabitForm')), findsOneWidget);
  });

  testWidgets("the reminder switch's label is part of it: tapping the label toggles it", (tester) async {
    await pumpOnIPhone(tester, const AddHabitScreen());
    final reminder = find.byKey(const Key('reminderSwitch'));
    await tester.scrollUntilVisible(reminder, 200, scrollable: find.byType(Scrollable).first);

    // New habits remind by default; tapping the label turns it off
    expect(tester.widget<SwitchListTile>(reminder).value, isTrue);
    await tester.tap(find.text('Remind me about this habit'));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(reminder).value, isFalse);
  });

  testWidgets('deleting a habit asks with an iOS alert', (tester) async {
    final habits = get<HabitProvider>();
    await habits.createHabit(const CreateHabitParams(
      name: 'Read',
      target: 1,
      color: HabitColor.teal,
      categoryId: BuiltInCategoryIds.mind,
    ));
    await pumpOnIPhone(tester, AddHabitScreen(editHabit: habits.habits.single));

    final delete = find.byKey(const Key('deleteHabitFromForm'));
    await tester.scrollUntilVisible(delete, 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(delete);
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.text('Delete "Read"?'), findsOneWidget);
  });

  testWidgets('the color sheet uses a segmented control, and swiping does not change tabs', (tester) async {
    await pumpOnIPhone(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showColorPickerSheet(context, selectedValue: HabitColor.blue.value),
            child: const Text('open'),
          ),
        ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoSlidingSegmentedControl<int>), findsOneWidget);
    final tabs = tester.widget<TabBarView>(find.byType(TabBarView));
    expect(tabs.physics, isA<NeverScrollableScrollPhysics>());
  });
}
