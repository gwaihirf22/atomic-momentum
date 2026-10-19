import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/core/copy/greetings.dart';
import 'package:atomic_momentum/domain/entities/momentum.dart';
import 'package:atomic_momentum/presentation/widgets/large_title_scaffold.dart';
import 'package:atomic_momentum/presentation/widgets/momentum_ring.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/theme/app_palette.dart';
import 'package:atomic_momentum/core/theme/ios_theme.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/habit_goal.dart';
import 'package:atomic_momentum/domain/entities/health_link.dart';
import 'package:atomic_momentum/domain/entities/quiet_hours.dart';
import 'package:atomic_momentum/presentation/habit_form/habit_draft.dart';
import 'package:atomic_momentum/domain/entities/reminder_settings.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/entities/two_minute_version.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/quote_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/inspire/quote_widgets.dart';
import 'package:atomic_momentum/domain/entities/quote.dart';
import 'package:atomic_momentum/screens/inspire_screen.dart';
import 'package:atomic_momentum/screens/quote_search_screen.dart';
import 'package:atomic_momentum/presentation/inspire/quote_filter_sheet.dart';
import 'package:atomic_momentum/presentation/inspire/quote_share_card.dart';
import 'package:atomic_momentum/presentation/share/share_cards.dart';
import 'package:atomic_momentum/core/copy/quotes.dart';
import 'package:atomic_momentum/domain/services/quote_facets.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/presentation/widgets/category_icons.dart';
import 'package:atomic_momentum/presentation/widgets/color_picker.dart';
import 'package:atomic_momentum/screens/add_habit_screen.dart';
import 'package:atomic_momentum/screens/calendar_screen.dart';
import 'package:atomic_momentum/screens/categories_screen.dart';
import 'package:atomic_momentum/screens/builder_add_screen.dart';
import 'package:atomic_momentum/screens/habit_detail_screen.dart';
import 'package:atomic_momentum/screens/habit_editor_screen.dart';
import 'package:atomic_momentum/screens/home_screen.dart';
import 'package:atomic_momentum/screens/story_habit_screen.dart';
import 'package:atomic_momentum/screens/insights_screen.dart';
import 'package:atomic_momentum/screens/settings_screen.dart';
import 'package:atomic_momentum/screens/app_icon_screen.dart';
import 'package:atomic_momentum/presentation/intro/intro_screen.dart';

import 'package:atomic_momentum/domain/services/achievements.dart';
import 'package:atomic_momentum/presentation/help/explainers.dart';
import 'package:atomic_momentum/presentation/widgets/achievement_widgets.dart';
import 'package:atomic_momentum/screens/achievements_screen.dart';
import 'package:atomic_momentum/screens/heatmap_screen.dart';
import 'package:atomic_momentum/presentation/share/share_sheet.dart';
import 'package:atomic_momentum/presentation/widgets/info_button.dart';

import '../helpers/fake_app_icon_service.dart';
import '../helpers/fake_support_link.dart';
import '../helpers/fake_health_source.dart';
import '../helpers/real_fonts.dart';
import 'package:atomic_momentum/presentation/tour/tour_anchor.dart';
import 'package:atomic_momentum/presentation/tour/tour_controller.dart';
import 'package:atomic_momentum/presentation/tour/tours.dart';
import 'package:atomic_momentum/presentation/tour/world_scope.dart';
import 'package:atomic_momentum/screens/tours_screen.dart';

