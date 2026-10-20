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
import 'package:atomic_momentum/presentation/widgets/habit_progress_ring.dart';
import 'package:atomic_momentum/screens/calendar_screen.dart';
import 'package:atomic_momentum/screens/categories_screen.dart';
import 'package:flutter/semantics.dart';

void main() {
  late HabitProvider habitProvider;
  late String id;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  final tomorrow = DateTime(now.year, now.month, now.day + 1);

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    habitProvider = get<HabitProvider>();
    await habitProvider.createHabit(const CreateHabitParams(
      name: 'Stretch',
      target: 2,
      color: HabitColor.teal,
      categoryId: BuiltInCategoryIds.body,
    ));
    id = habitProvider.habits.single.id;
  });

  tearDown(() async {
    await resetDependencies();
  });

  Future<void> pumpCalendar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: get<ThemeProvider>()),
        ChangeNotifierProvider<HabitProvider>.value(value: habitProvider),
        ChangeNotifierProvider<CategoryProvider>.value(value: get<CategoryProvider>()),
        ChangeNotifierProvider<SettingsProvider>.value(value: get<SettingsProvider>()),
      ],
      child: const MaterialApp(home: CalendarScreen()),
    ));
    await tester.pumpAndSettle();
  }

  Finder dayCell(DateTime day) => find.byKey(Key('calendarDay_${day.year}-${day.month}-${day.day}'));

  /// Shows the month holding [day], if it isn't the current one.
  Future<void> showMonthOf(WidgetTester tester, DateTime day) async {
    if (day.month == now.month) return;
    final icon = day.isBefore(today) ? CupertinoIcons.chevron_left : CupertinoIcons.chevron_right;
    await tester.tap(find.byIcon(icon));
    await tester.pumpAndSettle();
  }

  RingPainter? ringOf(WidgetTester tester, DateTime day) {
    final paints =
        tester.widgetList<CustomPaint>(find.descendant(of: dayCell(day), matching: find.byType(CustomPaint)));
    return paints.map((p) => p.painter).whereType<RingPainter>().firstOrNull;
  }

  testWidgets("each day's ring fills with that day's completion", (tester) async {
    // Created today, but yesterday was logged (backfilled), so it's tracked
    await habitProvider.updateProgressForDate(id, yesterday, 1);
    await pumpCalendar(tester);
    await showMonthOf(tester, yesterday);

    expect(ringOf(tester, yesterday)!.fraction, 0.5);
    // Nothing tracked before the first logged day; no rings in the future
    expect(ringOf(tester, DateTime(yesterday.year, yesterday.month, yesterday.day - 1)), isNull);
  });

  testWidgets('the selected day is a filled circle with the date as the heading', (tester) async {
    await pumpCalendar(tester);

    final circle = find.descendant(
      of: dayCell(today),
      matching: find.byWidgetPredicate((w) => w is Container && w.decoration is BoxDecoration),
    );
    expect(circle, findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('calendarDayTitle'))).data, equals('Today'));
  });

  testWidgets('the category rings and the list follow the selected day', (tester) async {
    await habitProvider.updateProgressForDate(id, yesterday, 2);
    await pumpCalendar(tester);
    expect(find.bySemanticsLabel(RegExp('Body, 0 percent, 0 of 1')), findsOneWidget);

    await showMonthOf(tester, yesterday);
    await tester.tap(dayCell(yesterday));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('Body, 100 percent, 1 of 1')), findsOneWidget);
    expect(find.text('1 of 1 done'), findsOneWidget);
    // Done: crossed off, with the ring's check
    final name =
        tester.widget<Text>(find.descendant(of: find.byKey(Key('dayHabit_$id')), matching: find.text('Stretch')));
    expect(name.style!.decoration, TextDecoration.lineThrough);
    expect(find.descendant(of: find.byKey(Key('dayHabitIcon_$id')), matching: find.byKey(const Key('completedBadge'))),
        findsOneWidget);
  });

  testWidgets("holding a day's ring finishes that day", (tester) async {
    await habitProvider.updateProgressForDate(id, yesterday, 1);
    await pumpCalendar(tester);
    await showMonthOf(tester, yesterday);
    await tester.tap(dayCell(yesterday));
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(Key('dayHabitIcon_$id')));
    await tester.pumpAndSettle();

    final habit = habitProvider.habits.single;
    expect(habit.getProgressForDate(yesterday), 2, reason: 'the 1 missing was added');
    expect(habit.wasCompletedOnDate(yesterday), isTrue);
    expect(habit.getProgressForDate(today), 0, reason: 'only that day changes');
  });

  testWidgets("holding a done day's ring clears it, and Undo brings it back", (tester) async {
    await habitProvider.updateProgressForDate(id, yesterday, 2);
    await pumpCalendar(tester);
    await showMonthOf(tester, yesterday);
    await tester.tap(dayCell(yesterday));
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(Key('dayHabitIcon_$id')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(habitProvider.habits.single.getProgressForDate(yesterday), 0);
    expect(find.text('Cleared'), findsOneWidget);

    await tester.tap(find.byKey(Key('undoDayHold_$id')));
    await tester.pumpAndSettle();
    expect(habitProvider.habits.single.getProgressForDate(yesterday), 2);
    expect(find.byKey(Key('undoDayHold_$id')), findsNothing);
  });

  testWidgets("future days can be looked at but not logged", (tester) async {
    await pumpCalendar(tester);
    await showMonthOf(tester, tomorrow);
    await tester.tap(dayCell(tomorrow));
    await tester.pumpAndSettle();

    expect(find.text("Future days can't be logged yet"), findsOneWidget);
    expect(find.byKey(Key('dayHabit_$id')), findsOneWidget);
    expect(find.byKey(Key('incrementDay_$id')), findsNothing);
  });

  testWidgets('the week/month toggle is labelled for VoiceOver', (tester) async {
    await pumpCalendar(tester);
    expect(find.bySemanticsLabel('Show one week'), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendarFormatToggle')));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Show the whole month'), findsOneWidget);
  });

  group('holding opens Arrange, as on Habits', () {
    testWidgets('holding a category', (tester) async {
      await pumpCalendar(tester);
      await tester.longPress(find.byKey(const Key('categoryRing_body')));
      await tester.pumpAndSettle();
      expect(find.byType(CategoriesScreen), findsOneWidget);
    });

    testWidgets("holding a habit's name opens it at that habit; holding its ring still finishes it", (tester) async {
      await pumpCalendar(tester);
      await tester.longPress(find.descendant(of: find.byKey(Key('dayHabit_$id')), matching: find.text('Stretch')));
      await tester.pumpAndSettle();
      expect(tester.widget<CategoriesScreen>(find.byType(CategoriesScreen)).showHabitId, id);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(Key('dayHabitIcon_$id')));
      await tester.pumpAndSettle();
      expect(find.byType(CategoriesScreen), findsNothing);
      expect(habitProvider.habits.single.wasCompletedOnDate(today), isTrue);
    });

    testWidgets('VoiceOver gets "Arrange habits" on a row', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCalendar(tester);
      final data = tester.getSemantics(find.byKey(Key('dayHabit_$id'))).getSemanticsData();
      final labels = data.customSemanticsActionIds!.map((id) => CustomSemanticsAction.getAction(id)!.label);
      expect(labels, contains('Arrange habits'));
      handle.dispose();
    });
  });
}
