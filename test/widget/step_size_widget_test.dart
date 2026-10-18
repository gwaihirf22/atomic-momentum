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
import 'package:atomic_momentum/screens/habit_detail_screen.dart';
import 'package:atomic_momentum/screens/home_screen.dart';

/// + and − move by a step that suits the target: 100 pages at a time for 500.
void main() {
  late HabitProvider habits;
  late String id;

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    habits = get<HabitProvider>();
    await habits.createHabit(const CreateHabitParams(
      name: 'Read',
      target: 500,
      units: 'pages',
      color: HabitColor.teal,
      categoryId: BuiltInCategoryIds.mind,
    ));
    id = habits.habits.single.id;
  });

  tearDown(resetDependencies);

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(390, 2000);
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

  testWidgets('on the card, + adds 100 pages and − takes 100 off', (tester) async {
    await pump(tester, const HomeScreen());
    expect(find.byTooltip('Add 100 pages'), findsOneWidget);
    await tester.tap(find.byKey(Key('incrementHabit_$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('incrementHabit_$id')));
    await tester.pumpAndSettle();
    expect(habits.habits.single.progress, 200);
    await tester.tap(find.byKey(Key('decrementHabit_$id')));
    await tester.pumpAndSettle();
    expect(habits.habits.single.progress, 100);
  });

  testWidgets('on the habit page, an odd amount rounds to the step', (tester) async {
    await habits.updateHabitProgress(id, 245);
    await pump(tester, HabitDetailScreen(habitId: id));
    await tester.tap(find.byKey(const Key('detailPlus')));
    await tester.pumpAndSettle();
    expect(habits.habits.single.progress, 300);
    await tester.tap(find.byKey(const Key('detailMinus')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detailMinus')));
    await tester.pumpAndSettle();
    expect(habits.habits.single.progress, 100);
  });
}
