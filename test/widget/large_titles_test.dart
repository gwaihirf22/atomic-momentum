import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/copy/greetings.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/presentation/widgets/large_title_scaffold.dart';
import 'package:atomic_momentum/screens/calendar_screen.dart';
import 'package:atomic_momentum/screens/home_screen.dart';

void main() {
  late HabitProvider habits;

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    habits = get<HabitProvider>();
  });

  tearDown(() async {
    await resetDependencies();
  });

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(402, 874);
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

  Future<String> addHabit(String name) async {
    await habits.createHabit(CreateHabitParams(
      name: name,
      target: 1,
      color: HabitColor.blue,
      categoryId: BuiltInCategoryIds.body,
    ));
    return habits.habits.firstWhere((h) => h.name == name).id;
  }

  group('Habits header', () {
    testWidgets("greets by time of day in the display font, under today's date", (tester) async {
      await pump(tester, const HomeScreen());
      final now = DateTime.now();

      final greeting = tester.widget<Text>(find.byKey(const Key('habitsGreeting')));
      expect(Greetings.lines[Greetings.partOf(now)], contains(greeting.data));
      expect(greeting.style!.fontFamily, LargeTitleHeader.fontFamily);
      expect(find.text(DateFormat.MMMMEEEEd().format(now).toUpperCase()), findsOneWidget);
    });

    testWidgets('shows overall momentum once something is logged', (tester) async {
      final id = await addHabit('Stretch');
      await pump(tester, const HomeScreen());
      expect(find.byKey(const Key('overallMomentum')), findsNothing);

      final now = DateTime.now();
      for (var i = 1; i <= 5; i++) {
        await habits.updateProgressForDate(id, DateTime(now.year, now.month, now.day - i), 1);
      }
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('overallMomentum')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Overall momentum \d+, rising$')), findsOneWidget);
    });

    testWidgets('the small title appears in the bar once the large one scrolls away', (tester) async {
      for (var i = 0; i < 8; i++) {
        await addHabit('Habit $i');
      }
      await pump(tester, const HomeScreen());

      double barTitleOpacity() => tester.widget<AnimatedOpacity>(find.byKey(const Key('collapsedTitle'))).opacity;
      expect(barTitleOpacity(), 0);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(barTitleOpacity(), 1);
    });
  });

  group('Calendar header', () {
    testWidgets('the month is the large title, and the arrows page through months', (tester) async {
      await pump(tester, const CalendarScreen());
      final now = DateTime.now();
      String title() => tester.widget<Text>(find.byKey(const Key('calendarMonthTitle'))).data!;

      expect(title(), DateFormat.MMMM().format(now));
      await tester.tap(find.bySemanticsLabel('Next month'));
      await tester.pumpAndSettle();
      expect(title(), DateFormat.MMMM().format(DateTime(now.year, now.month + 1, 1)));

      await tester.tap(find.byIcon(CupertinoIcons.chevron_left));
      await tester.tap(find.byIcon(CupertinoIcons.chevron_left));
      await tester.pumpAndSettle();
      expect(title(), DateFormat.MMMM().format(DateTime(now.year, now.month - 1, 1)));
    });
  });
}
