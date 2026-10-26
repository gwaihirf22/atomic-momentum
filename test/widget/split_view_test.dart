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
import 'package:atomic_momentum/presentation/layout/card_columns.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/tour/tour_controller.dart';
import 'package:atomic_momentum/screens/habit_detail_screen.dart';

/// A habit's page beside the list on wide windows (iPad sideways), the
/// Calendar's month beside its day, and cards in columns.
void main() {
  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({
      TourStore.key: ['habits', 'calendar', 'insights', 'inspire', 'settings', 'arrange', 'habitPage'],
    });
    await initializeDependencies(seedDefaultHabit: false);
  });

  tearDown(resetDependencies);

  late HabitProvider habits;

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MomentumApp());
    await tester.pumpAndSettle();
    habits = tester.element(find.byKey(const Key('tab_habits'))).read<HabitProvider>();
    for (final name in ['Walk', 'Read']) {
      await habits.createHabit(
          CreateHabitParams(name: name, target: 2, color: HabitColor.blue, categoryId: BuiltInCategoryIds.body));
    }
    await tester.pumpAndSettle();
  }

  String idOf(String name) => habits.habits.firstWhere((h) => h.name == name).id;
  Finder card(String name) => find.byKey(Key('habitCard_${idOf(name)}'));
  Finder pane(String name) => find.byKey(Key('paneHabit_${idOf(name)}'));
  final pick = find.byKey(const Key('pickAHabit'));

  const wide = Size(1194, 834);

  testWidgets('wide: a tapped card opens beside the list, highlighted; another replaces it', (tester) async {
    await pumpAt(tester, wide);
    expect(pick, findsOneWidget);

    await tester.tap(card('Walk'));
    await tester.pumpAndSettle();
    expect(pane('Walk'), findsOneWidget);
    expect(pick, findsNothing);
    // The list is still there, beside it
    expect(card('Read').hitTestable(), findsOneWidget);
    expect(tester.getTopLeft(pane('Walk')).dx, greaterThan(tester.getTopRight(card('Read')).dx));

    await tester.tap(card('Read'));
    await tester.pumpAndSettle();
    expect(pane('Read'), findsOneWidget);
    expect(pane('Walk'), findsNothing);

    // Logging on the page shows on the card, and the other way round
    await habits.updateHabitProgress(idOf('Read'), 1);
    await tester.pumpAndSettle();
    expect(find.descendant(of: pane('Read'), matching: find.text('1')), findsWidgets);
  });

  testWidgets('wide: deleting the habit showing leaves "Pick a habit"', (tester) async {
    await pumpAt(tester, wide);
    await tester.tap(card('Walk'));
    await tester.pumpAndSettle();
    await habits.deleteHabit(idOf('Walk'));
    await tester.pumpAndSettle();
    expect(pick, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a notification tap opens its habit beside the list', (tester) async {
    await pumpAt(tester, wide);
    NotificationService.focusRequests.value = HabitFocusRequest(idOf('Read'));
    await tester.pumpAndSettle();
    expect(pane('Read'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('narrowing the window moves the habit showing onto the Habits stack', (tester) async {
    await pumpAt(tester, wide);
    await tester.tap(card('Walk'));
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(834, 1194);
    await tester.pumpAndSettle();
    expect(pick, findsNothing);
    expect(find.byType(HabitDetailScreen), findsOneWidget);
    expect(card('Walk').hitTestable(), findsNothing, reason: 'the page, pushed over the list');
  });

  testWidgets('upright (regular) and on a phone, a card pushes the page as before', (tester) async {
    await pumpAt(tester, const Size(834, 1194));
    expect(pick, findsNothing);
    await tester.tap(card('Walk'));
    await tester.pumpAndSettle();
    expect(find.byType(HabitDetailScreen), findsOneWidget);
    expect(card('Walk').hitTestable(), findsNothing);
  });

  testWidgets('Calendar, wide: the month beside the day\'s habits, cells sized by their pane', (tester) async {
    await pumpAt(tester, wide);
    await tester.tap(find.byKey(const Key('tab_calendar')));
    await tester.pumpAndSettle();
    final grid = tester.getRect(find.byKey(const Key('calendarGrid')));
    final heading = tester.getRect(find.byKey(const Key('calendarDayTitle')));
    expect(heading.left, greaterThanOrEqualTo(grid.right - 1));
    expect(heading.top, lessThan(grid.bottom));
    expect(find.text('Walk').hitTestable(), findsOneWidget);
  });

  testWidgets('Calendar on a phone: cells fit a seventh of the width', (tester) async {
    await pumpAt(tester, const Size(375, 667));
    await tester.tap(find.byKey(const Key('tab_calendar')));
    await tester.pumpAndSettle();
    final grid = tester.getRect(find.byKey(const Key('calendarGrid')));
    expect(grid.width, lessThanOrEqualTo(375));
    expect(grid.top, lessThan(tester.getRect(find.byKey(const Key('calendarDayTitle'))).top));
  });

  testWidgets('cards go into columns where they fit, in reading order', (tester) async {
    Future<void> pumpCards(double width) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: SingleChildScrollView(
          child: CardColumns(children: [
            for (var i = 0; i < 4; i++) SizedBox(key: Key('card$i'), height: 50 + 10.0 * i),
          ]),
        ),
      ));
    }

    await pumpCards(390);
    for (var i = 1; i < 4; i++) {
      expect(tester.getTopLeft(find.byKey(Key('card$i'))).dy,
          greaterThan(tester.getTopLeft(find.byKey(Key('card${i - 1}'))).dy));
    }

    await pumpCards(900);
    final c0 = tester.getRect(find.byKey(const Key('card0')));
    final c1 = tester.getRect(find.byKey(const Key('card1')));
    final c2 = tester.getRect(find.byKey(const Key('card2')));
    expect(c1.top, c0.top, reason: 'side by side');
    expect(c1.left, greaterThan(c0.right));
    expect(c2.left, c0.left, reason: 'then down');
    expect(c2.top, greaterThan(c0.bottom));
  });
}
