import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/domain/entities/habit_category.dart';
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
      CreateHabitParams(name: 'Run', target: 1, color: HabitColor.orange, category: HabitCategory.body),
      CreateHabitParams(name: 'Stretch', target: 1, color: HabitColor.green, category: HabitCategory.body),
      CreateHabitParams(name: 'Read', target: 1, color: HabitColor.blue, category: HabitCategory.mind),
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

  Finder ring(HabitCategory c) => find.byKey(Key('categoryRing_${c.name}'));

  testWidgets('all six rings fit on one row at 375pt with 44pt tap targets', (tester) async {
    await pumpHome(tester);

    final rects = HabitCategory.values.map((c) => tester.getRect(ring(c))).toList();
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
      name: 'Water', target: 8, color: HabitColor.blue, category: HabitCategory.social));
    final water = habitProvider.habits.firstWhere((h) => h.name == 'Water');
    await pumpHome(tester);
    expect(find.bySemanticsLabel('Social, 0 percent, 0 of 1 habits complete'), findsOneWidget);

    await habitProvider.updateHabitProgress(water.id, 4);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Social, 50 percent, 0 of 1 habits complete'), findsOneWidget);
  });

  testWidgets('rings use the flat category icons, not emoji', (tester) async {
    await pumpHome(tester);
    for (final c in HabitCategory.values) {
      expect(find.descendant(of: find.byType(CategoryRingsBar), matching: find.byIcon(c.icon)), findsOneWidget);
      expect(find.text(c.emoji), findsNothing);
    }
  });

  testWidgets('tapping a ring filters; tapping it again shows all', (tester) async {
    await pumpHome(tester);
    expect(find.text('Read'), findsOneWidget);

    await tester.tap(ring(HabitCategory.body));
    await tester.pumpAndSettle();
    expect(categoryProvider.selectedCategory, HabitCategory.body);
    expect(find.text('Run'), findsOneWidget);
    expect(find.text('Read'), findsNothing);

    await tester.tap(ring(HabitCategory.body));
    await tester.pumpAndSettle();
    expect(categoryProvider.selectedCategory, isNull);
    expect(find.text('Read'), findsOneWidget);
  });

  testWidgets('an empty category shows the empty state with a way back', (tester) async {
    await pumpHome(tester);

    await tester.tap(ring(HabitCategory.creative));
    await tester.pumpAndSettle();

    expect(find.text('No creative habits yet'), findsOneWidget);
    expect(find.textContaining('tap the ring again'), findsOneWidget);
  });
}
