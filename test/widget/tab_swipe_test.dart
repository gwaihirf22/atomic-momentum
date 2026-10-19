import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/notification_service.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/main.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/screens/calendar_screen.dart';
import 'package:atomic_momentum/screens/categories_screen.dart';
import 'package:atomic_momentum/screens/habit_editor_screen.dart';
import 'package:atomic_momentum/screens/home_screen.dart';
import 'package:atomic_momentum/screens/insights_screen.dart';
import 'package:atomic_momentum/screens/inspire_screen.dart';
import 'package:atomic_momentum/screens/settings_screen.dart';

/// Swiping sideways between the main tabs, and where a swipe stays put.
void main() {
  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
  });

  tearDown(() async {
    NotificationService.focusRequests.value = null;
    await resetDependencies();
  });

  Future<void> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MomentumApp());
    await tester.pumpAndSettle();
  }

  HabitProvider appHabits(WidgetTester tester) =>
      Provider.of<HabitProvider>(tester.element(find.byKey(const Key('tab_habits'))), listen: false);

  Future<String> addHabit(WidgetTester tester) async {
    await appHabits(tester).createHabit(const CreateHabitParams(
      name: 'Read',
      target: 1,
      color: HabitColor.teal,
      categoryId: BuiltInCategoryIds.mind,
    ));
    await tester.pumpAndSettle();
    return appHabits(tester).habits.single.id;
  }

  bool showing(Type screen) => find.byType(screen).hitTestable().evaluate().isNotEmpty;

  Finder greeting() => find.byKey(const Key('habitsGreeting'));
  Finder calendarTitle() => find.byKey(const Key('calendarDayTitle'));

  Future<void> swipe(WidgetTester tester, Finder on, Offset by) async {
    await tester.drag(on, by);
    await tester.pumpAndSettle();
  }

  testWidgets('a left swipe goes to the next tab, a right swipe back', (tester) async {
    await launch(tester);
    await swipe(tester, greeting(), const Offset(-300, 0));
    expect(showing(CalendarScreen), isTrue);
    expect(showing(HomeScreen), isFalse);

    await swipe(tester, calendarTitle(), const Offset(300, 0));
    expect(showing(HomeScreen), isTrue);
  });

  testWidgets('a short drag springs back; a quick flick goes', (tester) async {
    await launch(tester);
    await swipe(tester, greeting(), const Offset(-60, 0));
    expect(showing(HomeScreen), isTrue);

    await tester.fling(greeting(), const Offset(-80, 0), 1200);
    await tester.pumpAndSettle();
    expect(showing(CalendarScreen), isTrue);
  });

  testWidgets('the first and last tabs go no further', (tester) async {
    await launch(tester);
    await swipe(tester, greeting(), const Offset(300, 0));
    expect(showing(HomeScreen), isTrue);

    await tester.tap(find.byKey(const Key('tab_settings')));
    await tester.pumpAndSettle();
    await swipe(tester, find.text('Appearance'), const Offset(-300, 0));
    expect(showing(SettingsScreen), isTrue);
    await swipe(tester, find.text('Appearance'), const Offset(300, 0));
    expect(showing(InspireScreen), isTrue);
    await swipe(tester, find.byType(InspireScreen), const Offset(300, 0));
    expect(showing(InsightsScreen), isTrue);
  });

  testWidgets('with Inspire turned off, Settings comes right after Insights', (tester) async {
    await get<SettingsProvider>().setShowInspireTab(false);
    await launch(tester);
    await tester.tap(find.byKey(const Key('tab_insights')));
    await tester.pumpAndSettle();
    await swipe(tester, find.byType(InsightsScreen), const Offset(-300, 0));
    expect(showing(SettingsScreen), isTrue);
    await swipe(tester, find.text('Appearance'), const Offset(300, 0));
    expect(showing(InsightsScreen), isTrue);
  });

  testWidgets('a swipe on a habit card shows its actions and stays on Habits', (tester) async {
    await launch(tester);
    final id = await addHabit(tester);
    await swipe(tester, find.byKey(Key('habitCard_$id')), const Offset(-300, 0));
    expect(showing(HomeScreen), isTrue);
    expect(find.byKey(Key('editHabit_$id')).hitTestable(), findsOneWidget);
  });

  testWidgets('on Calendar, the grid changes month and a habit row stays put', (tester) async {
    await launch(tester);
    final id = await addHabit(tester);
    await tester.tap(find.byKey(const Key('tab_calendar')));
    await tester.pumpAndSettle();

    await swipe(tester, find.byKey(Key('dayHabit_$id')), const Offset(300, 0));
    expect(showing(CalendarScreen), isTrue, reason: 'a habit row');

    final day = DateTime.now();
    final firstOfMonth = find.byKey(Key('calendarDay_${day.year}-${day.month}-1'));
    await swipe(tester, firstOfMonth, const Offset(300, 0));
    expect(showing(CalendarScreen), isTrue, reason: 'the grid');
    expect(firstOfMonth, findsNothing, reason: 'now on last month');
  });

  testWidgets('a mostly vertical drag scrolls, and stays on the tab', (tester) async {
    await launch(tester);
    await swipe(tester, greeting(), const Offset(-60, -300));
    expect(showing(CalendarScreen), isFalse);
  });

  testWidgets('a page pushed on a tab does not swipe to another tab', (tester) async {
    await launch(tester);
    await tester.tap(find.byKey(const Key('tab_settings')));
    await tester.pumpAndSettle();
    // Below Display's rows, clear of the tab bar
    await tester.scrollUntilVisible(find.byKey(const Key('openCategories')).hitTestable(), 200,
        scrollable: find.byType(Scrollable).hitTestable().first);
    await tester.tap(find.byKey(const Key('openCategories')));
    await tester.pumpAndSettle();

    await swipe(tester, find.byType(CategoriesScreen), const Offset(-300, 0));
    await swipe(tester, find.byType(CategoriesScreen), const Offset(200, 0));
    expect(find.byType(CategoriesScreen).hitTestable(), findsOneWidget);
    expect(showing(InspireScreen), isFalse);
  });

  testWidgets('a notification tap during a swipe lands on Habits', (tester) async {
    await launch(tester);
    final id = await addHabit(tester);
    await tester.tap(find.byKey(const Key('tab_calendar')));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(calendarTitle()));
    await gesture.moveBy(const Offset(-40, 0));
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump();
    NotificationService.focusRequests.value = HabitFocusRequest(id);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(showing(HomeScreen), isTrue);
    expect(showing(InsightsScreen), isFalse);
  });

  group('sliding along the tab bar', () {
    testWidgets('picks the tab under the finger, and never adds', (tester) async {
      await launch(tester);
      final habits = tester.getCenter(find.byKey(const Key('tab_habits')));
      final insights = tester.getCenter(find.byKey(const Key('tab_insights')));
      await tester.dragFrom(habits, insights - habits);
      await tester.pumpAndSettle();
      expect(showing(InsightsScreen), isTrue);

      await tester.dragFrom(insights, habits - insights);
      await tester.pumpAndSettle();
      expect(showing(HomeScreen), isTrue);
      expect(find.byType(HabitEditorScreen), findsNothing);
    });
  });
}
