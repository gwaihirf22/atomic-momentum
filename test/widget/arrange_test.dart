import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/screens/categories_screen.dart';

void main() {
  late HabitProvider habits;
  late CategoryProvider categories;

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    habits = get<HabitProvider>();
    categories = get<CategoryProvider>();
    await habits.loadHabits();
    for (final (name, category) in const [
      ('Read', BuiltInCategoryIds.mind),
      ('Water', BuiltInCategoryIds.body),
      ('Pray', BuiltInCategoryIds.spirit),
      ('Gym', BuiltInCategoryIds.body),
    ]) {
      await habits.createHabit(CreateHabitParams(name: name, target: 1, color: HabitColor.blue, categoryId: category));
    }
  });

  tearDown(resetDependencies);

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: get<ThemeProvider>()),
        ChangeNotifierProvider<HabitProvider>.value(value: habits),
        ChangeNotifierProvider<CategoryProvider>.value(value: categories),
        ChangeNotifierProvider<SettingsProvider>.value(value: get<SettingsProvider>()),
      ],
      child: MaterialApp(theme: ThemeData(platform: TargetPlatform.iOS), home: const CategoriesScreen()),
    ));
    await tester.pumpAndSettle();
  }

  List<String> names() => [for (final h in habits.habits) h.name];
  String id(String name) => habits.habits.firstWhere((h) => h.name == name).id;
  Finder habitHandle(String name) => find.byKey(Key('habitDragHandle_${id(name)}'));
  Finder categoryHandle(String id) => find.byKey(Key('dragHandle_$id'));

  /// Drags [handle] by [dy] in small steps, as a finger would.
  Future<void> drag(WidgetTester tester, Finder handle, double dy) async {
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(Offset(0, dy / 20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  void moveBy(WidgetTester tester, Finder row, String action) {
    final semantics = tester.widget<Semantics>(find.descendant(of: row, matching: find.byType(Semantics)).first);
    semantics.properties.customSemanticsActions!.entries.firstWhere((e) => e.key.label == action).value();
  }

  testWidgets('grouped: each category followed by its habits, in the order they show on Habits', (tester) async {
    await pump(tester);
    expect(find.text('Arrange'), findsOneWidget);
    final top = {
      for (final name in ['Water', 'Gym', 'Pray', 'Read']) name: tester.getTopLeft(find.byKey(Key('arrangeHabit_${id(name)}'))).dy,
    };
    expect(top['Water']! < top['Gym']! && top['Gym']! < top['Pray']! && top['Pray']! < top['Read']!, isTrue);
    expect(tester.getTopLeft(find.byKey(const Key('categoryRow_spirit'))).dy, lessThan(top['Pray']!));
  });

  testWidgets('dragging a category moves its habits with it', (tester) async {
    await pump(tester);
    // Spirit above Body
    await drag(tester, categoryHandle(BuiltInCategoryIds.spirit), -260);
    expect(categories.categories.first.id, BuiltInCategoryIds.spirit);
    expect(names(), ['Pray', 'Water', 'Gym', 'Read']);
  });

  testWidgets('a habit drags within its category', (tester) async {
    await pump(tester);
    await drag(tester, habitHandle('Gym'), -70);
    expect(names(), ['Gym', 'Water', 'Pray', 'Read']);
  });

  testWidgets('dropped in another category, a habit goes back where it was', (tester) async {
    await pump(tester);
    await drag(tester, habitHandle('Read'), -400);
    expect(names(), ['Water', 'Gym', 'Pray', 'Read']);
    expect(find.textContaining('Habits move within their category'), findsOneWidget);
  });

  testWidgets('VoiceOver can move rows up and down', (tester) async {
    await pump(tester);
    moveBy(tester, find.byKey(Key('arrangeHabit_${id('Water')}')), 'Move down');
    await tester.pumpAndSettle();
    expect(names(), ['Gym', 'Water', 'Pray', 'Read']);
    moveBy(tester, find.byKey(const Key('categoryRow_mind')), 'Move up');
    await tester.pumpAndSettle();
    expect(names(), ['Gym', 'Water', 'Read', 'Pray']);
  });

  testWidgets('grouping off: categories and habits each in their own list, any order', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('groupByCategorySwitch')));
    await tester.pumpAndSettle();
    expect(habits.groupByCategory, isFalse);
    expect(find.text('HABITS').evaluate().isNotEmpty || find.text('Habits').evaluate().isNotEmpty, isTrue);
    // Read (Mind) to the top, ahead of the Body habits
    await drag(tester, habitHandle('Read'), -220);
    expect(names().first, 'Read');
    expect(names(), unorderedEquals(['Water', 'Gym', 'Pray', 'Read']));
  });

  testWidgets("a deleted category's habits show last, under Uncategorized", (tester) async {
    await categories.delete(BuiltInCategoryIds.body);
    await pump(tester);
    expect(names(), ['Pray', 'Read', 'Water', 'Gym']);
    final uncategorized = find.byKey(const Key('categoryRow_${Category.uncategorizedId}'));
    expect(uncategorized, findsOneWidget);
    expect(categoryHandle(Category.uncategorizedId), findsNothing, reason: "Uncategorized doesn't move");
    expect(tester.getTopLeft(uncategorized).dy, lessThan(tester.getTopLeft(find.byKey(Key('arrangeHabit_${id('Water')}'))).dy));
  });
}
