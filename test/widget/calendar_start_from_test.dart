import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/habit_goal.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/screens/calendar_screen.dart';

import '../helpers/real_fonts.dart';

/// Calendar on a day before a habit was added: grayed, last, and it can be
/// started from that day.
void main() {
  late HabitProvider habits;
  late String read;
  late String walk;
  late String smoking;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  // A day this month before today (the Calendar opens on this month)
  final day = DateTime(today.year, today.month, today.day == 1 ? 1 : today.day - 1);

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    habits = get<HabitProvider>();
    // Walk since last month; Read and Smoking added today
    await withClock(
      Clock.fixed(DateTime(today.year, today.month - 1, 1)),
      () => habits.createHabit(const CreateHabitParams(
        name: 'Walk',
        target: 1,
        color: HabitColor.green,
        categoryId: BuiltInCategoryIds.body,
      )),
    );
    await habits.createHabit(const CreateHabitParams(
      name: 'Read',
      target: 1,
      color: HabitColor.teal,
      categoryId: BuiltInCategoryIds.mind,
    ));
    await habits.createHabit(const CreateHabitParams(
      name: 'Smoking',
      target: 0,
      color: HabitColor.red,
      categoryId: BuiltInCategoryIds.body,
      goal: HabitGoal.quit,
    ));
    String id(String name) => habits.habits.firstWhere((h) => h.name == name).id;
    read = id('Read');
    walk = id('Walk');
    smoking = id('Smoking');
  });

  tearDown(resetDependencies);

  Future<void> pump(WidgetTester tester, {double width = 390}) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: get<ThemeProvider>()),
        ChangeNotifierProvider<HabitProvider>.value(value: habits),
        ChangeNotifierProvider<CategoryProvider>.value(value: get<CategoryProvider>()),
        ChangeNotifierProvider<SettingsProvider>.value(value: get<SettingsProvider>()),
      ],
      child: const MaterialApp(home: Scaffold(body: CalendarScreen())),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('calendarDay_${day.year}-${day.month}-${day.day}')));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  testWidgets('habits added later are listed last, grayed, and not counted', (tester) async {
    if (day == today) return; // the 1st: no earlier day this month
    await pump(tester);
    expect(find.byKey(Key('dayHabit_$walk')), findsOneWidget);
    expect(find.byKey(Key('dayHabit_$read')), findsNothing);
    expect(find.byKey(Key('notStarted_$read')), findsOneWidget);
    expect(find.textContaining('Added'), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.byKey(Key('dayHabit_$walk'))).dy,
      lessThan(tester.getTopLeft(find.byKey(Key('notStarted_$read'))).dy),
    );
    expect(tester.widget<Text>(find.byKey(const Key('calendarDayDetail'))).data, '0 of 1 done');
  });

  testWidgets('"Start from this day" asks first; Cancel leaves it, confirming counts it from then', (tester) async {
    if (day == today) return;
    await pump(tester);
    await tap(tester, 'startFrom_$read');
    expect(find.textContaining('count as missed until you log them'), findsOneWidget);
    await tap(tester, 'startFromCancel');
    expect(find.byKey(Key('notStarted_$read')), findsOneWidget);

    await tap(tester, 'startFrom_$read');
    await tap(tester, 'startFromConfirm');
    expect(habits.getHabitById(read)!.trackedFrom, day);
    expect(find.byKey(Key('dayHabit_$read')), findsOneWidget, reason: 'ready to log that day');
    expect(find.textContaining('now counts from'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('calendarDayDetail'))).data, '0 of 2 done');

    await tap(tester, 'incrementDay_$read');
    expect(habits.getHabitById(read)!.getProgressForDate(day), 1);
  });

  testWidgets('a habit being broken: the days since count as clean', (tester) async {
    if (day == today) return;
    await pump(tester);
    await tap(tester, 'startFrom_$smoking');
    expect(find.textContaining('counts as clean unless you log slips'), findsOneWidget);
    await tap(tester, 'startFromConfirm');
    final quit = habits.getHabitById(smoking)!;
    expect(quit.wasCompletedOnDate(day), isTrue);
    expect(quit.streak.current, greaterThanOrEqualTo(2));
  });

  group('on an iPhone SE at large text', () {
    setUpAll(loadRealFonts);

    testWidgets('a grayed row and its button fit, nothing cut off', (tester) async {
      if (day == today) return;
      tester.platformDispatcher.textScaleFactorTestValue = 1.35 * sfWidthAllowance;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester, width: 375);
      expect(tester.takeException(), isNull);
      expect(find.byKey(Key('notStarted_$read')), findsOneWidget);
      final cut = [
        for (final p in tester.allRenderObjects.whereType<RenderParagraph>())
          if (p.didExceedMaxLines) p.text.toPlainText(),
      ];
      expect(cut, isEmpty);
    });
  });
}
