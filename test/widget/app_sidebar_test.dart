import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/main.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/tour/tour_controller.dart';
import 'package:atomic_momentum/presentation/widgets/floating_tab_bar.dart';
import 'package:atomic_momentum/screens/categories_screen.dart';
import 'package:atomic_momentum/screens/habit_editor_screen.dart';
import 'package:provider/provider.dart';

/// The iPad's sidebar, in place of the floating tab bar on wide windows.
void main() {
  setUp(() async {
    await resetDependencies();
    // Tours seen, so none covers the screen
    SharedPreferences.setMockInitialValues({TourStore.key: ['habits', 'calendar', 'insights', 'inspire', 'settings', 'arrange']});
    await initializeDependencies(seedDefaultHabit: false);
  });

  tearDown(resetDependencies);

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MomentumApp());
    await tester.pumpAndSettle();
  }

  Finder sidebar() => find.byKey(const Key('appSidebar'));

  for (final (name, size) in [('sideways', const Size(1194, 834)), ('upright', const Size(834, 1194))]) {
    testWidgets('an iPad $name has the sidebar, not the tab bar, and it switches sections', (tester) async {
      await pumpAt(tester, size);
      expect(sidebar(), findsOneWidget);
      expect(find.byType(FloatingTabBar), findsNothing);

      await tester.tap(find.byKey(const Key('tab_calendar')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('calendarDayTitle')), findsOneWidget);
      await tester.tap(find.byKey(const Key('tab_settings')));
      await tester.pumpAndSettle();
      expect(find.text('Appearance'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tab_habits')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('habitsGreeting')).hitTestable(), findsOneWidget);
    });
  }

  testWidgets('Add habit in the sidebar opens the editor, from any section', (tester) async {
    await pumpAt(tester, const Size(1194, 834));
    await tester.tap(find.byKey(const Key('tab_insights')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addHabitButton')));
    // The editor keeps a caret blinking: pump past the page's slide in
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(HabitEditorScreen), findsOneWidget);
  });

  testWidgets('a category under Habits filters the list, Habits shows them all, holding one opens Arrange',
      (tester) async {
    await pumpAt(tester, const Size(1194, 834));
    final context = tester.element(sidebar());
    final habits = context.read<HabitProvider>();
    for (final (name, category) in [('Walk', BuiltInCategoryIds.body), ('Read', BuiltInCategoryIds.mind)]) {
      await habits.createHabit(CreateHabitParams(name: name, target: 1, color: HabitColor.blue, categoryId: category));
    }
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tab_settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('sidebarCategory_${BuiltInCategoryIds.mind}')));
    await tester.pumpAndSettle();
    expect(context.read<CategoryProvider>().selectedCategoryId, BuiltInCategoryIds.mind);
    expect(find.byKey(const Key('habitsGreeting')).hitTestable(), findsOneWidget, reason: 'back on Habits');
    expect(find.text('Read'), findsWidgets);
    expect(find.text('Walk'), findsNothing);

    await tester.tap(find.byKey(const Key('tab_habits')));
    await tester.pumpAndSettle();
    expect(context.read<CategoryProvider>().selectedCategoryId, isNull);
    expect(find.text('Walk'), findsOneWidget);

    await tester.longPress(find.byKey(Key('sidebarCategory_${BuiltInCategoryIds.body}')));
    await tester.pumpAndSettle();
    expect(find.byType(CategoriesScreen), findsOneWidget);
  });

  testWidgets('a phone keeps the tab bar; resizing a window swaps them live, on the same section', (tester) async {
    await pumpAt(tester, const Size(390, 844));
    expect(sidebar(), findsNothing);
    expect(find.byType(FloatingTabBar), findsOneWidget);
    await tester.tap(find.byKey(const Key('tab_calendar')));
    await tester.pumpAndSettle();

    // Stage Manager widening the window
    tester.view.physicalSize = const Size(1194, 834);
    await tester.pumpAndSettle();
    expect(sidebar(), findsOneWidget);
    expect(find.byType(FloatingTabBar), findsNothing);
    expect(find.byKey(const Key('calendarDayTitle')), findsOneWidget);

    // And narrowing it again, as in Split View
    tester.view.physicalSize = const Size(507, 834);
    await tester.pumpAndSettle();
    expect(sidebar(), findsNothing);
    expect(find.byKey(const Key('calendarDayTitle')), findsOneWidget);
  });
}
