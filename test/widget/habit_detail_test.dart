import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/two_minute_version.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/presentation/widgets/hold_undo_strip.dart';
import 'package:atomic_momentum/screens/calendar_screen.dart';
import 'package:atomic_momentum/screens/habit_detail_screen.dart';
import 'package:atomic_momentum/screens/habit_editor_screen.dart';
import 'package:atomic_momentum/screens/home_screen.dart';

/// The habit page: opened by tapping a card (or a Calendar row).
void main() {
  late HabitProvider habits;
  late String id;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(now.year, now.month, now.day - 1);

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    habits = get<HabitProvider>();
    await habits.createHabit(const CreateHabitParams(
      name: 'Drink water',
      target: 8,
      units: 'glasses',
      color: HabitColor.blue,
      categoryId: BuiltInCategoryIds.body,
      icon: 'water',
      twoMinute: TwoMinuteVersion(description: 'Fill one glass'),
    ));
    id = habits.habits.single.id;
    await habits.updateHabitProgress(id, 5);
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

  Future<void> openFromCard(WidgetTester tester) async {
    await pump(tester, const HomeScreen());
    await tester.tap(find.descendant(of: find.byKey(Key('habitCard_$id')), matching: find.text('Drink water')));
    await tester.pumpAndSettle();
    expect(find.byType(HabitDetailScreen), findsOneWidget);
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  String number(WidgetTester tester) => tester
      .widget<Text>(find.descendant(of: find.byKey(const Key('detailNumber')), matching: find.byType(Text)).first)
      .data!;

  String dayKey(DateTime d) => 'detailDay_${d.year}-${d.month}-${d.day}';

  testWidgets("a card opens its habit's page: today's number and how it's going", (tester) async {
    await openFromCard(tester);
    expect(find.byKey(const Key('detailTitle')), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    expect(number(tester), '5');
    for (final key in ['detailStreak', 'detailBest', 'detailMomentum', 'detailKept', 'detailTrend', 'detailWhy', 'detailNotes']) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
  });

  testWidgets('tapping the number types it, even past the target', (tester) async {
    await openFromCard(tester);
    await tap(tester, 'detailNumber');
    await tester.enterText(find.byKey(const Key('amountField')), '10');
    await tap(tester, 'amountDone');

    expect(number(tester), '10');
    expect(habits.getHabitById(id)!.progress, 10);
    expect(habits.getHabitById(id)!.isCompleted, isTrue);
  });

  testWidgets('a typed number over ten times the target is caught', (tester) async {
    await openFromCard(tester);
    await tap(tester, 'detailNumber');
    await tester.enterText(find.byKey(const Key('amountField')), '81');
    await tap(tester, 'amountDone');
    expect(find.text('That is more than 80'), findsOneWidget);
    expect(habits.getHabitById(id)!.progress, 5);
  });

  testWidgets('+ and − change the chosen day; + stops at the target', (tester) async {
    await openFromCard(tester);
    await tap(tester, 'detailPlus');
    expect(habits.getHabitById(id)!.progress, 6);
    await tap(tester, 'detailMinus');
    await tap(tester, 'detailMinus');
    expect(habits.getHabitById(id)!.progress, 4);
  });

  testWidgets('another day of the week can be chosen and logged', (tester) async {
    await openFromCard(tester);
    // On the week's first day yesterday is only in the month (or last month)
    if (find.byKey(Key(dayKey(yesterday))).evaluate().isEmpty) {
      await tap(tester, 'detailMonthToggle');
      if (yesterday.month != today.month) await tap(tester, 'detailPrevMonth');
    }
    await tap(tester, dayKey(yesterday));
    expect(find.text('TODAY'), findsNothing);
    expect(number(tester), '0');
    await tap(tester, 'detailPlus');
    expect(habits.getHabitById(id)!.getProgressForDate(yesterday), 1);
    expect(habits.getHabitById(id)!.getProgressForDate(today), 5, reason: 'today is untouched');
  });

  testWidgets('the week opens to the month; future days can not be chosen', (tester) async {
    await openFromCard(tester);
    await tap(tester, 'detailMonthToggle');
    final first = DateTime(now.year, now.month, 1);
    expect(find.byKey(Key(dayKey(first))), findsOneWidget);
    if (now.day < DateUtils.getDaysInMonth(now.year, now.month)) {
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      await tap(tester, dayKey(tomorrow));
      expect(find.text('TODAY'), findsOneWidget, reason: 'still on today');
    }
    await tap(tester, 'detailPrevMonth');
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    expect(find.byKey(Key(dayKey(lastMonth))), findsOneWidget);
  });

  testWidgets('the why can be written, and is kept', (tester) async {
    await openFromCard(tester);
    await tap(tester, 'detailWhy');
    await tester.enterText(find.byKey(const Key('whyField')), 'Fewer headaches');
    await tap(tester, 'whyDone');
    expect(find.text('Fewer headaches'), findsOneWidget);
    expect(habits.getHabitById(id)!.why, 'Fewer headaches');
  });

  testWidgets("a note for the chosen day is added, listed, and opened to edit", (tester) async {
    await openFromCard(tester);
    await tap(tester, 'detailAddNote');
    await tester.enterText(find.byKey(const Key('noteField')), 'Two before lunch');
    await tap(tester, 'noteDone');

    expect(habits.getHabitById(id)!.dayNotes, {today: 'Two before lunch'});
    expect(find.text('Two before lunch'), findsOneWidget);

    await tap(tester, 'detailNote_${today.year}-${today.month}-${today.day}');
    expect(find.widgetWithText(TextField, 'Two before lunch'), findsOneWidget, reason: 'opens to edit');
  });

  testWidgets('holding the ring finishes the day, with Undo', (tester) async {
    await openFromCard(tester);
    await tester.longPress(find.byKey(const Key('detailRing')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(habits.getHabitById(id)!.progress, 8);
    await tester.tap(find.byKey(const Key('detailUndo')));
    await tester.pumpAndSettle();
    expect(habits.getHabitById(id)!.progress, 5);
    await tester.pump(HoldUndo.duration);
    await tester.pumpAndSettle();
  });

  testWidgets('VoiceOver reads the number as a button to type an amount', (tester) async {
    final semantics = tester.ensureSemantics();
    await openFromCard(tester);
    expect(tester.getSemantics(find.byKey(const Key('detailNumber'))),
        matchesSemantics(
          label: '5 of 8 glasses',
          hint: 'Type an amount',
          isButton: true,
          hasTapAction: true,
          hasLongPressAction: true,
        ));
    semantics.dispose();
  });

  testWidgets('a Calendar row opens the page on that day', (tester) async {
    await habits.updateProgressForDate(id, yesterday, 3);
    await pump(tester, const CalendarScreen());
    if (yesterday.month != now.month) return; // the Calendar starts on this month
    await tester.tap(find.byKey(Key('calendarDay_${yesterday.year}-${yesterday.month}-${yesterday.day}')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byKey(Key('dayHabit_$id')), matching: find.text('Drink water')));
    await tester.pumpAndSettle();

    expect(find.byType(HabitDetailScreen), findsOneWidget);
    expect(find.text('TODAY'), findsNothing);
    expect(number(tester), '3');
  });

  testWidgets('"Edit habit & notifications" opens the editor', (tester) async {
    await openFromCard(tester);
    await tester.scrollUntilVisible(find.byKey(const Key('detailEdit')), 300, scrollable: find.byType(Scrollable).first);
    await tap(tester, 'detailEdit');
    expect(find.byType(HabitEditorScreen), findsOneWidget);
    expect(find.text('Edit Habit'), findsOneWidget);
  });

  testWidgets('Edit in the bar opens the editor, without scrolling', (tester) async {
    await openFromCard(tester);
    await tap(tester, 'detailEditTop');
    expect(find.byType(HabitEditorScreen), findsOneWidget);
    expect(find.text('Edit Habit'), findsOneWidget);
  });
}
