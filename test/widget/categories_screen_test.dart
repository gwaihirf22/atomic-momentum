import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/repositories/category_repository.dart';
import 'package:atomic_momentum/domain/repositories/habit_repository.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/screens/add_habit_screen.dart';
import 'package:atomic_momentum/screens/categories_screen.dart';

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
    ]) {
      await habitProvider.createHabit(params);
    }
  });

  tearDown(() async {
    await resetDependencies();
  });

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: get<ThemeProvider>()),
        ChangeNotifierProvider<HabitProvider>.value(value: habitProvider),
        ChangeNotifierProvider<CategoryProvider>.value(value: categoryProvider),
        ChangeNotifierProvider<SettingsProvider>.value(value: get<SettingsProvider>()),
      ],
      child: MaterialApp(home: screen),
    ));
    await tester.pumpAndSettle();
  }

  Finder row(String id) => find.byKey(Key('categoryRow_$id'));
  Future<List<Category>> stored(WidgetTester tester) async =>
      (await tester.runAsync(() => get<CategoryRepository>().getAll()))!;

  Future<void> openEditor(WidgetTester tester, String id) async {
    await tester.tap(find.descendant(of: row(id), matching: find.byType(ListTile)).first);
    await tester.pumpAndSettle();
  }

  Future<void> deleteViaEditor(WidgetTester tester, String id) async {
    await openEditor(tester, id);
    await tester.tap(find.byKey(const Key('deleteCategory')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmDeleteCategory')));
    await tester.pumpAndSettle();
  }

  bool saveEnabled(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.byKey(const Key('saveCategory'))).onPressed != null;

  testWidgets('lists the categories with their habit counts', (tester) async {
    await pump(tester, const CategoriesScreen());

    for (final c in Category.defaults) {
      expect(row(c.id), findsOneWidget);
    }
    expect(find.descendant(of: row(BuiltInCategoryIds.body), matching: find.text('2 habits')), findsOneWidget);
    expect(find.descendant(of: row(BuiltInCategoryIds.mind), matching: find.text('No habits')), findsOneWidget);
    expect(find.text('Recently Deleted'), findsNothing);
  });

  testWidgets('adds a category with a chosen color and icon', (tester) async {
    await pump(tester, const CategoriesScreen());

    await tester.tap(find.byKey(const Key('addCategory')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('categoryNameField')), 'Hobbies');
    await tester.tap(find.byKey(const Key('categoryColorSwatch_Teal')));
    await tester.tap(find.byKey(const Key('categoryIconSwatch_music_note')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveCategory')));
    await tester.pumpAndSettle();

    final hobbies = (await stored(tester)).last;
    expect([hobbies.name, hobbies.colorValue, hobbies.iconKey], ['Hobbies', HabitColor.teal.value, 'music_note']);
    expect(row(hobbies.id), findsOneWidget);
  });

  testWidgets('name problems are shown and block saving', (tester) async {
    await pump(tester, const CategoriesScreen());
    await tester.tap(find.byKey(const Key('addCategory')));
    await tester.pumpAndSettle();

    expect(saveEnabled(tester), isFalse, reason: 'empty name');

    await tester.enterText(find.byKey(const Key('categoryNameField')), 'body');
    await tester.pumpAndSettle();
    expect(find.text('You already have a category called Body'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);

    await tester.enterText(find.byKey(const Key('categoryNameField')), 'Garden');
    await tester.pumpAndSettle();
    expect(saveEnabled(tester), isTrue);
  });

  testWidgets('renaming a built-in category keeps its habits attached', (tester) async {
    await pump(tester, const CategoriesScreen());
    await openEditor(tester, BuiltInCategoryIds.body);

    await tester.enterText(find.byKey(const Key('categoryNameField')), 'Fitness');
    await tester.tap(find.byKey(const Key('saveCategory')));
    await tester.pumpAndSettle();

    expect(find.descendant(of: row(BuiltInCategoryIds.body), matching: find.text('Fitness')), findsOneWidget);
    expect(categoryProvider.resolve(habitProvider.habits.first.categoryId).name, 'Fitness');
    final storedHabits = (await tester.runAsync(() => get<HabitRepository>().getHabits()))!;
    expect(storedHabits.map((h) => h.categoryId).toSet(), {BuiltInCategoryIds.body});
  });

  testWidgets('dragging a category reorders it, and the order is saved', (tester) async {
    await pump(tester, const CategoriesScreen());

    await tester.drag(find.byKey(const Key('dragHandle_creative')), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(categoryProvider.categories.first.id, BuiltInCategoryIds.creative);
    expect((await stored(tester)).first.id, BuiltInCategoryIds.creative);
  });

  testWidgets('deleting a category with habits keeps them as Uncategorized', (tester) async {
    await pump(tester, const CategoriesScreen());
    await openEditor(tester, BuiltInCategoryIds.body);
    await tester.tap(find.byKey(const Key('deleteCategory')));
    await tester.pumpAndSettle();

    expect(find.textContaining('2 habits and their streaks are kept and shown as Uncategorized'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmDeleteCategory')));
    await tester.pumpAndSettle();

    expect(row(BuiltInCategoryIds.body), findsNothing);
    expect(find.text('Recently Deleted'), findsOneWidget);
    expect(find.byKey(const Key('moveHabits_body')), findsOneWidget);
    expect(find.byKey(const Key('deletePermanently_body')), findsNothing,
        reason: 'not while it still has habits');
    expect(categoryProvider.filterOptions(habitProvider.habits).last, Category.uncategorized);
    expect(habitProvider.habits, hasLength(2), reason: 'habits are kept');

    // No longer offered when adding a habit
    await tester.pumpWidget(const SizedBox());
    await pump(tester, const AddHabitScreen());
    expect(find.byKey(const Key('categoryChip_body')), findsNothing);
  });

  testWidgets('restoring brings the category back at the end', (tester) async {
    await pump(tester, const CategoriesScreen());
    await deleteViaEditor(tester, BuiltInCategoryIds.body);

    await tester.tap(find.byKey(const Key('restoreCategory_body')));
    await tester.pumpAndSettle();

    expect(categoryProvider.categories.last.id, BuiltInCategoryIds.body);
    expect(find.text('Recently Deleted'), findsNothing);
    expect(categoryProvider.filterOptions(habitProvider.habits), isNot(contains(Category.uncategorized)));
  });

  testWidgets('move habits out, then delete permanently', (tester) async {
    await pump(tester, const CategoriesScreen());
    await deleteViaEditor(tester, BuiltInCategoryIds.body);

    await tester.tap(find.byKey(const Key('moveHabits_body')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moveTarget_mind')));
    await tester.pumpAndSettle();

    expect(habitProvider.habits.map((h) => h.categoryId).toSet(), {BuiltInCategoryIds.mind});
    expect(find.text('Moved 2 habits to Mind'), findsOneWidget);

    await tester.tap(find.byKey(const Key('deletePermanently_body')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmDeletePermanently')));
    await tester.pumpAndSettle();

    expect((await stored(tester)).map((c) => c.id), isNot(contains(BuiltInCategoryIds.body)));
    expect(find.text('Recently Deleted'), findsNothing);
  });

  testWidgets('the last category cannot be deleted', (tester) async {
    await tester.runAsync(() async {
      for (final id in BuiltInCategoryIds.all.skip(1)) {
        await categoryProvider.delete(id);
      }
    });
    await pump(tester, const CategoriesScreen());
    await openEditor(tester, BuiltInCategoryIds.body);

    expect(tester.widget<TextButton>(find.byKey(const Key('deleteCategory'))).onPressed, isNull);
    expect(find.text('Keep at least one category'), findsOneWidget);
  });

  testWidgets('at 24 categories Add is disabled and restoring explains why it can\'t', (tester) async {
    await tester.runAsync(() async {
      await categoryProvider.delete(BuiltInCategoryIds.mind);
      for (var i = 1; i <= 19; i++) {
        await categoryProvider.add(name: 'Extra $i', iconKey: 'star', colorValue: 0xFF607D8B);
      }
    });
    await pump(tester, const CategoriesScreen());

    expect(tester.widget<IconButton>(find.byKey(const Key('addCategory'))).onPressed, isNull);
    expect(find.text('You can have up to 24 categories.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('restoreCategory_mind')));
    await tester.pumpAndSettle();
    expect(find.text('You already have 24 categories. Delete one first.'), findsOneWidget);
  });

  testWidgets('restoring renames on a clash and says so', (tester) async {
    await tester.runAsync(() async {
      await categoryProvider.delete(BuiltInCategoryIds.mind);
      await categoryProvider.add(name: 'Mind', iconKey: 'star', colorValue: 0xFF607D8B);
    });
    await pump(tester, const CategoriesScreen());

    await tester.tap(find.byKey(const Key('restoreCategory_mind')));
    await tester.pumpAndSettle();

    expect(find.text('Restored as "Mind 2"'), findsOneWidget);
    expect(categoryProvider.resolve(BuiltInCategoryIds.mind).name, 'Mind 2');
  });

  testWidgets('deleting the category the Habits screen is filtered to clears the filter', (tester) async {
    categoryProvider.setSelectedCategoryId(BuiltInCategoryIds.body);
    await pump(tester, const CategoriesScreen());

    await deleteViaEditor(tester, BuiltInCategoryIds.body);

    expect(categoryProvider.selectedCategoryId, isNull);
  });
}
