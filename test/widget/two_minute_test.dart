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
import 'package:atomic_momentum/presentation/widgets/two_minute_button.dart';
import 'package:atomic_momentum/screens/add_habit_screen.dart';
import 'package:atomic_momentum/screens/calendar_screen.dart';
import 'package:atomic_momentum/screens/home_screen.dart';

void main() {
  late HabitProvider habits;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  const shoes = TwoMinuteVersion(description: 'Put on running shoes');

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    habits = get<HabitProvider>();
  });

  tearDown(resetDependencies);

  Future<String> create({String name = 'Run', int target = 1, TwoMinuteVersion? tiny = shoes}) async {
    await habits.createHabit(CreateHabitParams(
      name: name,
      target: target,
      color: HabitColor.orange,
      categoryId: BuiltInCategoryIds.body,
      twoMinute: tiny,
    ));
    return habits.habits.firstWhere((h) => h.name == name).id;
  }

  Future<void> pump(WidgetTester tester, Widget screen, {Size size = const Size(375, 1400)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: get<ThemeProvider>()),
        ChangeNotifierProvider<HabitProvider>.value(value: habits),
        ChangeNotifierProvider<CategoryProvider>.value(value: get<CategoryProvider>()),
        ChangeNotifierProvider<SettingsProvider>.value(value: get<SettingsProvider>()),
      ],
      child: MaterialApp(home: screen),
    ));
    await tester.pumpAndSettle();
  }

  TwoMinuteButton button(WidgetTester tester, String id) =>
      tester.widget<TwoMinuteButton>(find.byKey(Key('twoMinute_$id')));

  group('the card', () {
    testWidgets('shows "2 min" only for a habit with a two-minute version', (tester) async {
      final run = await create();
      final read = await create(name: 'Read', tiny: null);
      final hidden = await create(
        name: 'Stretch',
        tiny: const TwoMinuteVersion(description: 'One stretch', showOnCard: false),
      );
      await pump(tester, const HomeScreen());

      expect(find.byKey(Key('twoMinute_$run')), findsOneWidget);
      expect(find.byKey(Key('twoMinute_$read')), findsNothing);
      expect(find.byKey(Key('twoMinute_$hidden')), findsNothing, reason: '"Show on card" is off');
    });

    testWidgets('is hidden once the habit is done today', (tester) async {
      final run = await create();
      await habits.updateHabitProgress(run, 1);
      await pump(tester, const HomeScreen());
      expect(find.byKey(Key('twoMinute_$run')), findsNothing);
    });

    testWidgets('tapping it keeps the day, without opening Edit; Undo takes it back', (tester) async {
      final run = await create();
      await pump(tester, const HomeScreen());
      expect(button(tester, run).done, isFalse);

      await tester.tap(find.byKey(Key('twoMinute_$run')));
      await tester.pumpAndSettle();

      expect(find.byType(AddHabitScreen), findsNothing);
      expect(button(tester, run).done, isTrue);
      expect(habits.getHabitById(run)!.twoMinuteDays, {today});
      expect(habits.getHabitById(run)!.streak.current, 1);
      expect(find.textContaining('Put on running shoes'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(habits.getHabitById(run)!.twoMinuteDays, isEmpty);
      expect(button(tester, run).done, isFalse);
    });

    testWidgets('tapping it again undoes it', (tester) async {
      final run = await create();
      await pump(tester, const HomeScreen());

      await tester.tap(find.byKey(Key('twoMinute_$run')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('twoMinute_$run')));
      await tester.pumpAndSettle();

      expect(habits.getHabitById(run)!.twoMinuteDays, isEmpty);
    });

    testWidgets('reaching the two-minute amount shows it done, and it is not a toggle', (tester) async {
      final water = await create(
        name: 'Water',
        target: 8,
        tiny: const TwoMinuteVersion(description: 'One glass', minimum: 1),
      );
      await habits.updateHabitProgress(water, 1);
      await pump(tester, const HomeScreen());

      expect(button(tester, water).done, isTrue);
      expect(button(tester, water).onChanged, isNull);
    });

    testWidgets('its tap area is at least 32pt tall', (tester) async {
      final run = await create();
      await pump(tester, const HomeScreen());
      expect(tester.getSize(find.byKey(Key('twoMinute_$run'))).height,
          greaterThanOrEqualTo(TwoMinuteButton.minTapHeight));
    });
  });

  group('the form', () {
    Future<void> fillBasics(WidgetTester tester, {String target = '8'}) async {
      await tester.enterText(find.byType(TextFormField).at(0), 'Water');
      await tester.enterText(find.byType(TextFormField).at(1), target);
      await tester.pumpAndSettle();
    }

    testWidgets('saves a two-minute version with a minimum, hidden from the card', (tester) async {
      await pump(tester, const AddHabitScreen(), size: const Size(1200, 3000));
      await fillBasics(tester);

      expect(find.byKey(const Key('twoMinuteMinimum')), findsNothing, reason: 'only once there is a tiny version');
      await tester.enterText(find.byKey(const Key('twoMinuteField')), 'One glass');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('twoMinuteMinimum')), '1');
      await tester.tap(find.byKey(const Key('twoMinuteOnCard')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Habit'));
      await tester.pumpAndSettle();

      expect(habits.habits.single.twoMinute,
          const TwoMinuteVersion(description: 'One glass', minimum: 1, showOnCard: false));
    });

    testWidgets('a target of 1 has no minimum', (tester) async {
      await pump(tester, const AddHabitScreen(), size: const Size(1200, 3000));
      await fillBasics(tester, target: '1');
      await tester.enterText(find.byKey(const Key('twoMinuteField')), 'Put on shoes');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('twoMinuteMinimum')), findsNothing);
    });

    testWidgets('a minimum at or above the target is rejected', (tester) async {
      await pump(tester, const AddHabitScreen(), size: const Size(1200, 3000));
      await fillBasics(tester);
      await tester.enterText(find.byKey(const Key('twoMinuteField')), 'One glass');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('twoMinuteMinimum')), '8');

      await tester.tap(find.text('Add Habit'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a number from 1 to 7'), findsOneWidget);
      expect(habits.habits, isEmpty);
    });

    testWidgets('editing fills it in, and clearing it removes the version', (tester) async {
      final run = await create();
      await pump(tester, AddHabitScreen(editHabit: habits.getHabitById(run)), size: const Size(1200, 3000));

      expect(find.text('Put on running shoes'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('twoMinuteField')), '');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(habits.getHabitById(run)!.twoMinute, isNull);
    });

    testWidgets('habits that never reset have no two-minute version', (tester) async {
      await pump(tester, const AddHabitScreen(), size: const Size(1200, 3000));
      expect(find.byKey(const Key('twoMinuteField')), findsOneWidget);
      await tester.tap(find.byKey(const Key('frequency_never')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('twoMinuteField')), findsNothing);
    });
  });

  testWidgets('the Calendar marks a day with the two-minute version and shows it', (tester) async {
    final run = await create();
    await pump(tester, const CalendarScreen(), size: const Size(390, 1600));

    await tester.tap(find.byKey(Key('dayTwoMinute_$run')));
    await tester.pumpAndSettle();

    expect(habits.getHabitById(run)!.twoMinuteDays, {today});
    expect(find.textContaining('2-min version'), findsOneWidget);
  });
}
