import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/main.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/widgets/floating_tab_bar.dart';
import 'package:atomic_momentum/screens/habit_editor_screen.dart';
import 'package:atomic_momentum/screens/calendar_screen.dart';
import 'package:atomic_momentum/screens/categories_screen.dart';
import 'package:atomic_momentum/screens/insights_screen.dart';
import 'package:atomic_momentum/screens/settings_screen.dart';

import '../helpers/real_fonts.dart';

/// The floating tab bar: four tabs, Habits doubling as "+", hiding on pushed
/// pages, and content that clears it.
void main() {
  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
  });

  tearDown(resetDependencies);

  Future<void> launch(WidgetTester tester, {Size size = const Size(390, 844), double bottomInset = 34}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = FakeViewPadding(top: 47, bottom: bottomInset);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MomentumApp());
    await tester.pumpAndSettle();
  }

  Finder bar() => find.byType(FloatingTabBar);
  bool barShown(WidgetTester tester) => find.byKey(const Key('tab_habits')).hitTestable().evaluate().isNotEmpty;

  testWidgets('each tab shows its screen; Insights says what will show once habits are tracked', (tester) async {
    await launch(tester);
    for (final (tab, screen) in [
      ('calendar', CalendarScreen),
      ('insights', InsightsScreen),
      ('settings', SettingsScreen),
    ]) {
      await tester.tap(find.byKey(Key('tab_$tab')));
      await tester.pumpAndSettle();
      expect(find.byType(screen).hitTestable(), findsOneWidget, reason: tab);
    }
    expect(find.byKey(const Key('insightsEmpty')), findsNothing, reason: 'Insights is offstage now');
    await tester.tap(find.byKey(const Key('tab_insights')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('insightsEmpty')), findsOneWidget);
    await tester.tap(find.byKey(const Key('tab_habits')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('habitsGreeting')).hitTestable(), findsOneWidget);
  });

  testWidgets('tabs keep their place when you switch away and back', (tester) async {
    await launch(tester);
    await tester.tap(find.byKey(const Key('tab_settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('openCategories')));
    await tester.pumpAndSettle();
    expect(find.byType(CategoriesScreen), findsOneWidget);

    // A pushed page hides the bar, so leave through the page's back button
    expect(barShown(tester), isFalse);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(barShown(tester), isTrue, reason: 'back on the first page');
  });

  testWidgets('four tabs and no orb; selected, Habits turns into "Add habit"', (tester) async {
    await launch(tester);
    expect(find.byKey(const Key('addHabitOrb')), findsNothing);
    final tabs = find.descendant(
      of: bar(),
      matching: find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('tab_')),
    );
    expect(tabs, findsNWidgets(4));
    expect(find.descendant(of: bar(), matching: find.text('Add habit')), findsOneWidget);
    expect(find.descendant(of: bar(), matching: find.text('Habits')), findsNothing);

    await tester.tap(find.byKey(const Key('tab_calendar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('addHabitButton')), findsNothing);
    expect(find.descendant(of: bar(), matching: find.text('Habits')), findsOneWidget);
  });

  testWidgets('"+" opens New Habit over the bar, and closing it comes back', (tester) async {
    await launch(tester);
    await tester.tap(find.byKey(const Key('addHabitButton')));
    await tester.pumpAndSettle();

    expect(find.byType(HabitEditorScreen), findsOneWidget);
    expect(barShown(tester), isFalse, reason: 'New Habit covers the bar, so Save is never under it');
    final save = tester.getRect(find.byKey(const Key('saveHabitButton')));
    expect(save.bottom, lessThanOrEqualTo(844));

    await Navigator.of(tester.element(find.byType(HabitEditorScreen))).maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(HabitEditorScreen), findsNothing);
    expect(barShown(tester), isTrue);
  });

  testWidgets('from another tab, Habits only switches; a quick second tap does not add', (tester) async {
    await launch(tester);
    await tester.tap(find.byKey(const Key('tab_calendar')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tab_habits')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('habitsGreeting')).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(const Key('tab_habits')));
    await tester.pumpAndSettle();
    expect(find.byType(HabitEditorScreen), findsNothing, reason: 'a double-tap from Calendar');

    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('addHabitButton')));
    await tester.pumpAndSettle();
    expect(find.byType(HabitEditorScreen), findsOneWidget);
  });

  testWidgets('tapping the current tab goes back to its first page', (tester) async {
    await launch(tester);
    await tester.tap(find.byKey(const Key('tab_settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('openCategories')));
    await tester.pumpAndSettle();

    // Hidden while the page is open, so tap it through the bar's callback
    tester.widget<FloatingTabBar>(bar()).onTap(3);
    await tester.pumpAndSettle();
    expect(find.byType(CategoriesScreen), findsNothing);
    expect(barShown(tester), isTrue);
  });

  testWidgets('the end of the habit list scrolls clear of the bar', (tester) async {
    final habits = get<HabitProvider>();
    for (var i = 1; i <= 12; i++) {
      await habits.createHabit(CreateHabitParams(
        name: 'Habit $i',
        target: 1,
        color: HabitColor.blue,
        categoryId: BuiltInCategoryIds.body,
      ));
    }
    await launch(tester);
    final last = habits.habits.firstWhere((h) => h.name == 'Habit 12').id;

    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -5000));
    await tester.pumpAndSettle();

    final card = tester.getRect(find.byKey(Key('habitCard_$last')));
    expect(card.bottom, lessThanOrEqualTo(tester.getRect(bar()).top), reason: 'the last card is above the bar');
  });

  testWidgets('messages show above the bar', (tester) async {
    await launch(tester);
    ScaffoldMessenger.of(tester.element(find.byKey(const Key('habitsGreeting'))))
        .showSnackBar(const SnackBar(content: Text('Hello')));
    await tester.pumpAndSettle();

    final message = tester.getRect(find.byType(SnackBar));
    expect(message.bottom, lessThanOrEqualTo(tester.getRect(bar()).top));
  });

  testWidgets('VoiceOver reads Habits as "Add habit" while it is selected', (tester) async {
    final semantics = tester.ensureSemantics();
    await launch(tester);
    expect(
      tester.getSemantics(find.byKey(const Key('tab_habits'))),
      matchesSemantics(
        label: 'Add habit',
        hint: 'Adds a new habit',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(find.byKey(const Key('tab_settings')));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.byKey(const Key('tab_habits'))),
      matchesSemantics(label: 'Habits', isButton: true, hasSelectedState: true, hasTapAction: true),
    );
    semantics.dispose();
  });

  group('fits an iPhone SE', () {
    setUpAll(loadRealFonts);

    for (final scale in [1.0, 1.35, 2.0]) {
      testWidgets('at text ${(scale * 100).round()}%', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale * sfWidthAllowance;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await launch(tester, size: const Size(375, 667), bottomInset: 0);

        // With Habits selected ("Add habit"), then with another tab
        for (final tab in [null, 'calendar']) {
          if (tab != null) {
            await tester.tap(find.byKey(Key('tab_$tab')));
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
          expect(tester.getSize(bar()).height, FloatingTabBar.height);
          for (final p in tester.renderObjectList<RenderParagraph>(find.descendant(of: bar(), matching: find.byType(RichText)))) {
            expect(p.didExceedMaxLines, isFalse, reason: p.text.toPlainText());
          }
        }
        for (final tab in ['habits', 'calendar', 'insights', 'settings']) {
          final size = tester.getSize(find.byKey(Key('tab_$tab')));
          expect(size.width, greaterThanOrEqualTo(44), reason: tab);
          expect(size.height, greaterThanOrEqualTo(44), reason: tab);
        }
      });
    }
  });
}
