import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/freeze_bank.dart';
import 'package:atomic_momentum/core/services/notification_service.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/repositories/habit_repository.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/main.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/screens/habit_detail_screen.dart';
import 'package:atomic_momentum/screens/settings_screen.dart';
import 'package:atomic_momentum/presentation/widgets/freezes_settings_section.dart';

/// Freezes and vacation mode on screen: the habit page, the card's swipe,
/// Settings and the Habits banner.
void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime ago(int n) => DateTime(today.year, today.month, today.day - n);

  late HabitProvider habits;
  late String id;

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies();
    habits = get<HabitProvider>();
    await habits.loadHabits();
    await habits.createHabit(const CreateHabitParams(
      name: 'Read',
      target: 1,
      color: HabitColor.teal,
      categoryId: BuiltInCategoryIds.mind,
    ));
    id = habits.habits.single.id;
  });

  tearDown(resetDependencies);

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(390, 3000);
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

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  testWidgets('the habit page freezes today and takes it back', (tester) async {
    await pump(tester, HabitDetailScreen(habitId: id));
    expect(find.text('Freeze · 3 left'), findsOneWidget);

    await tap(tester, 'detailFreeze');
    expect(get<FreezeBank>().available, 2);
    // In place of "TODAY": how long the freeze still holds
    expect(find.textContaining(RegExp(r'^FROZEN · \d+ (HOURS?|MIN) LEFT$')), findsOneWidget);
    expect(find.textContaining('Neither kept nor missed'), findsOneWidget);

    await tap(tester, 'detailUnfreeze');
    expect(get<FreezeBank>().available, 3);
    expect(find.text('TODAY'), findsOneWidget);
  });

  testWidgets('with the streak at risk, the miss before can be frozen from today', (tester) async {
    final habit = habits.habits.single;
    await get<HabitRepository>().saveHabit(habit.copyWith(history: {for (var d = 6; d >= 2; d--) ago(d): 1}));
    await habits.loadHabits();
    expect(habits.getHabitById(id)!.streak.atRisk, isTrue);

    await pump(tester, HabitDetailScreen(habitId: id));
    expect(find.text('Freeze yesterday'), findsOneWidget);
    await tap(tester, 'detailFreezeMissed');
    final read = habits.getHabitById(id)!;
    expect(read.isFrozenOn(ago(1)), isTrue);
    expect(read.streak.atRisk, isFalse, reason: 'the miss no longer counts');
    expect(read.streak.current, 5);
  });

  testWidgets('an empty bank says so', (tester) async {
    final bank = get<FreezeBank>();
    for (var i = 0; i < 3; i++) {
      await bank.spend(now);
    }
    await pump(tester, HabitDetailScreen(habitId: id));
    expect(find.text('No freezes left'), findsOneWidget);
  });

  testWidgets('Settings shows the bank and turns vacation mode on and off', (tester) async {
    await pump(tester, const SettingsScreen());
    await tester.scrollUntilVisible(find.byKey(const Key('vacationSwitch')), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('3 of 5'), findsOneWidget);

    await tester.tap(find.descendant(of: find.byKey(const Key('vacationSwitch')), matching: find.byType(Switch)));
    await tester.pumpAndSettle();
    expect(habits.onVacation, isTrue);
    expect(find.text('On: nothing is due, no reminders'), findsOneWidget);
  });

  testWidgets('the Habits screen: swipe right to freeze today; the vacation banner turns it off', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MomentumApp());
    await tester.pumpAndSettle();
    final shown = tester.element(find.byKey(Key('habitCard_$id'))).read<HabitProvider>();

    await tester.drag(find.byKey(Key('habitCard_$id')), const Offset(150, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('freezeHabit_$id')));
    await tester.pumpAndSettle();
    expect(shown.getHabitById(id)!.isFrozenOn(now), isTrue);
    expect(find.byKey(Key('habitFrozen_$id')), findsOneWidget);
    expect(find.textContaining(RegExp(r'^Frozen · \d+ (hours?|min) left$')), findsOneWidget);
    expect(find.textContaining('is frozen for today'), findsOneWidget);
    // The first freeze is worth a (fun) celebration
    expect(find.text('Brain freeze'), findsOneWidget);
    await tester.tap(find.byKey(const Key('achievementDone')));
    await tester.pumpAndSettle();

    await shown.startVacation();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vacationBanner')), findsOneWidget);
    await tester.tap(find.byKey(const Key('vacationEnd')));
    await tester.pumpAndSettle();
    expect(shown.onVacation, isFalse);
    expect(find.byKey(const Key('vacationBanner')), findsNothing);
  });

  testWidgets('on vacation, Settings offers a return date, and its check-ins can be turned off', (tester) async {
    await habits.startVacation();
    await pump(tester, const SettingsScreen());
    await tester.scrollUntilVisible(find.byKey(const Key('vacationNotices')), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Add a date'), findsOneWidget);
    expect(find.textContaining('A check-in every few days'), findsOneWidget);

    final back = DateTime(today.year, today.month, today.day + 5);
    await habits.setVacationReturn(back);
    await tester.pumpAndSettle();
    expect(find.text(FreezesSettingsSection.dayLabel(back)), findsOneWidget);
    expect(find.text('A welcome back on ${FreezesSettingsSection.dayLabel(back)}'), findsOneWidget);

    await tester.tap(find.descendant(of: find.byKey(const Key('vacationNotices')), matching: find.byType(Switch)));
    await tester.pumpAndSettle();
    expect(get<SettingsProvider>().vacationNotices, isFalse);
  });

  testWidgets('a set return date can be taken off from Settings', (tester) async {
    await habits.startVacation(back: DateTime(today.year, today.month, today.day + 3));
    await pump(tester, const SettingsScreen());
    await tester.scrollUntilVisible(find.byKey(const Key('vacationBack')), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('vacationBack')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vacationBackClear')));
    await tester.pumpAndSettle();
    expect(habits.vacationBack, isNull);
    expect(habits.onVacation, isTrue);
    expect(find.text('Add a date'), findsOneWidget);
  });

  testWidgets('the banner says when vacation ends; "I\'m back" on a check-in ends it', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final back = DateTime(today.year, today.month, today.day + 4);
    await habits.startVacation(back: back);
    await tester.pumpWidget(const MomentumApp());
    await tester.pumpAndSettle();
    final shown = tester.element(find.byKey(const Key('vacationBanner'))).read<HabitProvider>();
    expect(find.textContaining('On vacation until ${FreezesSettingsSection.dayLabel(back)}'), findsOneWidget);

    NotificationService.handleResponse(NotificationService.vacationBackAction, NotificationService.vacationPayload);
    await tester.pumpAndSettle();
    expect(shown.onVacation, isFalse);
    expect(find.byKey(const Key('vacationBanner')), findsNothing);
  });
}
