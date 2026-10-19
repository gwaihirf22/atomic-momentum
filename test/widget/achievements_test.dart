import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/achievement_store.dart';
import 'package:atomic_momentum/core/services/freeze_bank.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/repositories/habit_repository.dart';
import 'package:atomic_momentum/domain/services/achievements.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/main.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/screens/achievements_screen.dart';
import 'package:atomic_momentum/screens/habit_detail_screen.dart';

/// Achievements: celebrated once when earned, kept on the shelf.
void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime ago(int n) => DateTime(today.year, today.month, today.day - n);
  late String id;

  /// A habit done on each of [days] days ago.
  Future<void> seed(Iterable<int> days, {bool started = true}) async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    final habits = get<HabitProvider>();
    await withClock(
      Clock.fixed(ago(30)),
      () => habits.createHabit(const CreateHabitParams(
        name: 'Read',
        target: 1,
        color: HabitColor.teal,
        categoryId: BuiltInCategoryIds.mind,
      )),
    );
    final habit = habits.habits.single;
    id = habit.id;
    final seeded = habit.copyWith(history: {for (final d in days) ago(d): 1});
    await get<HabitRepository>().saveHabit(seeded);
    // The fun ones depend on the weekday (Weekend warrior): out of the way
    // of what these tests watch
    if (started) {
      await get<AchievementStore>().markSeen([
        for (final a in Achievements.earned([seeded], now))
          if (a.kind == AchievementKind.fun) a.id,
      ]);
    }
  }

  tearDown(resetDependencies);

  Future<void> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MomentumApp());
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Finder sheet() => find.byKey(const Key('achievementSheet'));

  group('reaching 7 days opens the celebration, once', () {
    setUp(() => seed([6, 5, 4, 3, 2, 1]));

    testWidgets('reaching 7 days opens the celebration, once', (tester) async {
      await launch(tester);
      expect(sheet(), findsNothing);

      await tap(tester, find.byKey(Key('incrementHabit_$id')));
      expect(sheet(), findsOneWidget);
      expect(find.text('NEW ACHIEVEMENT'), findsOneWidget);
      expect(find.text('7 days'), findsOneWidget);
      expect(find.textContaining('Next: 21 days'), findsOneWidget);
      // A streak milestone earns a freeze
      expect(find.text('+1 freeze · 4 of 5'), findsOneWidget);
      expect(get<FreezeBank>().available, 4);

      await tap(tester, find.byKey(const Key('achievementDone')));
      expect(sheet(), findsNothing);
      expect(get<AchievementStore>().seen, contains('streak_7_$id'));

      // Undo and redo: already celebrated
      await tap(tester, find.byKey(Key('decrementHabit_$id')));
      await tap(tester, find.byKey(Key('incrementHabit_$id')));
      expect(sheet(), findsNothing);
    });
  });

  group('the first time, what history already holds is filed without a celebration', () {
    setUp(() => seed([6, 5, 4, 3, 2, 1, 0], started: false));

    testWidgets('the first time, what history already holds is filed without a celebration', (tester) async {
      await launch(tester);
      expect(sheet(), findsNothing);
      expect(get<AchievementStore>().seen, contains('streak_7_$id'));
    });
  });

  group('one reached days ago (logged afterwards) goes to the shelf quietly', () {
    setUp(() => seed([20, 19, 18, 17, 16, 15, 14]));

    testWidgets('one reached days ago (logged afterwards) goes to the shelf quietly', (tester) async {
      await launch(tester);
      expect(sheet(), findsNothing);
      expect(get<AchievementStore>().seen, contains('streak_7_$id'));
    });
  });

  group('Insights shows the shelf; a tile opens it again; See all lists everything', () {
    setUp(() => seed([for (var d = 21; d >= 1; d--) d], started: false));

    testWidgets('Insights shows the shelf; a tile opens it again; See all lists everything', (tester) async {
      await launch(tester);
      await tap(tester, find.byKey(const Key('tab_insights')));
      await tester.scrollUntilVisible(find.byKey(const Key('insightsAchievements')), 300,
          scrollable: find.byType(Scrollable).hitTestable().first);
      expect(find.byKey(const Key('insightsAchievements')), findsOneWidget);

      await tap(tester, find.byKey(Key('achievement_streak_21_$id')));
      expect(sheet(), findsOneWidget);
      expect(find.textContaining('EARNED'), findsOneWidget);
      await tap(tester, find.byKey(const Key('achievementDone')));

      await tap(tester, find.byKey(const Key('insightsSeeAllAchievements')));
      expect(find.byType(AchievementsScreen), findsOneWidget);
      // 7 days, 21 days and a perfect week, and the fun ones (depending on the weekday)
      final shown = tester.element(find.byType(AchievementsScreen)).read<HabitProvider>().habits;
      final shelf = Achievements.earned(shown, now).where((a) => a.onShelf).length;
      expect(shelf, greaterThanOrEqualTo(3));
      expect(find.text('$shelf earned'), findsOneWidget);
      expect(find.text('Up next'), findsOneWidget);
    });
  });

  group("a habit's page lists its achievements", () {
    setUp(() => seed([for (var d = 8; d >= 1; d--) d], started: false));

    testWidgets("a habit's page lists its achievements", (tester) async {
      await launch(tester);
      await tap(tester, find.descendant(of: find.byKey(Key('habitCard_$id')), matching: find.text('Read')));
      expect(find.byType(HabitDetailScreen), findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(Key('achievement_streak_7_$id')), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.byKey(Key('achievement_streak_7_$id')), findsOneWidget);
    });
  });
}
