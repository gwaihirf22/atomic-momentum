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
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/presentation/share/share_sheet.dart';
import 'package:atomic_momentum/screens/insights_screen.dart';
import 'package:atomic_momentum/screens/year_review_screen.dart';

import '../helpers/fake_plus_store.dart';
import '../helpers/fake_sharer.dart';

/// The year in review (Momentum Plus): its card on Insights, its page, and
/// sharing it.
void main() {
  late HabitProvider habits;
  late FakeSharer sharer;
  late FakePlusStore plus;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime daysAgo(int n) => DateTime(today.year, today.month, today.day - n);

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    habits = get<HabitProvider>();
    sharer = FakeSharer.install();
    plus = FakePlusStore.install(unlocked: true);
  });

  tearDown(resetDependencies);

  /// Read and Walk every day for 40 days.
  Future<void> seed() async {
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
      await repo.saveHabit(h.copyWith(history: {for (var i = 40; i >= 1; i--) daysAgo(i): 1}));
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

  final card = find.byKey(const Key('insightsYearReview'));

  testWidgets('with Plus, Insights has the year, and "See your year" opens it', (tester) async {
    await seed();
    await pump(tester, const InsightsScreen());
    expect(card, findsOneWidget);
    await tester.tap(find.byKey(const Key('insightsSeeYear')));
    await tester.pumpAndSettle();
    expect(find.byType(YearReviewScreen), findsOneWidget);
    expect(find.byKey(const Key('yearReviewSummary')), findsOneWidget);
    expect(find.byKey(const Key('yearHeatmap')), findsOneWidget);
    expect(find.byKey(const Key('yearHighlights')), findsOneWidget);
    // Every day kept: the habits come up as the year's most reliable
    expect(find.textContaining('100% of the time'), findsOneWidget);
  });

  testWidgets('without Plus, no year card; buying it brings the card', (tester) async {
    plus.unlocked = false;
    await seed();
    await pump(tester, const InsightsScreen());
    expect(card, findsNothing);
    plus.unlocked = true;
    await tester.pumpAndSettle();
    expect(card, findsOneWidget);
  });

  testWidgets('with too little tracked, no card', (tester) async {
    await pump(tester, const InsightsScreen());
    expect(card, findsNothing);
  });

  testWidgets('sharing makes a 1080 × 1350 picture of the year', (tester) async {
    await seed();
    await pump(tester, const YearReviewScreen());
    await tester.ensureVisible(find.byKey(const Key('yearReviewShare')));
    await tester.tap(find.byKey(const Key('yearReviewShare')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shareCard_year')), findsWidgets);
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
    expect(sharer.shared.single.name, 'momentum-year.png');
  });
}
