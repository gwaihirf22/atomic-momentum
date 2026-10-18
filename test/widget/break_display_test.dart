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
import 'package:atomic_momentum/presentation/widgets/break_wording.dart';
import 'package:atomic_momentum/screens/calendar_screen.dart';
import 'package:atomic_momentum/screens/habit_detail_screen.dart';
import 'package:atomic_momentum/screens/home_screen.dart';

import '../helpers/real_fonts.dart';

/// How habits being broken show: cards, the habit page and Calendar.
void main() {
  late HabitProvider habits;
  late String smoking;
  late String drinks;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(now.year, now.month, now.day - 1);

  setUpAll(loadRealFonts);

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    habits = get<HabitProvider>();
    await habits.createHabit(const CreateHabitParams(
      name: 'Smoking',
      target: 0,
      color: HabitColor.red,
      categoryId: BuiltInCategoryIds.body,
      goal: HabitGoal.quit,
    ));
    await habits.createHabit(const CreateHabitParams(
      name: 'Alcohol',
      target: 2,
      units: 'drinks',
      color: HabitColor.purple,
      categoryId: BuiltInCategoryIds.social,
      goal: HabitGoal.limit,
    ));
    smoking = habits.habits.firstWhere((h) => h.name == 'Smoking').id;
    drinks = habits.habits.firstWhere((h) => h.name == 'Alcohol').id;
  });

  tearDown(resetDependencies);

  Future<void> pump(WidgetTester tester, Widget home, {double width = 390, double scale = 1}) async {
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
      child: MaterialApp(home: home),
    ));
    await tester.pumpAndSettle();
  }

  Finder inCard(String id, String text) =>
      find.descendant(of: find.byKey(Key('habitCard_$id')), matching: find.textContaining(text));

  group('cards', () {
    testWidgets('a clean day reads "Clean today"; + logs a slip; the ring never does', (tester) async {
      await pump(tester, const HomeScreen());
      expect(inCard(smoking, 'Clean today'), findsOneWidget);
      expect(inCard(drinks, '0 of 2 drinks today'), findsOneWidget);

      // A tap on the ring logs nothing: it opens the habit's page, like the rest of the card
      await tester.tap(find.byKey(Key('habitIcon_$smoking')));
      await tester.pumpAndSettle();
      expect(habits.getHabitById(smoking)!.progress, 0);
      expect(find.byType(HabitDetailScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(HabitDetailScreen))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(Key('incrementHabit_$smoking')));
      await tester.pumpAndSettle();
      expect(habits.getHabitById(smoking)!.progress, 1);
      expect(inCard(smoking, '1 slip today'), findsOneWidget);

      await tester.tap(find.byKey(Key('decrementHabit_$smoking')));
      await tester.pumpAndSettle();
      expect(inCard(smoking, 'Clean today'), findsOneWidget);
    });

    testWidgets('+ keeps logging past a limit', (tester) async {
      await pump(tester, const HomeScreen());
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(Key('incrementHabit_$drinks')));
        await tester.pumpAndSettle();
      }
      expect(habits.getHabitById(drinks)!.progress, 3);
      expect(habits.getHabitById(drinks)!.isCompleted, isFalse);
      expect(inCard(drinks, '3 of 2 drinks today'), findsOneWidget);
    });

    testWidgets('holding the ring does nothing for a habit being broken', (tester) async {
      await pump(tester, const HomeScreen());
      await tester.longPress(find.byKey(Key('habitIcon_$smoking')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(Key('undoHold_$smoking')), findsNothing);
      expect(habits.getHabitById(smoking)!.progress, 0);
    });

    testWidgets('a clean run shows its streak and momentum, though nothing is logged', (tester) async {
      await habits.startFrom(smoking, DateTime(now.year, now.month, now.day - 9));
      await pump(tester, const HomeScreen());
      expect(habits.getHabitById(smoking)!.history, isEmpty);
      expect(find.descendant(of: find.byKey(Key('habitStreak_$smoking')), matching: find.text('10')), findsOneWidget);
      expect(find.byKey(Key('habitMomentum_$smoking')), findsOneWidget);
    });

    testWidgets('a slip after a clean streak reads "Don\'t slip twice"', (tester) async {
      // Tracked from a slip six days ago; clean since, until a slip yesterday
      await habits.updateProgressForDate(smoking, DateTime(now.year, now.month, now.day - 6), 1);
      await habits.updateProgressForDate(smoking, yesterday, 1);
      await pump(tester, const HomeScreen());
      expect(habits.getHabitById(smoking)!.streak.atRisk, isTrue);
      expect(inCard(smoking, "Don't slip twice"), findsOneWidget);
    });
  });

  group('the habit page', () {
    testWidgets('the number counts slips, and + logs one', (tester) async {
      await pump(tester, HabitDetailScreen(habitId: smoking));
      expect(find.text('slips'), findsOneWidget);
      expect(find.text('Clean streak'), findsOneWidget);
      await tester.tap(find.byKey(const Key('detailPlus')));
      await tester.pumpAndSettle();
      expect(habits.getHabitById(smoking)!.progress, 1);
      expect(find.text('slip'), findsOneWidget);
    });

    testWidgets('a limit reads "of 2 drinks allowed", and typing past it is fine', (tester) async {
      await pump(tester, HabitDetailScreen(habitId: drinks));
      expect(find.text('of 2 drinks allowed'), findsOneWidget);
      await tester.tap(find.byKey(const Key('detailNumber')));
      await tester.pumpAndSettle();
      expect(find.text('Drinks today'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('amountField')), '4');
      await tester.tap(find.byKey(const Key('amountDone')));
      await tester.pumpAndSettle();
      expect(habits.getHabitById(drinks)!.progress, 4);
    });
  });

  testWidgets('a Calendar row says how a past day went', (tester) async {
    await habits.updateProgressForDate(drinks, today, 1);
    await pump(tester, const CalendarScreen());
    expect(
      find.descendant(of: find.byKey(Key('dayHabit_$drinks')), matching: find.textContaining('1 of 2 drinks today')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(Key('incrementDay_$smoking')));
    await tester.pumpAndSettle();
    expect(habits.getHabitById(smoking)!.getProgressForDate(today), 1);
  });

  testWidgets('cards with break habits fit an iPhone SE at large text', (tester) async {
    await habits.updateHabitProgress(drinks, 3);
    await pump(tester, const HomeScreen(), width: 375, scale: 1.35);
    expect(tester.takeException(), isNull);
    final cut = [
      for (final p in tester.allRenderObjects.whereType<RenderParagraph>())
        if (p.didExceedMaxLines) p.text.toPlainText(),
    ];
    expect(cut, isEmpty);
  });

  test('break wording', () {
    final quit = habits.getHabitById(smoking)!;
    final limit = habits.getHabitById(drinks)!;
    expect(BreakWording.status(quit, today), 'Clean today');
    expect(BreakWording.status(limit, today), '0 of 2 drinks today');
    expect(BreakWording.status(quit, yesterday, current: false), 'Clean');
    expect(BreakWording.underNumber(quit, 2), 'slips');
    expect(BreakWording.underNumber(limit, 1), 'of 2 drinks allowed');
    expect(BreakWording.streak(quit, 12), '12 days clean');
    expect(BreakWording.streak(quit, 1), '1 day clean');
  });
}
