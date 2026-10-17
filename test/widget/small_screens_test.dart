import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/core/copy/greetings.dart';
import 'package:atomic_momentum/domain/entities/momentum.dart';
import 'package:atomic_momentum/presentation/widgets/large_title_scaffold.dart';
import 'package:atomic_momentum/presentation/widgets/momentum_ring.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/theme/app_palette.dart';
import 'package:atomic_momentum/core/theme/ios_theme.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/reminder_settings.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/entities/two_minute_version.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/presentation/widgets/category_icons.dart';
import 'package:atomic_momentum/presentation/widgets/color_picker.dart';
import 'package:atomic_momentum/screens/add_habit_screen.dart';
import 'package:atomic_momentum/screens/calendar_screen.dart';
import 'package:atomic_momentum/screens/categories_screen.dart';
import 'package:atomic_momentum/screens/home_screen.dart';
import 'package:atomic_momentum/screens/settings_screen.dart';

import '../helpers/real_fonts.dart';

/// Every screen on the smallest supported iPhone (the SE, 375pt wide) and
/// just above the habit card's breakpoint, at the default text size and at
/// iOS's largest standard size, drawn with real fonts: nothing may overflow
/// and no text may be cut off. At an Accessibility size, nothing may break.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HabitProvider habits;

  setUpAll(loadRealFonts);

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    habits = get<HabitProvider>();
    await habits.loadHabits();
    await habits.addSampleHabits();

    final now = DateTime.now();
    DateTime daysAgo(int n) => DateTime(now.year, now.month, now.day - n);

    // A long name, missed yesterday (so "Don't miss twice" shows), with a
    // two-minute version (so the "2 min" button shows too)
    await habits.createHabit(CreateHabitParams(
      name: 'Drink water every morning',
      target: 8,
      units: 'glasses',
      color: HabitColor.blue,
      categoryId: BuiltInCategoryIds.body,
      reminder: ReminderSettings.smart(time: const TimeOfDay(hour: 9, minute: 0)),
      twoMinute: const TwoMinuteVersion(description: 'Fill one glass and take a sip', minimum: 1),
    ));
    final water = habits.habits.firstWhere((h) => h.name.startsWith('Drink water every')).id;
    await habits.updateProgressForDate(water, daysAgo(3), 8);
    await habits.updateProgressForDate(water, daysAgo(2), 8);

    // Rest days, and custom reminder days
    await habits.createHabit(const CreateHabitParams(
      name: 'Stretch',
      target: 1,
      units: 'session',
      color: HabitColor.teal,
      categoryId: BuiltInCategoryIds.body,
      scheduledWeekdays: [1, 3, 5],
      reminder: ReminderSettings(time: TimeOfDay(hour: 7, minute: 0), enabled: true, daysOfWeek: [1, 3, 5]),
    ));

    // A long category name
    await get<CategoryProvider>().add(
      name: 'Personal growth',
      iconKey: CategoryIcons.library.keys.first,
      colorValue: HabitColor.indigo.value,
    );
  });

  tearDown(resetDependencies);

  Future<void> pump(WidgetTester tester, Widget screen,
      {required double width, required double scale, AppPalette palette = AppPalette.light}) async {
    // Tall, so whole screens build; the width is what's under test
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = scale * sfWidthAllowance;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: get<ThemeProvider>()),
        ChangeNotifierProvider<HabitProvider>.value(value: habits),
        ChangeNotifierProvider<CategoryProvider>.value(value: get<CategoryProvider>()),
        ChangeNotifierProvider<SettingsProvider>.value(value: get<SettingsProvider>()),
      ],
      child: MaterialApp(
        theme: IOSTheme.material(palette).copyWith(platform: TargetPlatform.iOS),
        home: screen,
      ),
    ));
    await tester.pumpAndSettle();
  }

  void expectNothingCutOff(WidgetTester tester, String where, {bool checkTruncation = true}) {
    final error = tester.takeException();
    expect(error, isNull, reason: '$where: $error');
    if (!checkTruncation) return;
    final cut = [
      for (final p in tester.allRenderObjects.whereType<RenderParagraph>())
        if (p.didExceedMaxLines) '"${p.text.toPlainText()}"',
    ];
    expect(cut, isEmpty, reason: '$where: cut off: ${cut.join(', ')}');
  }

  final screens = <String, Widget Function()>{
    'Habits': () => const HomeScreen(),
    'Calendar': () => const CalendarScreen(),
    'Settings': () => const SettingsScreen(),
    'New habit': () => const AddHabitScreen(),
    'Edit habit (custom reminder days)': () =>
        AddHabitScreen(editHabit: habits.habits.firstWhere((h) => h.name == 'Stretch')),
    'Edit habit (two-minute version)': () =>
        AddHabitScreen(editHabit: habits.habits.firstWhere((h) => h.name.startsWith('Drink water every'))),
    'Categories': () => const CategoriesScreen(),
  };

  for (final width in [375.0, 390.0]) {
    for (final scale in [1.0, 1.35]) {
      final setting = '${width.toInt()}pt, text ${(scale * 100).round()}%';

      for (final entry in screens.entries) {
        testWidgets('${entry.key} at $setting', (tester) async {
          await pump(tester, entry.value(), width: width, scale: scale);
          expectNothingCutOff(tester, '${entry.key} at $setting');
        });
      }

      testWidgets('Calendar, a past day, at $setting', (tester) async {
        await pump(tester, const CalendarScreen(), width: width, scale: scale);
        final now = DateTime.now();
        final day = now.day > 2 ? now.day - 2 : now.day;
        await tester.tap(find.byKey(Key('calendarDay_${now.year}-${now.month}-$day')));
        await tester.pumpAndSettle();
        expectNothingCutOff(tester, 'Calendar past day at $setting');
      });

      testWidgets('Category editor at $setting', (tester) async {
        await pump(tester, const CategoriesScreen(), width: width, scale: scale);
        await tester.tap(find.text('Personal growth').first);
        await tester.pumpAndSettle();
        expectNothingCutOff(tester, 'Category editor at $setting');
      });

      testWidgets('Color sheet at $setting', (tester) async {
        await pump(
          tester,
          Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showColorPickerSheet(context, selectedValue: HabitColor.blue.value),
                child: const Text('open'),
              ),
            ),
          ),
          width: width,
          scale: scale,
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expectNothingCutOff(tester, 'Color sheet at $setting');
      });

      testWidgets('Reset day picker at $setting', (tester) async {
        await pump(tester, const AddHabitScreen(), width: width, scale: scale);
        await tester.tap(find.byKey(Key('frequency_${ResetFrequency.monthly.name}')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('changeStartDate')));
        await tester.pumpAndSettle();
        expectNothingCutOff(tester, 'Reset day picker at $setting');
      });
    }
  }

  // Colors don't change sizes, but each theme builds its own widgets' colors
  for (final palette in [AppPalette.sepia, AppPalette.dark]) {
    for (final name in ['Habits', 'Calendar', 'Settings', 'New habit']) {
      testWidgets('$name in ${palette.theme.name} at 375pt, text 135%', (tester) async {
        await pump(tester, screens[name]!(), width: 375, scale: 1.35, palette: palette);
        expect(AppPalette.of(tester.element(find.byType(Scaffold).first)), palette);
        expectNothingCutOff(tester, '$name in ${palette.theme.name}');
      });
    }
  }

  testWidgets('the Calendar weekday labels fit their row at 135% text', (tester) async {
    await pump(tester, const CalendarScreen(), width: 375, scale: 1.35);
    final row = tester.widget<TableCalendar<Habit>>(find.byType(TableCalendar<Habit>)).daysOfWeekHeight;
    final label = tester.getSize(find.text('Mon').first);
    expect(label.height, lessThanOrEqualTo(row));
  });

  testWidgets('every greeting fits the Habits header at 375pt and 135% text', (tester) async {
    tester.view.physicalSize = const Size(375, 2400);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.35 * sfWidthAllowance;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    for (final line in Greetings.lines.values.expand((l) => l)) {
      await tester.pumpWidget(MaterialApp(
        theme: IOSTheme.material(AppPalette.light).copyWith(platform: TargetPlatform.iOS),
        home: Scaffold(
          body: LargeTitleHeader(
            eyebrow: 'WEDNESDAY, SEPTEMBER 30',
            title: line,
            accessory: const MomentumRing(momentum: Momentum(score: 100, trend: 5)),
          ),
        ),
      ));
      expectNothingCutOff(tester, 'greeting "$line"');
    }
  });

  testWidgets('a long greeting steps down in size to fit two lines; a short one stays large', (tester) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Future<double> sizeOf(String line) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LargeTitleHeader(
            title: line,
            titleKey: const Key('t'),
            accessory: const MomentumRing(momentum: Momentum(score: 72, trend: 2)),
          ),
        ),
      ));
      return tester.widget<Text>(find.byKey(const Key('t'))).style!.fontSize!;
    }

    expect(await sizeOf('Still up?'), LargeTitleHeader.titleSizes.first);
    final long = await sizeOf('Quiet hours, big wins, and an early night ahead');
    expect(long, lessThan(LargeTitleHeader.titleSizes.first));
    // Two lines at most, unless even the smallest size needs more (then it wraps)
    final lines = tester.getSize(find.byKey(const Key('t'))).height / (long * 1.15);
    if (long > LargeTitleHeader.titleSizes.last) {
      expect(lines, lessThanOrEqualTo(LargeTitleHeader.maxTitleLines + 0.1));
    }
    expectNothingCutOff(tester, 'long title');
  });

  // Accessibility sizes: layouts may reflow, but nothing may break
  for (final entry in screens.entries) {
    testWidgets('${entry.key} at 375pt, Accessibility text (200%)', (tester) async {
      await pump(tester, entry.value(), width: 375, scale: 2.0);
      expectNothingCutOff(tester, '${entry.key} at 200%', checkTruncation: false);
    });
  }
}
