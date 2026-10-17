import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/copy/greetings.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/theme/app_palette.dart';
import 'package:atomic_momentum/core/theme/ios_theme.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/screens/home_screen.dart';
import 'package:atomic_momentum/screens/settings_screen.dart';

/// Settings → "My day starts at" moves the Habits greetings to the person's
/// own day, e.g. for night shifts.
void main() {
  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
  });

  tearDown(resetDependencies);

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: get<ThemeProvider>()),
        ChangeNotifierProvider<HabitProvider>.value(value: get<HabitProvider>()),
        ChangeNotifierProvider<CategoryProvider>.value(value: get<CategoryProvider>()),
        ChangeNotifierProvider<SettingsProvider>.value(value: get<SettingsProvider>()),
      ],
      child: MaterialApp(
        theme: IOSTheme.material(AppPalette.light).copyWith(platform: TargetPlatform.iOS),
        home: screen,
      ),
    ));
    await tester.pumpAndSettle();
  }

  String greeting(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('habitsGreeting'))).data!;

  /// A day start that puts "now" [hoursIn] hours into the person's day.
  TimeOfDay startingHoursAgo(int hoursIn) {
    final now = clock.now();
    final start = DateTime(now.year, now.month, now.day, now.hour - hoursIn, now.minute);
    return TimeOfDay(hour: start.hour, minute: start.minute);
  }

  testWidgets('the greeting follows the day start, and changes with it', (tester) async {
    final settings = get<SettingsProvider>();
    // Just woken up, whatever the real time: a morning greeting
    await tester.runAsync(() => settings.setDayStart(startingHoursAgo(0)));
    await pump(tester, const HomeScreen());
    expect(Greetings.lines[DayPart.morning], contains(greeting(tester)));

    // Ten hours into the day: afternoon, straight away
    await tester.runAsync(() => settings.setDayStart(startingHoursAgo(10)));
    await tester.pumpAndSettle();
    expect(Greetings.lines[DayPart.afternoon], contains(greeting(tester)));
  });

  testWidgets('Settings shows the day start and changes it with the time picker', (tester) async {
    await pump(tester, const SettingsScreen());
    expect(find.text('My day starts at'), findsOneWidget);
    expect(find.text('5:00 AM'), findsOneWidget);

    await tester.tap(find.byKey(const Key('dayStartSetting')));
    await tester.pumpAndSettle();
    // Spin the hour wheel forward, then Done
    await tester.drag(find.text('5').last, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pickerDone')));
    await tester.pumpAndSettle();

    final saved = get<SettingsProvider>().dayStart;
    expect(saved.hour, greaterThan(5));
    expect(find.text(saved.format(tester.element(find.byType(SettingsScreen)))), findsOneWidget);
  });
}
