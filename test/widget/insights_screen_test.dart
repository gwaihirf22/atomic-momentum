import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/two_minute_version.dart';
import 'package:atomic_momentum/domain/repositories/habit_repository.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/presentation/widgets/heatmap.dart';
import 'package:atomic_momentum/screens/habit_detail_screen.dart';
import 'package:atomic_momentum/screens/insights_screen.dart';

/// The Insights page.
void main() {
  late HabitProvider habits;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime daysAgo(int n) => DateTime(today.year, today.month, today.day - n);

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    habits = get<HabitProvider>();
  });

  tearDown(resetDependencies);

  /// Two habits tracked for 70 days: Read every day but Saturdays (with
  /// the two-minute version the day after each missed Saturday), Walk
  /// every other day.
  Future<void> seed() async {
    for (final name in ['Read', 'Walk']) {
      await withClock(
        Clock.fixed(daysAgo(70)),
        () => habits.createHabit(CreateHabitParams(
          name: name,
          target: 1,
          color: name == 'Read' ? HabitColor.teal : HabitColor.green,
          categoryId: BuiltInCategoryIds.body,
          twoMinute: const TwoMinuteVersion(description: 'One page'),
        )),
      );
    }
    await habits.loadHabits();
    final repo = get<HabitRepository>();
    for (final h in habits.habits) {
      final read = h.name == 'Read';
      final history = <DateTime, int>{};
      final tiny = <DateTime>{};
      for (var i = 70; i >= 1; i--) {
        final day = daysAgo(i);
        if (read) {
          if (day.weekday == DateTime.saturday) continue;
          day.weekday == DateTime.sunday ? tiny.add(day) : history[day] = 1;
        } else if (i.isEven) {
          history[day] = 1;
        }
      }
      await repo.saveHabit(h.copyWith(history: history).withTwoMinuteDays(tiny));
    }
    await habits.loadHabits();
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: get<ThemeProvider>()),
        ChangeNotifierProvider<HabitProvider>.value(value: habits),
        ChangeNotifierProvider<CategoryProvider>.value(value: get<CategoryProvider>()),
        ChangeNotifierProvider<SettingsProvider>.value(value: get<SettingsProvider>()),
      ],
      child: const MaterialApp(home: InsightsScreen()),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  String text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

  testWidgets('with nothing tracked yet, it says what will show', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('insightsEmpty')), findsOneWidget);
    expect(find.byKey(const Key('insightsMomentum')), findsNothing);
  });

  testWidgets('momentum: the ring, this month against last, and the chart', (tester) async {
    await seed();
    await pump(tester);
    expect(find.byKey(const Key('insightsMomentum')), findsOneWidget);
    expect(find.byKey(const Key('insightsMomentumChart')), findsOneWidget);
    expect(text(tester, 'insightsMonthCompare'), contains('80'));
  });

  testWidgets('the heatmap: tapping a day says how it went; Year shows more weeks', (tester) async {
    await seed();
    await pump(tester);
    Heatmap heatmap() => tester.widget<Heatmap>(find.byKey(const Key('insightsHeatmap')));
    expect(heatmap().days.length, inInclusiveRange(25 * 7 + 1, 26 * 7));

    // The top right square is in the latest week
    final grid = find.byKey(const Key('heatmapGrid'));
    await tester.ensureVisible(grid);
    await tester.tapAt(tester.getTopRight(grid) + const Offset(-3, 3));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('heatmapDaySummary')), findsOneWidget);

    await tap(tester, find.byKey(const Key('insightsRange_year')));
    expect(heatmap().days.length, inInclusiveRange(52 * 7 + 1, 53 * 7));
  });

  testWidgets('choosing one habit shows only it', (tester) async {
    await seed();
    await pump(tester);
    final walk = habits.habits.firstWhere((h) => h.name == 'Walk');
    await tap(tester, find.byKey(const Key('insightsHabitPicker')));
    await tap(tester, find.byKey(Key('insightsPick_${walk.id}')));
    expect(find.descendant(of: find.byKey(const Key('insightsHabitPicker')), matching: find.text('Walk')), findsOneWidget);
    final days = tester.widget<Heatmap>(find.byKey(const Key('insightsHeatmap'))).days;
    expect(days.where((d) => !d.isEmpty).every((d) => d.due == 1), isTrue);
  });

  testWidgets('two-minute days: how many, and the streaks they saved', (tester) async {
    await seed();
    await pump(tester);
    String number(String key) => tester
        .widgetList<Text>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)))
        .first
        .data!;
    // Read: a two-minute Sunday after each missed Saturday, about ten weeks
    expect(int.parse(number('insightsTwoMinuteDays')), inInclusiveRange(9, 11));
    expect(int.parse(number('insightsStreaksSaved')), inInclusiveRange(8, 11));
  });

  testWidgets('your week: Saturdays are the hardest', (tester) async {
    await seed();
    await pump(tester);
    expect(text(tester, 'insightsWeekSummary'), contains('Saturdays are the hardest'));
  });

  testWidgets('habits are listed by momentum, and open their page', (tester) async {
    await seed();
    await pump(tester);
    final read = habits.habits.firstWhere((h) => h.name == 'Read');
    final walk = habits.habits.firstWhere((h) => h.name == 'Walk');
    expect(
      tester.getTopLeft(find.byKey(Key('insightsHabit_${read.id}'))).dy,
      lessThan(tester.getTopLeft(find.byKey(Key('insightsHabit_${walk.id}'))).dy),
    );
    await tap(tester, find.byKey(Key('insightsHabit_${walk.id}')));
    expect(find.byType(HabitDetailScreen), findsOneWidget);
    expect(find.byKey(const Key('detailHeatmap')), findsOneWidget, reason: 'the habit page has its own');
  });
}

extension on Habit {
  Habit withTwoMinuteDays(Set<DateTime> days) => Habit(
        id: id,
        name: name,
        progress: progress,
        target: target,
        units: units,
        color: color,
        categoryId: categoryId,
        lastUpdatedDate: lastUpdatedDate,
        resetFrequency: resetFrequency,
        history: history,
        streak: streak,
        metadata: metadata,
        resetAnchorDate: resetAnchorDate,
        twoMinute: twoMinute,
        twoMinuteDays: days,
        goal: goal,
      );
}
