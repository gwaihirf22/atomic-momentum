import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/repositories/habit_repository.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/presentation/habit_form/habit_draft.dart';
import 'package:atomic_momentum/presentation/habit_form/sections.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/screens/add_habit_screen.dart';
import 'package:atomic_momentum/screens/story_habit_screen.dart';

/// Editing when a habit counts from: earlier or later, clearing what's
/// logged before a later start once asked.
void main() {
  late HabitProvider habits;
  late String id;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime ago(int n) => DateTime(today.year, today.month, today.day - n);

  /// Read, added 20 days ago, logged 15 and 10 days ago.
  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    habits = get<HabitProvider>();
    await withClock(
      Clock.fixed(ago(20)),
      () => habits.createHabit(const CreateHabitParams(
        name: 'Read',
        target: 1,
        color: HabitColor.teal,
        categoryId: BuiltInCategoryIds.mind,
      )),
    );
    final habit = habits.habits.single;
    id = habit.id;
    await get<HabitRepository>().saveHabit(habit.copyWith(history: {ago(15): 1, ago(10): 1}));
    await habits.loadHabits();
  });

  tearDown(resetDependencies);

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(390, 2400);
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

  HabitDraft draft() => HabitDraft.fromHabit(habits.getHabitById(id)!, defaultReminderTime: const TimeOfDay(hour: 9, minute: 0));

  testWidgets('editing shows when it counts from, and Change opens a date picker', (tester) async {
    await pump(tester, AddHabitScreen(editHabit: habits.getHabitById(id)));
    await tester.ensureVisible(find.byKey(const Key('countsFrom')));
    expect(find.descendant(of: find.byKey(const Key('countsFrom')), matching: find.textContaining('${ago(20).day}')),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('countsFromChange')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('adding a habit has no such row', (tester) async {
    await pump(tester, const AddHabitScreen());
    expect(find.byKey(const Key('countsFrom')), findsNothing);
  });

  testWidgets("Story's edit has it too", (tester) async {
    await pump(tester, StoryHabitScreen(editHabit: habits.getHabitById(id)));
    expect(find.byKey(const Key('countsFrom')), findsOneWidget);
  });

  group('choosing a day', () {
    Future<HabitDraft> choose(WidgetTester tester, DateTime day, {String? answer}) async {
      final d = draft();
      await pump(tester, Scaffold(body: CountsFromSection(d)));
      final done = CountsFromSection.choose(tester.element(find.byType(CountsFromSection)), d, day);
      await tester.pumpAndSettle();
      if (answer != null) {
        await tester.tap(find.byKey(Key(answer)));
        await tester.pumpAndSettle();
      }
      await done;
      return d;
    }

    testWidgets('earlier: no question, it saves', (tester) async {
      final d = await choose(tester, ago(25));
      expect(d.countFrom, ago(25));
      expect(d.hasChanges, isTrue);
      expect(await d.save(habits), isTrue);
      await tester.pumpAndSettle();
      expect(habits.getHabitById(id)!.trackedFrom, ago(25));
    });

    testWidgets('later, past a logged day: asks; clearing saves the new start without that log', (tester) async {
      final d = await choose(tester, ago(12), answer: 'countsFromClear');
      expect(find.textContaining('Clear 1 day logged before'), findsNothing, reason: 'answered');
      expect(d.countFrom, ago(12));
      expect(await d.save(habits), isTrue);
      await tester.pumpAndSettle();
      final habit = habits.getHabitById(id)!;
      expect(habit.trackedFrom, ago(12));
      expect(habit.history.keys, [ago(10)]);
    });

    testWidgets('keeping the logs leaves the start as it was', (tester) async {
      final d = await choose(tester, ago(12), answer: 'countsFromKeep');
      expect(d.countFrom, ago(20));
      expect(d.hasChanges, isFalse);
    });

    testWidgets('later, before any log: no question', (tester) async {
      final d = await choose(tester, ago(17));
      expect(find.byKey(const Key('countsFromClear')), findsNothing);
      expect(await d.save(habits), isTrue);
      await tester.pumpAndSettle();
      expect(habits.getHabitById(id)!.trackedFrom, ago(17));
    });
  });
}
