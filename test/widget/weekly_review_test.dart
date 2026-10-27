import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/repositories/habit_repository.dart';
import 'package:atomic_momentum/domain/services/weekly_review.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/presentation/share/share_sheet.dart';
import 'package:atomic_momentum/screens/insights_screen.dart';
import 'package:atomic_momentum/screens/settings_screen.dart';
import 'package:atomic_momentum/screens/weekly_review_screen.dart';

import '../helpers/fake_sharer.dart';

/// The week in review: its card on Insights, its page, and sharing it.
void main() {
  late HabitProvider habits;
  late FakeSharer sharer;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime daysAgo(int n) => DateTime(today.year, today.month, today.day - n);

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    habits = get<HabitProvider>();
    sharer = FakeSharer.install();
  });

  tearDown(resetDependencies);

  /// The first day of the week the review is about, as things stand.
  DateTime reviewedWeek() => WeeklyReview.weekFor(
        clock.now(),
        weekStart: get<SettingsProvider>().firstDayOfWeek,
        reviewTime: (hour: 18, minute: 0),
      );

  /// Read every day for 40 days but [missed]; Walk every day.
  Future<void> seed({DateTime? missed}) async {
    for (final name in ['Read', 'Walk']) {
      await withClock(
        Clock.fixed(daysAgo(40)),
        () => habits.createHabit(CreateHabitParams(
          name: name,
          target: 1,
          color: name == 'Read' ? HabitColor.teal : HabitColor.green,
          categoryId: BuiltInCategoryIds.body,
        )),
      );
    }
    await habits.loadHabits();
    final repo = get<HabitRepository>();
    for (final h in habits.habits) {
      await repo.saveHabit(h.copyWith(history: {
        for (var i = 40; i >= 1; i--)
          if (h.name != 'Read' || daysAgo(i) != missed) daysAgo(i): 1,
      }));
    }
    await habits.loadHabits();
  }

  Future<void> pump(WidgetTester tester, Widget home) async {
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
      child: MaterialApp(home: home),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Insights leads with the week, and "See your week" opens it', (tester) async {
    await seed();
    await pump(tester, const InsightsScreen());
    expect(find.byKey(const Key('insightsWeeklyReview')), findsOneWidget);
    await tester.tap(find.byKey(const Key('insightsSeeWeek')));
    await tester.pumpAndSettle();
    expect(find.byType(WeeklyReviewScreen), findsOneWidget);
    expect(find.byKey(const Key('weeklyReviewSummary')), findsOneWidget);
    expect(find.byKey(const Key('weeklyReviewWins')), findsOneWidget);
    expect(find.byKey(const Key('weeklyReviewComebacks')), findsOneWidget);
  });

  testWidgets('a habit kept every time is a win; with no misses, nothing to come back from', (tester) async {
    await seed();
    await pump(tester, const WeeklyReviewScreen());
    expect(find.descendant(of: find.byKey(const Key('weeklyReviewWins')), matching: find.text('Walk')), findsWidgets);
    expect(find.textContaining("you didn't miss once"), findsOneWidget);
  });

  testWidgets("a miss followed by a kept day: it didn't miss twice", (tester) async {
    final week = reviewedWeek();
    final missed = DateTime(week.year, week.month, week.day + 1);
    // Only when that day is behind us (a review early in its own week has none)
    if (!missed.isBefore(daysAgo(1))) return;
    await seed(missed: missed);
    await pump(tester, const WeeklyReviewScreen());
    final comebacks = find.byKey(const Key('weeklyReviewComebacks'));
    expect(find.descendant(of: comebacks, matching: find.text('Read')), findsOneWidget);
    expect(find.descendant(of: comebacks, matching: find.textContaining('Missed ${DateFormat.EEEE().format(missed)}')),
        findsOneWidget);
  });

  testWidgets('sharing makes a 1080 × 1350 picture', (tester) async {
    await seed();
    await pump(tester, const WeeklyReviewScreen());
    await tester.ensureVisible(find.byKey(const Key('weeklyReviewShare')));
    await tester.tap(find.byKey(const Key('weeklyReviewShare')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shareCard_week')), findsWidgets);
    // Rendering the picture takes real time
    final button = find.descendant(of: find.byType(ShareSheet), matching: find.text('Share…'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(button);
      for (var i = 0; i < 20 && sharer.shared.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
    expect(pngSize(sharer.shared.single.png), (1080, 1350));
    expect(sharer.shared.single.name, 'momentum-week.png');
  });

  testWidgets('with nothing tracked, no card on Insights', (tester) async {
    await pump(tester, const InsightsScreen());
    expect(find.byKey(const Key('insightsWeeklyReview')), findsNothing);
  });

  testWidgets('Settings → Notifications: the switch and the review time', (tester) async {
    await pump(tester, const SettingsScreen());
    final settings = get<SettingsProvider>();
    final time = find.byKey(const Key('weeklyReviewTime'));
    await tester.scrollUntilVisible(time, 300, scrollable: find.byType(Scrollable).first);
    expect(find.descendant(of: time, matching: find.textContaining('6:00')), findsOneWidget);
    await tester.tap(find.byKey(const Key('weeklyReviewSwitch')));
    await tester.pumpAndSettle();
    expect(settings.weeklyReview, isFalse);
    expect(time, findsNothing, reason: 'no time without the notification');
    await tester.ensureVisible(find.byKey(const Key('weeklyReviewSwitch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('weeklyReviewSwitch')));
    await tester.pumpAndSettle();
    expect(settings.weeklyReview, isTrue);
  });
}
