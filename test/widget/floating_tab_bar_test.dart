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
import 'package:atomic_momentum/presentation/providers/quote_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/widgets/floating_tab_bar.dart';
import 'package:atomic_momentum/screens/habit_editor_screen.dart';
import 'package:atomic_momentum/screens/calendar_screen.dart';
import 'package:atomic_momentum/screens/categories_screen.dart';
import 'package:atomic_momentum/screens/insights_screen.dart';
import 'package:atomic_momentum/screens/inspire_screen.dart';
import 'package:atomic_momentum/screens/ios_main_navigation.dart';
import 'package:atomic_momentum/screens/settings_screen.dart';

import '../helpers/real_fonts.dart';

/// The floating tab bar: five tabs (Inspire can be turned off), Habits doubling as "+", hiding on pushed
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
      ('inspire', InspireScreen),
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

  Finder tabKeys() => find.descendant(
        of: bar(),
        matching: find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('tab_')),
      );

  List<String> tabOrder(WidgetTester tester) => [
        for (final element in tabKeys().evaluate())
          ((element.widget.key as ValueKey<String>).value).substring(4),
      ];

  testWidgets('five tabs and no orb; selected, Habits turns into "Add habit"', (tester) async {
    await launch(tester);
    expect(find.byKey(const Key('addHabitOrb')), findsNothing);
    expect(tabKeys(), findsNWidgets(5));
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
    final floating = tester.widget<FloatingTabBar>(bar());
    floating.onTap(floating.tabs.indexWhere((t) => t.label == 'Settings'));
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

  group('Inspire', () {
    bool barVisible(WidgetTester tester) =>
        tester.widget<AnimatedOpacity>(find.byKey(const Key('tabBarFade'))).opacity == 1;

    Future<void> openInspire(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('tab_inspire')));
      await tester.pumpAndSettle();
    }

    testWidgets('sits just left of Settings, and Settings can take it off the bar and put it back', (tester) async {
      await launch(tester);
      expect(tabOrder(tester), ['habits', 'calendar', 'insights', 'inspire', 'settings']);

      await tester.tap(find.byKey(const Key('tab_settings')));
      await tester.pumpAndSettle();
      // Down to the switch, clear of the bar
      await tester.scrollUntilVisible(find.byKey(const Key('inspireTabSwitch')), 200,
          scrollable: find.byType(Scrollable).hitTestable().first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('inspireTabSwitch')));
      await tester.pumpAndSettle();
      expect(get<SettingsProvider>().showInspireTab, isFalse);
      expect(tabOrder(tester), ['habits', 'calendar', 'insights', 'settings']);
      expect(find.byType(SettingsScreen).hitTestable(), findsOneWidget, reason: 'Settings stays selected');
      expect(find.byKey(const Key('quoteSourcesSetting')), findsNothing);

      await tester.tap(find.byKey(const Key('inspireTabSwitch')));
      await tester.pumpAndSettle();
      expect(tabOrder(tester), ['habits', 'calendar', 'insights', 'inspire', 'settings']);
      expect(find.byType(SettingsScreen).hitTestable(), findsOneWidget);
    });

    testWidgets('off, it stays off after a restart', (tester) async {
      await get<SettingsProvider>().setShowInspireTab(false);
      await launch(tester);
      expect(tabOrder(tester), ['habits', 'calendar', 'insights', 'settings']);
      expect(find.byType(InspireScreen), findsNothing);
    });

    testWidgets('the bar fades after a few seconds untouched, and a touch brings it back', (tester) async {
      await launch(tester);
      await openInspire(tester);
      expect(barVisible(tester), isTrue);

      // A touch starts the wait over
      await tester.tapAt(const Offset(12, 400));
      await tester.pump(IOSMainNavigation.barFadeDelay - const Duration(milliseconds: 100));
      expect(barVisible(tester), isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(barVisible(tester), isFalse);
      expect(barShown(tester), isFalse, reason: 'a faded bar takes no taps');

      await tester.tapAt(const Offset(200, 400));
      await tester.pumpAndSettle();
      expect(barVisible(tester), isTrue);
      expect(barShown(tester), isTrue);

      // Other tabs never fade
      await tester.tap(find.byKey(const Key('tab_insights')));
      await tester.pumpAndSettle();
      await tester.pump(IOSMainNavigation.barFadeDelay * 2);
      expect(barVisible(tester), isTrue);
    });

    testWidgets('the quote\'s buttons fade with the bar, and a touch brings them back without pressing one',
        (tester) async {
      await launch(tester);
      await openInspire(tester);
      double actions() => tester.widget<AnimatedOpacity>(find.byKey(const Key('inspireActionsFade'))).opacity;
      expect(actions(), 1);

      await tester.pump(IOSMainNavigation.barFadeDelay + const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(actions(), 0);
      expect(find.byKey(const Key('quoteSave')).hitTestable(), findsNothing);
      expect(find.byKey(const Key('inspireAnother')).hitTestable(), findsNothing);

      // Tapping where Save was only wakes the page
      final quotes = get<QuoteProvider>();
      await tester.tap(find.byKey(const Key('quoteSave')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(quotes.savedIds, isEmpty);
      expect(actions(), 1);
      expect(barVisible(tester), isTrue);

      await tester.tap(find.byKey(const Key('quoteSave')));
      await tester.pumpAndSettle();
      expect(quotes.savedIds, hasLength(1));
    });

    testWidgets('the quote and its buttons scroll clear of the bar on a small phone', (tester) async {
      await launch(tester, size: const Size(375, 667), bottomInset: 0);
      await openInspire(tester);
      final barTop = tester.getRect(bar()).top;
      await tester.drag(find.byType(InspireScreen), const Offset(0, -2000));
      await tester.pumpAndSettle();
      // The page ends where the bar begins, not a bar's height above it
      final another = tester.getRect(find.byKey(const Key('inspireAnother')));
      expect(another.bottom, lessThanOrEqualTo(barTop));
      expect(another.bottom, greaterThan(barTop - 80));
      expect(find.byKey(const Key('quoteSave')).hitTestable(), findsOneWidget);
    });

    testWidgets('swiping between tabs still works while the bar is faded', (tester) async {
      await launch(tester);
      await openInspire(tester);
      await tester.pump(IOSMainNavigation.barFadeDelay + const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(barVisible(tester), isFalse);

      await tester.fling(find.byType(InspireScreen), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen).hitTestable(), findsOneWidget);
      expect(barVisible(tester), isTrue);
    });

    testWidgets('with VoiceOver on, the bar never fades', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await launch(tester);
      await openInspire(tester);
      await tester.pump(IOSMainNavigation.barFadeDelay * 2);
      await tester.pumpAndSettle();
      expect(barVisible(tester), isTrue);
    });
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
        for (final tab in ['habits', 'calendar', 'insights', 'inspire', 'settings']) {
          final size = tester.getSize(find.byKey(Key('tab_$tab')));
          expect(size.width, greaterThanOrEqualTo(44), reason: tab);
          expect(size.height, greaterThanOrEqualTo(44), reason: tab);
        }
      });
    }
  });
}
