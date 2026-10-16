import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/presentation/widgets/category_icons.dart';
import 'package:atomic_momentum/presentation/widgets/category_rings_bar.dart';
import 'package:atomic_momentum/screens/home_screen.dart';

void main() {
  late HabitProvider habitProvider;
  late CategoryProvider categoryProvider;

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    habitProvider = get<HabitProvider>();
    categoryProvider = get<CategoryProvider>();

    for (final params in const [
      CreateHabitParams(name: 'Run', target: 1, color: HabitColor.orange, categoryId: BuiltInCategoryIds.body),
      CreateHabitParams(name: 'Stretch', target: 1, color: HabitColor.green, categoryId: BuiltInCategoryIds.body),
      CreateHabitParams(name: 'Read', target: 1, color: HabitColor.blue, categoryId: BuiltInCategoryIds.mind),
    ]) {
      await habitProvider.createHabit(params);
    }
    final run = habitProvider.habits.firstWhere((h) => h.name == 'Run');
    await habitProvider.updateHabitProgress(run.id, 1);
  });

  tearDown(() async {
    await resetDependencies();
  });

  // Narrowest current iPhone (SE / mini class)
  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: get<ThemeProvider>()),
        ChangeNotifierProvider<HabitProvider>.value(value: habitProvider),
        ChangeNotifierProvider<CategoryProvider>.value(value: categoryProvider),
        ChangeNotifierProvider<SettingsProvider>.value(value: get<SettingsProvider>()),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ));
    await tester.pumpAndSettle();
  }

  Finder ring(String id) => find.byKey(Key('categoryRing_$id'));

  testWidgets('all six rings fit on one row at 375pt with 44pt tap targets', (tester) async {
    await pumpHome(tester);

    final rects = Category.defaults.map((c) => tester.getRect(ring(c.id))).toList();
    expect(rects.map((r) => r.top).toSet(), hasLength(1), reason: 'single row');
    expect(rects.last.right, lessThanOrEqualTo(375));
    for (final r in rects) {
      expect(r.width, greaterThanOrEqualTo(44));
      expect(r.height, greaterThanOrEqualTo(44));
    }
    expect(tester.takeException(), isNull, reason: 'no layout overflow');
  });

  testWidgets('rings announce each category\'s progress to VoiceOver', (tester) async {
    await pumpHome(tester);

    expect(find.bySemanticsLabel('Body, 50 percent, 1 of 2 habits complete'), findsOneWidget);
    expect(find.bySemanticsLabel('Mind, 0 percent, 0 of 1 habits complete'), findsOneWidget);
    expect(find.bySemanticsLabel('Creative, no habits'), findsOneWidget);
  });

  testWidgets('a ring fills with partial progress, not just completed habits', (tester) async {
    await habitProvider.createHabit(const CreateHabitParams(
      name: 'Water', target: 8, color: HabitColor.blue, categoryId: BuiltInCategoryIds.social));
    final water = habitProvider.habits.firstWhere((h) => h.name == 'Water');
    await pumpHome(tester);
    expect(find.bySemanticsLabel('Social, 0 percent, 0 of 1 habits complete'), findsOneWidget);

    await habitProvider.updateHabitProgress(water.id, 4);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Social, 50 percent, 0 of 1 habits complete'), findsOneWidget);
  });

  testWidgets('rings use the flat category icons, not emoji', (tester) async {
    await pumpHome(tester);
    for (final c in Category.defaults) {
      expect(find.descendant(of: find.byType(CategoryRingsBar), matching: find.byIcon(c.icon)), findsOneWidget);
    }
    for (final emoji in ['💪', '🙏', '🧠', '👥', '💼', '🎨']) {
      expect(find.text(emoji), findsNothing);
    }
  });

  testWidgets('header shows all habits, and Show all clears a filter', (tester) async {
    await pumpHome(tester);
    String header() => tester.widget<Text>(find.byKey(const Key('filterHeaderLabel'))).data!;

    expect(header(), 'All habits · 3 habits');
    expect(find.byKey(const Key('showAllHabits')), findsNothing);

    await tester.tap(ring(BuiltInCategoryIds.mind));
    await tester.pumpAndSettle();
    expect(header(), 'Mind · 1 habit');

    final showAll = find.byKey(const Key('showAllHabits'));
    expect(tester.getSize(showAll).height, greaterThanOrEqualTo(44));
    await tester.tap(showAll);
    await tester.pumpAndSettle();

    expect(categoryProvider.selectedCategory, isNull);
    expect(header(), 'All habits · 3 habits');
    expect(find.text('Run'), findsOneWidget);
  });

  testWidgets('a habit on its rest day is labelled and left out of its ring', (tester) async {
    // Due only on tomorrow's weekday, so today is a rest day
    final tomorrowWeekday = DateTime.now().weekday % 7 + 1;
    await habitProvider.createHabit(CreateHabitParams(
      name: 'Pottery',
      target: 1,
      color: HabitColor.pink,
      categoryId: BuiltInCategoryIds.creative,
      scheduledWeekdays: [tomorrowWeekday],
    ));
    final pottery = habitProvider.habits.firstWhere((h) => h.name == 'Pottery');

    await pumpHome(tester);

    expect(
      find.descendant(of: find.byKey(Key('habitCard_${pottery.id}')), matching: find.textContaining('Rest day')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Creative, no habits'), findsOneWidget);
  });

  testWidgets('a habit in a deleted or unknown category shows under a grey Uncategorized ring', (tester) async {
    await habitProvider.createHabit(const CreateHabitParams(
      name: 'Pottery',
      target: 1,
      color: HabitColor.pink,
      categoryId: 'hobbies',
    ));
    final pottery = habitProvider.habits.firstWhere((h) => h.name == 'Pottery');

    await pumpHome(tester);

    expect(find.bySemanticsLabel('Uncategorized, 0 percent, 0 of 1 habits complete'), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(Key('habitCard_${pottery.id}')), matching: find.textContaining('Uncategorized')),
      findsOneWidget,
    );

    await tester.tap(ring(Category.uncategorizedId));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('filterHeaderLabel'))).data, 'Uncategorized · 1 habit');
    expect(find.text('Read'), findsNothing);
  });

  testWidgets('no Uncategorized ring while every habit has a category', (tester) async {
    await pumpHome(tester);
    expect(ring(Category.uncategorizedId), findsNothing);
  });

  testWidgets('tapping a ring filters; tapping it again shows all', (tester) async {
    await pumpHome(tester);
    expect(find.text('Read'), findsOneWidget);

    await tester.tap(ring(BuiltInCategoryIds.body));
    await tester.pumpAndSettle();
    expect(categoryProvider.selectedCategory?.id, BuiltInCategoryIds.body);
    expect(find.text('Run'), findsOneWidget);
    expect(find.text('Read'), findsNothing);

    await tester.tap(ring(BuiltInCategoryIds.body));
    await tester.pumpAndSettle();
    expect(categoryProvider.selectedCategory, isNull);
    expect(find.text('Read'), findsOneWidget);
  });

  testWidgets('an empty category shows the empty state with a way back', (tester) async {
    await pumpHome(tester);

    await tester.tap(ring(BuiltInCategoryIds.creative));
    await tester.pumpAndSettle();

    expect(find.text('No creative habits yet'), findsOneWidget);
    expect(find.textContaining('tap Show all'), findsOneWidget);
  });
}