/// Every screen on the smallest supported iPhone (the SE, 375pt wide) and
/// just above the habit card's breakpoint, at the default text size and at
/// iOS's largest standard size, drawn with real fonts: nothing may overflow
/// and no text may be cut off. At an Accessibility size, nothing may break.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HabitProvider habits;

  setUpAll(loadRealFonts);

  late Quote longQuote;

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    // Health shows (as on an iPhone), with a habit filled in from it
    FakeHealthSource.install();
    // Settings shows App icon, as on an iPhone
    FakeAppIconService.install();
    // And Buy me a coffee, as for a US user once there's a page
    FakeSupportLink.install();
    habits = get<HabitProvider>();
    await habits.loadHabits();
    await habits.addSampleHabits();

    final now = DateTime.now();
    DateTime daysAgo(int n) => DateTime(now.year, now.month, now.day - n);

    // A long name, missed yesterday (so "Don't miss twice" shows), with a
    // two-minute version (so the "2 min" button shows too)
    await habits.createHabit(CreateHabitParams(
      name: 'Drink water every morning',
      target: 8,
      units: 'glasses',
      color: HabitColor.blue,
      categoryId: BuiltInCategoryIds.body,
      reminder: ReminderSettings.smart(time: const TimeOfDay(hour: 9, minute: 0)),
      twoMinute: const TwoMinuteVersion(description: 'Fill one glass and take a sip', minimum: 1),
    ));
    final water = habits.habits.firstWhere((h) => h.name.startsWith('Drink water every')).id;
    await habits.updateProgressForDate(water, daysAgo(3), 8);
    await habits.updateProgressForDate(water, daysAgo(2), 8);

    // Rest days, and custom reminder days
    await habits.createHabit(const CreateHabitParams(
      name: 'Stretch',
      target: 1,
      units: 'session',
      color: HabitColor.teal,
      categoryId: BuiltInCategoryIds.body,
      scheduledWeekdays: [1, 3, 5],
      reminder: ReminderSettings(time: TimeOfDay(hour: 7, minute: 0), enabled: true, daysOfWeek: [1, 3, 5]),
    ));

    await habits.createHabit(CreateHabitParams(
      name: 'Walk the neighbourhood',
      target: 8000,
      units: 'steps',
      color: HabitColor.green,
      categoryId: BuiltInCategoryIds.body,
      health: HealthLink(metric: HealthMetric.steps, linkedOn: DateTime.now()),
    ));
    await habits.createHabit(CreateHabitParams(
      name: 'Water from the bottle',
      target: 8,
      units: 'glasses',
      color: HabitColor.blue,
      categoryId: BuiltInCategoryIds.body,
      health: HealthLink(metric: HealthMetric.water, logToHealth: true, linkedOn: DateTime.now()),
    ));

    // Quotes kept with a habit, one of them the person's own (long)
    final quotes = get<QuoteProvider>();
    longQuote = (await quotes.addMine(
      text: 'Not all those who wander are lost. ' * 11,
      author: 'Someone with a rather long name for a byline',
      source: 'A very long book title, chapter twelve, page 300',
    ))!;
    await quotes.setSaved('spurgeon-snail', true);
    final read = habits.habits.firstWhere((h) => h.name == 'Read').id;
    await habits.addQuote(read, 'burnett-it-is-done');
    await habits.addQuote(read, longQuote.id);

    // A long category name
    await get<CategoryProvider>().add(
      name: 'Personal growth',
      iconKey: CategoryIcons.library.keys.first,
      colorValue: HabitColor.indigo.value,
    );
  });

  tearDown(resetDependencies);

  Future<void> pump(WidgetTester tester, Widget screen,
      {required double width, required double scale, AppPalette palette = AppPalette.sepia}) async {
    // Tall, so whole screens build; the width is what's under test
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = scale * sfWidthAllowance;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: get<ThemeProvider>()),
        ChangeNotifierProvider<HabitProvider>.value(value: habits),
        ChangeNotifierProvider<CategoryProvider>.value(value: get<CategoryProvider>()),
        ChangeNotifierProvider<SettingsProvider>.value(value: get<SettingsProvider>()),
        ChangeNotifierProvider<QuoteProvider>.value(value: get<QuoteProvider>()),
        ChangeNotifierProvider<TourController>(
          create: (_) => TourController(worlds: WorldController(), tours: Tours.all, anchors: TourAnchors()),
        ),
      ],
      child: MaterialApp(
        theme: IOSTheme.material(palette).copyWith(platform: TargetPlatform.iOS),
        home: screen,
      ),
    ));
    await tester.pumpAndSettle();
  }

  void expectNothingCutOff(WidgetTester tester, String where, {bool checkTruncation = true}) {
    final error = tester.takeException();
    expect(error, isNull, reason: '$where: $error');
    if (!checkTruncation) return;
    final cut = [
      for (final p in tester.allRenderObjects.whereType<RenderParagraph>())
        if (p.didExceedMaxLines) '"${p.text.toPlainText()}"',
    ];
    expect(cut, isEmpty, reason: '$where: cut off: ${cut.join(', ')}');
  }

  /// A habit to break, with a long name and a limit.
  HabitDraft breakDraft() =>
      HabitDraft.newHabit(categoryId: 'body', reminderTime: const TimeOfDay(hour: 9, minute: 0))
        ..setGoal(HabitGoal.limit)
        ..name.text = 'Scrolling social media late at night'
        ..target.text = '30'
        ..units.text = 'minutes';

  final screens = <String, Widget Function()>{
    'Habits': () => const HomeScreen(),
    'Calendar': () => const CalendarScreen(),
    'Settings': () => const SettingsScreen(),
    'App icon': () => const AppIconScreen(),
    'Tours': () => const ToursScreen(),
    'Insights': () => const InsightsScreen(),
    'Inspire': () => const InspireScreen(),
    'Quote search': () => const QuoteSearchScreen(),
    'My quotes': () => const QuoteSearchScreen(start: QuoteList.mine),
    'Choose a quote (for a habit)': () =>
        QuoteSearchScreen(pickForHabitId: habits.habits.firstWhere((h) => h.name == 'Read').id),
    'Quote sheet, the longest quote': () => Scaffold(body: QuoteSheet(quoteId: longQuote.id)),
    'Quote sheet, a built-in quote': () => const Scaffold(body: QuoteSheet(quoteId: 'burnett-it-is-done')),
    'Add a quote sheet': () => const Scaffold(body: MyQuoteSheet()),
    'Edit a quote sheet, filed under a source': () => Scaffold(body: MyQuoteSheet(editing: longQuote)),
    'Quote filter sheet': () => const Scaffold(
          body: QuoteFilterSheet(initial: QuoteFilter(author: 'Seneca', themes: {QuoteTheme.hardDays})),
        ),
    'Inspire explainer': () => const Scaffold(body: InfoSheet(topic: InfoTopic.inspire)),
    'Health explainer': () => const Scaffold(body: InfoSheet(topic: InfoTopic.health)),
    'Habit page, filled in from Health': () =>
        HabitDetailScreen(habitId: habits.habits.firstWhere((h) => h.name.startsWith('Walk the')).id),
    'Edit habit, logging water back to Health': () =>
        AddHabitScreen(editHabit: habits.habits.firstWhere((h) => h.name == 'Water from the bottle')),
    'Story, editing a habit filled in from Health': () =>
        StoryHabitScreen(editHabit: habits.habits.firstWhere((h) => h.name.startsWith('Walk the'))),
    'Quote share card, the longest quote': () => Scaffold(
          body: Center(child: QuoteShareCard(quote: longQuote, look: ShareLook.of(ShareStyle.charged))),
        ),
    'Quote share card, a short quote': () => Scaffold(
          body: Center(
            child: QuoteShareCard(
              quote: Quotes.library.firstWhere((q) => q.id == 'kempis-habit-by-habit'),
              look: ShareLook.of(ShareStyle.ember),
            ),
          ),
        ),
    'Quote sources sheet': () => const Scaffold(body: QuoteSourcesSheet()),
    'Quote sources & credits': () => const Scaffold(body: QuoteCreditsSheet()),
    'New habit': () => const AddHabitScreen(),
    'Edit habit (custom reminder days)': () =>
        AddHabitScreen(editHabit: habits.habits.firstWhere((h) => h.name == 'Stretch')),
    'Edit habit (two-minute version)': () =>
        AddHabitScreen(editHabit: habits.habits.firstWhere((h) => h.name.startsWith('Drink water every'))),
    'Categories': () => const CategoriesScreen(),
    'Builder, step 1': () => const BuilderAddScreen(),
    'Story, new': () => const StoryHabitScreen(),
    'Habit editor (with its style switch)': () => const HabitEditorScreen(),
    'Story, breaking a habit (limit)': () => StoryHabitScreen(draft: breakDraft()),
    'Builder, breaking a habit': () => BuilderAddScreen(draft: breakDraft()),
    'One page, breaking a habit': () => AddHabitScreen(draft: breakDraft()),
    'Habit page': () => HabitDetailScreen(habitId: habits.habits.firstWhere((h) => h.name == 'Read').id),
    'Habit editor, editing a long name': () =>
        HabitEditorScreen(editHabit: habits.habits.firstWhere((h) => h.name.startsWith('Drink water every'))),
    'Story, editing a long name with a two-minute version': () =>
        StoryHabitScreen(editHabit: habits.habits.firstWhere((h) => h.name.startsWith('Drink water every'))),
    'Momentum explainer': () => const Scaffold(body: InfoSheet(topic: InfoTopic.momentum, momentum: 72)),
    'Achievements': () => const AchievementsScreen(),
    'Every day (full screen)': () => const HeatmapScreen(),
    'Share preview, hiding a name': () => Scaffold(
          body: ShareSheet(
            card: (look, hideName) => AchievementShareCard(
              achievement: Achievement(
                id: 'clean_30_x',
                kind: AchievementKind.clean,
                title: '30 days without late night snacking',
                badge: '30',
                unit: 'DAYS',
                message: "A whole month without a slip. That's a real change.",
                habitName: 'Late night snacking after dinner',
                earnedOn: DateTime(2026, 10, 17),
              ),
              look: look,
              hideName: hideName,
            ),
            fileName: 'x.png',
            styles: ShareStyle.values,
            canHideName: true,
          ),
        ),
    'Achievement celebration, a long name': () => Scaffold(
          body: AchievementSheet(
            isNew: true,
            achievement: Achievement(
              id: 'clean_30_x',
              kind: AchievementKind.clean,
              title: '30 days without late night snacking',
              badge: '30',
              unit: 'DAYS',
              message: "A whole month without a slip. That's a real change.",
              habitName: 'Late night snacking after dinner',
              earnedOn: DateTime(2026, 10, 17),
            ),
            next: const AchievementProgress(
              title: '90 days without late night snacking',
              badge: '90',
              unit: 'DAYS',
              current: 30,
              goal: 90,
            ),
            freeze: (added: false, available: 5),
          ),
        ),
    'Fun achievement, earning a freeze': () => Scaffold(
          body: AchievementSheet(
            isNew: true,
            achievement: Achievement(
              id: 'fun_tiny5_x',
              kind: AchievementKind.fun,
              title: 'Speedrunner',
              badge: '5',
              unit: 'TWO-MIN',
              message: "Five two-minute versions in a row. We're not saying you're gaming it. We're saying we see you. (The atoms)",
              habitName: 'Late night stretching before bed',
              earnedOn: DateTime(2026, 10, 17),
            ),
            freeze: (added: true, available: 4),
          ),
        ),
    'Freezes explainer': () => const Scaffold(body: InfoSheet(topic: InfoTopic.freezes)),
    'Two-minute explainer, a long example': () => const Scaffold(
          body: InfoSheet(
            topic: InfoTopic.twoMinute,
            example: (usual: 'Drink water every morning 8 glasses', tiny: 'Fill one glass and drink it slowly'),
          ),
        ),
  };

  for (final width in [375.0, 390.0]) {
    for (final scale in [1.0, 1.35]) {
      final setting = '${width.toInt()}pt, text ${(scale * 100).round()}%';

      for (final entry in screens.entries) {
        testWidgets('${entry.key} at $setting', (tester) async {
          await pump(tester, entry.value(), width: width, scale: scale);
          expectNothingCutOff(tester, '${entry.key} at $setting');
        });
      }

      testWidgets('Calendar, a past day, at $setting', (tester) async {
        await pump(tester, const CalendarScreen(), width: width, scale: scale);
        final now = DateTime.now();
        final day = now.day > 2 ? now.day - 2 : now.day;
        await tester.tap(find.byKey(Key('calendarDay_${now.year}-${now.month}-$day')));
        await tester.pumpAndSettle();
        expectNothingCutOff(tester, 'Calendar past day at $setting');
      });

      testWidgets('Builder steps 2 and 3 at $setting', (tester) async {
        await pump(tester, const BuilderAddScreen(), width: width, scale: scale);
        await tester.enterText(find.byKey(const Key('habitNameField')), 'Drink water every morning');
        await tester.tap(find.byKey(const Key('builderNext')));
        await tester.pumpAndSettle();
        expectNothingCutOff(tester, 'Builder step 2 at $setting');
        await tester.enterText(find.byKey(const Key('habitTargetField')), '8');
        await tester.enterText(find.byKey(const Key('habitUnitsField')), 'glasses');
        await tester.tap(find.byKey(const Key('builderNext')));
        await tester.pumpAndSettle();
        expectNothingCutOff(tester, 'Builder step 3 at $setting');
      });

      testWidgets('Story sheets at $setting', (tester) async {
        await pump(tester, const StoryHabitScreen(), width: width, scale: scale);
        for (final part in ['storyName', 'storyAmount', 'storySchedule', 'storyReminder', 'storyTiny']) {
          await tester.tap(find.byKey(Key(part)));
          await tester.pumpAndSettle();
          expectNothingCutOff(tester, '$part sheet at $setting');
          Navigator.of(tester.element(find.byKey(const Key('storySheetDone')))).pop();
          await tester.pumpAndSettle();
        }
      });

      testWidgets('Habit page, week and month, at $setting', (tester) async {
        final id = habits.habits.firstWhere((h) => h.name.startsWith('Drink water every')).id;
        await habits.setWhy(id, 'More energy in the afternoon, fewer headaches, and better sleep at night');
        await habits.setDayNote(id, DateTime.now(), 'Two glasses before lunch, one after the walk, and tea at night');
        await pump(tester, HabitDetailScreen(habitId: id), width: width, scale: scale);
        expectNothingCutOff(tester, 'Habit page at $setting');
        await tester.tap(find.byKey(const Key('detailMonthToggle')));
        await tester.pumpAndSettle();
        expectNothingCutOff(tester, 'Habit page month at $setting');
      });

      testWidgets('Habit page offering Health, and its sheet, at $setting', (tester) async {
        await habits.createHabit(const CreateHabitParams(
          name: 'Walk around the block every evening',
          target: 6000,
          units: 'steps',
          color: HabitColor.green,
          categoryId: BuiltInCategoryIds.body,
        ));
        await pump(tester, HabitDetailScreen(habitId: habits.habits.last.id), width: width, scale: scale);
        await tester.scrollUntilVisible(find.byKey(const Key('detailHealthOffer')), 300,
            scrollable: find.byType(Scrollable).first);
        expectNothingCutOff(tester, 'Health offer at $setting');
        await tester.tap(find.byKey(const Key('detailHealthOfferLink')));
        await tester.pumpAndSettle();
        expectNothingCutOff(tester, 'Health sheet at $setting');
      });

      testWidgets('Habit page with a frozen day, and Habits on vacation, at $setting', (tester) async {
        final id = habits.habits.firstWhere((h) => h.name.startsWith('Drink water every')).id;
        await habits.freeze(id, DateTime.now());
        await pump(tester, HabitDetailScreen(habitId: id), width: width, scale: scale);
        expectNothingCutOff(tester, 'Habit page, frozen, at $setting');
        await habits.startVacation();
        await pump(tester, const HomeScreen(), width: width, scale: scale);
        expect(find.byKey(const Key('vacationBanner')), findsOneWidget);
        expectNothingCutOff(tester, 'Habits on vacation at $setting');
      });

      testWidgets('Settings with quiet hours on at $setting', (tester) async {
        await get<SettingsProvider>().setQuietHours(const QuietHours(enabled: true));
        await pump(tester, const SettingsScreen(), width: width, scale: scale);
        expectNothingCutOff(tester, 'Settings with quiet hours at $setting');
      });

      testWidgets('Undo after holding a ring at $setting', (tester) async {
        await pump(tester, const HomeScreen(), width: width, scale: scale);
        final id = habits.habits.firstWhere((h) => h.name.startsWith('Drink water every')).id;
        await tester.longPress(find.byKey(Key('habitIcon_$id')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(Key('undoHold_$id')), findsOneWidget);
        expectNothingCutOff(tester, 'Undo strip at $setting');
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      });

      testWidgets('Category editor at $setting', (tester) async {
        await pump(tester, const CategoriesScreen(), width: width, scale: scale);
        await tester.tap(find.text('Personal growth').first);
        await tester.pumpAndSettle();
        expectNothingCutOff(tester, 'Category editor at $setting');
      });

      testWidgets('Color sheet at $setting', (tester) async {
        await pump(
          tester,
          Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showColorPickerSheet(context, selectedValue: HabitColor.blue.value),
                child: const Text('open'),
              ),
            ),
          ),
          width: width,
          scale: scale,
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expectNothingCutOff(tester, 'Color sheet at $setting');
      });

      testWidgets('Reset day picker at $setting', (tester) async {
        await pump(tester, const AddHabitScreen(), width: width, scale: scale);
        await tester.tap(find.byKey(Key('frequency_${ResetFrequency.monthly.name}')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('changeStartDate')));
        await tester.pumpAndSettle();
        expectNothingCutOff(tester, 'Reset day picker at $setting');
      });
    }
  }

  for (final width in [375.0, 390.0]) {
    for (final scale in [1.0, 1.35]) {
      testWidgets('Inspire, the longest quote of the day, at ${width.toInt()}pt, text ${(scale * 100).round()}%',
          (tester) async {
        final settings = get<SettingsProvider>();
        for (final family in QuoteFamily.values.where((f) => f != QuoteFamily.mine)) {
          await settings.setQuoteFamily(family, false);
        }
        await pump(tester, const InspireScreen(), width: width, scale: scale);
        expect(find.byKey(Key('inspireQuote_${longQuote.id}')), findsOneWidget);
        expectNothingCutOff(tester, 'Inspire, longest quote');
      });
    }
  }

  for (final width in [375.0, 390.0]) {
    for (final scale in [1.0, 1.35]) {
      testWidgets('Quotes, filtered by a source, an author and a theme, at ${width.toInt()}pt, text ${(scale * 100).round()}%',
          (tester) async {
        await pump(tester, const QuoteSearchScreen(), width: width, scale: scale);
        await tester.tap(find.byKey(const Key('browseAuthor_Frances Hodgson Burnett')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('quoteFilterButton')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('filterFamily_stories')));
        await tester.tap(find.byKey(const Key('filterTheme_momentum')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('quoteFilterApply')));
        await tester.pumpAndSettle();
        expect(find.text('Filter · 3'), findsOneWidget);
        expectNothingCutOff(tester, 'Quotes, filtered');
      });
    }
  }

  for (final width in [375.0, 390.0]) {
    for (final scale in [1.0, 1.35]) {
      testWidgets('Intro, Unstoppable and the end, at ${width.toInt()}pt, text ${(scale * 100).round()}%', (tester) async {
        tester.view.physicalSize = Size(width, 667);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = scale * sfWidthAllowance;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(MaterialApp(
          theme: IOSTheme.material(AppPalette.dark).copyWith(platform: TargetPlatform.iOS),
          home: IntroScreen(onDone: () {}),
        ));
        // The intro moves on at most IntroScreen.maxStep a frame
        Future<void> play(int ms) async {
          for (var i = 0; i < ms ~/ 10; i++) {
            await tester.pump(const Duration(milliseconds: 10));
          }
        }

        await play(1050);
        expect(find.byKey(const Key('introWord_unstoppable')), findsOneWidget);
        expectNothingCutOff(tester, 'Intro, Unstoppable');
        await play(950);
        expectNothingCutOff(tester, 'Intro, the end');
        await play(IntroScreen.duration.inMilliseconds);
      });
    }
  }

  // Colors don't change sizes, but each theme builds its own widgets' colors
  // The main passes are in Sepia, the look by day
  for (final palette in [AppPalette.light, AppPalette.dark]) {
    for (final name in [
      'Habits',
      'Calendar',
      'Settings',
      'App icon',
      'New habit',
      'Builder, step 1',
      'Story, new',
      'Habit page',
      'Insights',
      'Inspire',
      'Quote search',
      'Quote sheet, a built-in quote',
      'Quote filter sheet',
      'Add a quote sheet',
      'Inspire explainer',
      'Health explainer',
      'Edit habit, logging water back to Health',
      'Momentum explainer',
      'Achievement celebration, a long name',
      'Fun achievement, earning a freeze',
      'Freezes explainer',
      'Every day (full screen)',
      'Share preview, hiding a name',
    ]) {
      testWidgets('$name in ${palette.theme.name} at 375pt, text 135%', (tester) async {
        await pump(tester, screens[name]!(), width: 375, scale: 1.35, palette: palette);
        expect(AppPalette.of(tester.element(find.byType(Scaffold).first)), palette);
        expectNothingCutOff(tester, '$name in ${palette.theme.name}');
      });
    }
  }

  testWidgets('the Calendar weekday labels fit their row at 135% text', (tester) async {
    await pump(tester, const CalendarScreen(), width: 375, scale: 1.35);
    final row = tester.widget<TableCalendar<Habit>>(find.byType(TableCalendar<Habit>)).daysOfWeekHeight;
    final label = tester.getSize(find.text('Mon').first);
    expect(label.height, lessThanOrEqualTo(row));
  });

  testWidgets('every greeting fits the Habits header at 375pt and 135% text', (tester) async {
    tester.view.physicalSize = const Size(375, 2400);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.35 * sfWidthAllowance;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    for (final line in Greetings.lines.values.expand((l) => l)) {
      await tester.pumpWidget(MaterialApp(
        theme: IOSTheme.material(AppPalette.light).copyWith(platform: TargetPlatform.iOS),
        home: Scaffold(
          body: LargeTitleHeader(
            eyebrow: 'WEDNESDAY, SEPTEMBER 30',
            title: line,
            accessory: const MomentumRing(momentum: Momentum(score: 100, trend: 5)),
          ),
        ),
      ));
      expectNothingCutOff(tester, 'greeting "$line"');
    }
  });

  testWidgets('a long greeting steps down in size to fit two lines; a short one stays large', (tester) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Future<double> sizeOf(String line) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LargeTitleHeader(
            title: line,
            titleKey: const Key('t'),
            accessory: const MomentumRing(momentum: Momentum(score: 72, trend: 2)),
          ),
        ),
      ));
      return tester.widget<Text>(find.byKey(const Key('t'))).style!.fontSize!;
    }

    expect(await sizeOf('Still up?'), LargeTitleHeader.titleSizes.first);
    final long = await sizeOf('Quiet hours, big wins, and an early night ahead');
    expect(long, lessThan(LargeTitleHeader.titleSizes.first));
    // Two lines at most, unless even the smallest size needs more (then it wraps)
    final lines = tester.getSize(find.byKey(const Key('t'))).height / (long * 1.15);
    if (long > LargeTitleHeader.titleSizes.last) {
      expect(lines, lessThanOrEqualTo(LargeTitleHeader.maxTitleLines + 0.1));
    }
    expectNothingCutOff(tester, 'long title');
  });

  // Accessibility sizes: layouts may reflow, but nothing may break
  for (final entry in screens.entries) {
    testWidgets('${entry.key} at 375pt, Accessibility text (200%)', (tester) async {
      await pump(tester, entry.value(), width: 375, scale: 2.0);
      expectNothingCutOff(tester, '${entry.key} at 200%', checkTruncation: false);
    });
  }
}
