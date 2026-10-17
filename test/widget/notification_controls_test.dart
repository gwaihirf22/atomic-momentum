import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/habit_goal.dart';
import 'package:atomic_momentum/domain/entities/habit_notify.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/screens/add_habit_screen.dart';
import 'package:atomic_momentum/screens/settings_screen.dart';

/// Notification controls: for all habits in Settings, for one in its editor.
void main() {
  late HabitProvider habits;

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    habits = get<HabitProvider>();
  });

  tearDown(resetDependencies);

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: get<ThemeProvider>()),
        ChangeNotifierProvider<HabitProvider>.value(value: habits),
        ChangeNotifierProvider<CategoryProvider>.value(value: get<CategoryProvider>()),
        ChangeNotifierProvider<SettingsProvider>.value(value: get<SettingsProvider>()),
      ],
      child: MaterialApp(home: home),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  SettingsProvider settings() => get<SettingsProvider>();

  group('Settings', () {
    testWidgets('the default sound is chosen and saved', (tester) async {
      await pump(tester, const SettingsScreen());
      expect(find.descendant(of: find.byKey(const Key('notifySoundSetting')), matching: find.text('Chime')), findsOneWidget);
      await tap(tester, 'notifySoundSetting');
      await tap(tester, 'notifySound_soft');
      expect(settings().notifySound, NotifySound.soft);
    });

    testWidgets('quiet hours: off to start; on shows From and To', (tester) async {
      await pump(tester, const SettingsScreen());
      expect(find.byKey(const Key('quietStart')), findsNothing);
      await tap(tester, 'quietHoursSwitch');
      expect(settings().quietHours.enabled, isTrue);
      expect(find.byKey(const Key('quietStart')), findsOneWidget);
      expect(find.byKey(const Key('quietEnd')), findsOneWidget);
    });

    testWidgets('time-sensitive alerts can be turned off for all habits', (tester) async {
      await pump(tester, const SettingsScreen());
      await tap(tester, 'allowTimeSensitiveSwitch');
      expect(settings().allowTimeSensitive, isFalse);
    });
  });

  group('the editor', () {
    Future<String> addHabit({HabitGoal goal = HabitGoal.build}) async {
      await habits.createHabit(CreateHabitParams(
        name: goal == HabitGoal.build ? 'Read' : 'Smoking',
        target: goal == HabitGoal.quit ? 0 : 1,
        color: HabitColor.teal,
        categoryId: BuiltInCategoryIds.mind,
        goal: goal,
      ));
      return habits.habits.single.id;
    }

    testWidgets("a habit's own sound, time-sensitive and streak warnings are saved", (tester) async {
      final id = await addHabit();
      await pump(tester, AddHabitScreen(editHabit: habits.getHabitById(id)));
      // Editing a habit without a reminder: turn it on to see its sound
      await tap(tester, 'reminderSwitch');
      expect(find.text('Default (Chime)'), findsOneWidget);
      await tap(tester, 'habitSound');
      await tap(tester, 'habitSound_ding');
      await tap(tester, 'habitTimeSensitive');
      await tap(tester, 'habitStreakWarnings');
      await tap(tester, 'saveHabitButton');

      final notify = habits.getHabitById(id)!.notify;
      expect(notify.sound, NotifySound.ding);
      expect(notify.timeSensitive, isTrue);
      expect(notify.streakWarnings, isFalse);
    });

    testWidgets('time-sensitive only shows when Settings allows it', (tester) async {
      await settings().setAllowTimeSensitive(false);
      await pump(tester, const AddHabitScreen());
      expect(find.byKey(const Key('habitTimeSensitive')), findsNothing);
      expect(find.byKey(const Key('habitSound')), findsOneWidget);
    });

    testWidgets('a habit being broken has no streak-warning switch', (tester) async {
      final id = await addHabit(goal: HabitGoal.quit);
      await pump(tester, AddHabitScreen(editHabit: habits.getHabitById(id)));
      expect(find.byKey(const Key('habitStreakWarnings')), findsNothing);
    });
  });
}
