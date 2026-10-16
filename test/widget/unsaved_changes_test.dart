import 'package:flutter/material.dart';
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
  });

  tearDown(() async {
    await resetDependencies();
  });

  /// Shows a launcher screen and pushes [screen] on top, so leaving can be tested.
  Future<void> openOnTop(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: get<ThemeProvider>()),
        ChangeNotifierProvider<HabitProvider>.value(value: habitProvider),
        ChangeNotifierProvider<CategoryProvider>.value(value: categoryProvider),
        ChangeNotifierProvider<SettingsProvider>.value(value: get<SettingsProvider>()),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('launcher'),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('launcher')));
    await tester.pumpAndSettle();
  }

  Finder discardDialog() => find.text('Discard changes?');

  group('Add/Edit Habit', () {
    testWidgets('leaving an untouched form needs no confirmation', (tester) async {
      await openOnTop(tester, const AddHabitScreen());

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(discardDialog(), findsNothing);
      expect(find.byType(AddHabitScreen), findsNothing);
    });

    testWidgets('typed changes: Keep Editing stays, Discard leaves without saving', (tester) async {
      await openOnTop(tester, const AddHabitScreen());
      await tester.enterText(find.byType(TextFormField).at(0), 'Meditate');
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(discardDialog(), findsOneWidget);

      await tester.tap(find.byKey(const Key('keepEditing')));
      await tester.pumpAndSettle();
      expect(find.byType(AddHabitScreen), findsOneWidget);
      expect(find.text('Meditate'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('discardChanges')));
      await tester.pumpAndSettle();
      expect(find.byType(AddHabitScreen), findsNothing);
      expect(habitProvider.habits, isEmpty);
    });

    testWidgets('choices made without typing also count as changes', (tester) async {
      await openOnTop(tester, const AddHabitScreen());
      await tester.tap(find.byKey(const Key('colorSwatch_Green')));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(discardDialog(), findsOneWidget);
    });

    testWidgets('editing a habit: discarding keeps the saved version', (tester) async {
      await habitProvider.createHabit(const CreateHabitParams(
        name: 'Read',
        target: 2,
        color: HabitColor.teal,
        categoryId: BuiltInCategoryIds.mind,
      ));
      await openOnTop(tester, AddHabitScreen(editHabit: habitProvider.habits.single));

      await tester.enterText(find.byType(TextFormField).at(1), '5');
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('discardChanges')));
      await tester.pumpAndSettle();

      expect(habitProvider.habits.single.target, 2);
    });

    testWidgets('changing a field and changing it back is not a change', (tester) async {
      await habitProvider.createHabit(const CreateHabitParams(
        name: 'Read',
        target: 2,
        color: HabitColor.teal,
        categoryId: BuiltInCategoryIds.mind,
      ));
      await openOnTop(tester, AddHabitScreen(editHabit: habitProvider.habits.single));

      await tester.enterText(find.byType(TextFormField).at(1), '5');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(1), '2');
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(discardDialog(), findsNothing);
      expect(find.byType(AddHabitScreen), findsNothing);
    });

    testWidgets('saving leaves without asking', (tester) async {
      await openOnTop(tester, const AddHabitScreen());
      await tester.enterText(find.byType(TextFormField).at(0), 'Meditate');
      await tester.enterText(find.byType(TextFormField).at(1), '1');

      await tester.tap(find.text('Add Habit'));
      await tester.pumpAndSettle();

      expect(discardDialog(), findsNothing);
      expect(find.byType(AddHabitScreen), findsNothing);
      expect(habitProvider.habits.single.name, 'Meditate');
    });
  });

  group('Category editor', () {
    Future<void> openNewCategory(WidgetTester tester) async {
      await openOnTop(tester, const CategoriesScreen());
      await tester.tap(find.byKey(const Key('addCategory')));
      await tester.pumpAndSettle();
    }

    Finder sheet() => find.byKey(const Key('categoryNameField'));

    testWidgets('Cancel on an untouched sheet closes it straight away', (tester) async {
      await openNewCategory(tester);

      await tester.tap(find.byKey(const Key('cancelCategoryEdit')));
      await tester.pumpAndSettle();

      expect(discardDialog(), findsNothing);
      expect(sheet(), findsNothing);
    });

    testWidgets('tapping outside with changes asks; Keep Editing keeps the sheet', (tester) async {
      await openNewCategory(tester);
      await tester.enterText(sheet(), 'Garden');
      await tester.pumpAndSettle();

      // The barrier above the sheet
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(discardDialog(), findsOneWidget);

      await tester.tap(find.byKey(const Key('keepEditing')));
      await tester.pumpAndSettle();
      expect(sheet(), findsOneWidget);
      expect(find.text('Garden'), findsWidgets);

      await tester.tap(find.byKey(const Key('cancelCategoryEdit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('discardChanges')));
      await tester.pumpAndSettle();

      expect(sheet(), findsNothing);
      expect(categoryProvider.categories.map((c) => c.name), isNot(contains('Garden')));
    });

    testWidgets('changing an existing category\'s icon counts as a change', (tester) async {
      await openOnTop(tester, const CategoriesScreen());
      await tester.tap(find.descendant(
        of: find.byKey(const Key('categoryRow_mind')),
        matching: find.byType(ListTile),
      ).first);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('categoryIconSwatch_moon')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cancelCategoryEdit')));
      await tester.pumpAndSettle();

      expect(discardDialog(), findsOneWidget);
      await tester.tap(find.byKey(const Key('discardChanges')));
      await tester.pumpAndSettle();
      expect(categoryProvider.resolve(BuiltInCategoryIds.mind).iconKey, 'book');
    });
  });
}
