import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/notification_service.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/reminder_settings.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/screens/home_screen.dart';

import '../simulation/simulated_notification_center.dart';

/// The notification simulator stands in for the Habits screen's midnight
/// timer; this checks the real timer: left open across midnight, the app
/// moves its two-week window of reminders on by a day.
void main() {
  late SimulatedNotificationCenter center;

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    center = SimulatedNotificationCenter()..now = () => clock.now();
    NotificationService.debugOverride(plugin: center);
    await initializeDependencies(seedDefaultHabit: false);
  });

  tearDown(() async {
    NotificationService.debugReset();
    await resetDependencies();
  });

  testWidgets('crossing midnight with the app open rolls the reminders on a day', (tester) async {
    final habits = get<HabitProvider>();
    await tester.runAsync(() => habits.createHabit(CreateHabitParams(
          name: 'Read',
          target: 1,
          color: HabitColor.blue,
          categoryId: BuiltInCategoryIds.mind,
          reminder: ReminderSettings.smart(time: const TimeOfDay(hour: 9, minute: 0)),
        )));

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: get<ThemeProvider>()),
        ChangeNotifierProvider<HabitProvider>.value(value: habits),
        ChangeNotifierProvider<CategoryProvider>.value(value: get<CategoryProvider>()),
        ChangeNotifierProvider<SettingsProvider>.value(value: get<SettingsProvider>()),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ));
    await tester.pumpAndSettle();

    // Reminders only: the week in review's notice can come after the last one
    DateTime lastReminder() =>
        center.pending.values.where((r) => r.isReminder).map((r) => r.at).reduce((a, b) => a.isAfter(b) ? a : b);
    final before = lastReminder();

    final now = clock.now();
    final pastMidnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 5).difference(now);
    await tester.pump(pastMidnight);
    await tester.pumpAndSettle();

    final after = lastReminder();
    expect(DateTime(after.year, after.month, after.day), DateTime(before.year, before.month, before.day + 1));
  });
}
