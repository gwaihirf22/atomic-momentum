import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/notification_service.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/main.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/widgets/habit_card.dart';
import 'package:atomic_momentum/screens/calendar_screen.dart';

/// Tapping a reminder or streak warning opens Habits at that habit's card.
void main() {
  late String lastId;
  late String firstId;

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    // Enough habits that the last one starts off screen
    final habits = get<HabitProvider>();
    for (var i = 1; i <= 12; i++) {
      await habits.createHabit(CreateHabitParams(
        name: 'Habit $i',
        target: 1,
        color: HabitColor.blue,
        categoryId: i == 12 ? BuiltInCategoryIds.mind : BuiltInCategoryIds.body,
      ));
    }
    lastId = habits.habits.firstWhere((h) => h.name == 'Habit 12').id;
    firstId = habits.habits.firstWhere((h) => h.name == 'Habit 1').id;
  });

  tearDown(() async {
    NotificationService.focusRequests.value = null;
    await resetDependencies();
  });

  Future<void> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MomentumApp());
    await tester.pumpAndSettle();
  }

  HabitCard card(WidgetTester tester, String id) =>
      tester.widget<HabitCard>(find.ancestor(of: find.byKey(Key('habitCard_$id')), matching: find.byType(HabitCard)));

  test('payloads name the habit: reminders, streak warnings; not test notifications', () {
    expect(NotificationService.habitIdFromPayload('reminder|habit_1'), 'habit_1');
    expect(NotificationService.habitIdFromPayload('habit_1'), 'habit_1');
    expect(NotificationService.habitIdFromPayload('reminder|'), isNull);
    expect(NotificationService.habitIdFromPayload(NotificationService.testPayload), isNull);
    expect(NotificationService.habitIdFromPayload(null), isNull);
    expect(NotificationService.habitIdFromPayload(''), isNull);
  });

  testWidgets('from another tab, with a filter hiding it: Habits opens at the card, highlighted', (tester) async {
    await launch(tester);
    get<CategoryProvider>().setSelectedCategoryId(BuiltInCategoryIds.body);
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarScreen).hitTestable(), findsOneWidget);

    NotificationService.handleTap('reminder|$lastId');
    // Switch tabs, then scroll (well within the 2 second highlight)
    await tester.pumpAndSettle();

    expect(find.byType(CalendarScreen).hitTestable(), findsNothing);
    expect(find.byKey(Key('habitCard_$lastId')).hitTestable(), findsOneWidget, reason: 'on the Habits tab');
    expect(get<CategoryProvider>().selectedCategory, isNull, reason: 'the filter hid the habit');
    expect(card(tester, lastId).highlighted, isTrue);
    final rect = tester.getRect(find.byKey(Key('habitCard_$lastId')));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(844), reason: 'scrolled into view');
    expect(NotificationService.focusRequests.value, isNull, reason: 'handled once');

    // The highlight fades after a moment
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(card(tester, lastId).highlighted, isFalse);
  });

  testWidgets('a streak warning (bare id) works the same', (tester) async {
    await launch(tester);
    NotificationService.handleTap(lastId);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(card(tester, lastId).highlighted, isTrue);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('an open Edit screen is closed so the card shows', (tester) async {
    await launch(tester);
    await tester.tap(find.byKey(Key('habitCard_$firstId')));
    await tester.pumpAndSettle();
    expect(find.text('Edit Habit'), findsOneWidget);

    NotificationService.handleTap('reminder|$lastId');
    await tester.pumpAndSettle();
    expect(find.text('Edit Habit'), findsNothing);
    expect(card(tester, lastId).highlighted, isTrue);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('a tap for a deleted habit just opens Habits', (tester) async {
    await launch(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    NotificationService.handleTap('reminder|gone');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('habitsGreeting')).hitTestable(), findsOneWidget);
    expect(NotificationService.focusRequests.value, isNull);
    expect(tester.takeException(), isNull);
  });
}
