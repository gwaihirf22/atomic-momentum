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

  Future<void> saveNewHabit(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).at(0), 'Paint');
    await tester.enterText(find.byType(TextFormField).at(1), '1');
    await tester.tap(find.text('Add Habit'));
    await tester.pumpAndSettle();
  }

  testWidgets('More opens the full grid; picking a shade uses it', (tester) async {
    await pump(tester, const AddHabitScreen());

    await tester.tap(find.byKey(const Key('colorSwatch_More')));
    await tester.pumpAndSettle();
    expect(find.text('Choose a Color'), findsOneWidget);

    await tester.tap(find.byKey(const Key('paletteColor_Teal_700')));
    await tester.pumpAndSettle();
    expect(find.text('Choose a Color'), findsNothing);
    expect(find.byKey(const Key('colorSwatch_Teal 700')), findsOneWidget, reason: 'now the current color');

    await saveNewHabit(tester);
    final color = habitProvider.habits.single.color;
    expect(color.value, Colors.teal[700]!.value);
    expect(color.name, 'Teal 700');
  });

  testWidgets('Custom: the hue wheel picks a custom color', (tester) async {
    await pump(tester, const AddHabitScreen());
    await tester.tap(find.byKey(const Key('colorSwatch_More')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();

    // The right edge of the ring is hue 0 (red)
    final wheel = tester.getRect(find.byKey(const Key('hueWheel')));
    await tester.tapAt(Offset(wheel.right - 10, wheel.center.dy));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('useCustomColor')));
    await tester.pumpAndSettle();

    await saveNewHabit(tester);
    final color = habitProvider.habits.single.color;
    final hsv = HSVColor.fromColor(color.color);
    expect(hsv.hue, anyOf(lessThan(15), greaterThan(345)));
    expect(color.value, isNot(HabitColor.blue.value));
  });

  testWidgets('a habit\'s current color shows first even if it\'s not a suggestion', (tester) async {
    await habitProvider.createHabit(const CreateHabitParams(
      name: 'Odd color',
      target: 1,
      color: HabitColor(value: 0xFF123456, hex: '#123456', name: 'Custom'),
      categoryId: BuiltInCategoryIds.body,
    ));
    await pump(tester, AddHabitScreen(editHabit: habitProvider.habits.single));

    final first = find.byKey(const Key('colorSwatch_Custom'));
    expect(first, findsOneWidget);
    expect(tester.getSemantics(first).label, 'Custom color');
  });

  testWidgets('the category editor uses the same picker', (tester) async {
    await pump(tester, const CategoriesScreen());
    await tester.tap(find.byKey(const Key('addCategory')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('categoryNameField')), 'Art');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('categoryColorSwatch_More')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('paletteColor_Deep_Purple_300')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveCategory')));
    await tester.pumpAndSettle();

    expect(categoryProvider.categories.last.colorValue, Colors.deepPurple[300]!.value);
  });
}
