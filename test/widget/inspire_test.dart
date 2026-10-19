import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/copy/quotes.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/presentation/inspire/quote_widgets.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/quote.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/quote_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/screens/habit_detail_screen.dart';
import 'package:atomic_momentum/screens/inspire_screen.dart';
import 'package:atomic_momentum/screens/quote_search_screen.dart';
import 'package:atomic_momentum/presentation/inspire/quote_filter_sheet.dart';
import 'package:atomic_momentum/domain/services/quote_facets.dart';
import 'package:atomic_momentum/screens/settings_screen.dart';
import 'package:atomic_momentum/presentation/share/share_sheet.dart';

import '../helpers/fake_sharer.dart';

/// The Inspire tab, quote search, the person's own quotes, and quotes kept
/// with a habit.
void main() {
  late HabitProvider habits;
  late QuoteProvider quotes;
  late SettingsProvider settings;
  late String habitId;

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    habits = get<HabitProvider>();
    quotes = get<QuoteProvider>();
    settings = get<SettingsProvider>();
    await habits.createHabit(const CreateHabitParams(
      name: 'Read',
      target: 1,
      color: HabitColor.teal,
      categoryId: BuiltInCategoryIds.mind,
    ));
    habitId = habits.habits.single.id;
  });

  tearDown(resetDependencies);

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: get<ThemeProvider>()),
        ChangeNotifierProvider<HabitProvider>.value(value: habits),
        ChangeNotifierProvider<CategoryProvider>.value(value: get<CategoryProvider>()),
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<QuoteProvider>.value(value: quotes),
      ],
      child: MaterialApp(home: home),
    ));
    await tester.pumpAndSettle();
  }

  Quote today() => quotes.today(settings.quoteFamilies)!;

  group('the Inspire tab', () {
    testWidgets('shows the quote of the day, with who said it and the date', (tester) async {
      await pump(tester, const InspireScreen());
      final quote = today();
      expect(find.byKey(Key('inspireQuote_${quote.id}')), findsOneWidget);
      expect(find.text(quote.text), findsOneWidget);
      expect(find.text('— ${quote.author}'), findsOneWidget);
      expect(find.byKey(const Key('inspireDate')), findsOneWidget);
    });

    testWidgets('follows the quote sources turned on', (tester) async {
      for (final family in QuoteFamily.values.where((f) => f != QuoteFamily.stoic)) {
        await settings.setQuoteFamily(family, false);
      }
      await pump(tester, const InspireScreen());
      expect(today().family, QuoteFamily.stoic);
      expect(find.text(today().text), findsOneWidget);
    });

    testWidgets('with only their own quotes on and none added, offers to add one', (tester) async {
      for (final family in QuoteFamily.values.where((f) => f != QuoteFamily.mine)) {
        await settings.setQuoteFamily(family, false);
      }
      await pump(tester, const InspireScreen());
      expect(find.text('No quotes to show'), findsOneWidget);

      await tester.tap(find.byKey(const Key('inspireAddFirst')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('myQuoteText')), 'Courage, dear heart.');
      await tester.enterText(find.byKey(const Key('myQuoteAuthor')), 'Aslan');
      await tester.tap(find.byKey(const Key('myQuoteSave')));
      await tester.pumpAndSettle();

      expect(find.text('Courage, dear heart.'), findsOneWidget, reason: 'their quote is the only one, so it is today\'s');
      expect(find.text('— Aslan'), findsOneWidget);
    });

    testWidgets('Back leaves "Add a quote", asking first once something is typed', (tester) async {
      for (final family in QuoteFamily.values.where((f) => f != QuoteFamily.mine)) {
        await settings.setQuoteFamily(family, false);
      }
      await pump(tester, const InspireScreen());
      Future<void> open() async {
        await tester.tap(find.byKey(const Key('inspireAddFirst')));
        await tester.pumpAndSettle();
      }

      // Nothing typed: closes at once
      await open();
      await tester.tap(find.byKey(const Key('myQuoteBack')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('myQuoteText')), findsNothing);

      // Typed: asks, and Keep Editing keeps the words
      await open();
      await tester.enterText(find.byKey(const Key('myQuoteText')), 'Courage, dear heart.');
      await tester.pump();
      await tester.tap(find.byKey(const Key('myQuoteBack')));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('keepEditing')));
      await tester.pumpAndSettle();
      expect(find.text('Courage, dear heart.'), findsOneWidget);

      // Discard closes without saving
      await tester.tap(find.byKey(const Key('myQuoteBack')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('discardChanges')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('myQuoteText')), findsNothing);
      expect(quotes.mine, isEmpty);
    });

    testWidgets('"Another quote" shows a different one, and keeps it', (tester) async {
      await pump(tester, const InspireScreen());
      final first = today();
      await tester.tap(find.byKey(const Key('inspireAnother')));
      await tester.pumpAndSettle();
      final second = today();
      expect(second.id, isNot(first.id));
      expect(find.byKey(Key('inspireQuote_${second.id}')), findsOneWidget);
      expect(find.byKey(Key('inspireQuote_${first.id}')), findsNothing);
    });

    testWidgets('⋯ shares the quote as a card', (tester) async {
      final sharer = FakeSharer.install();
      await pump(tester, const InspireScreen());
      await tester.tap(find.byKey(const Key('inspireOptions')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('inspireOption_share')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shareCard_quote')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('shareCard_quote')), matching: find.text(today().text)),
          findsOneWidget);

      final button = find.descendant(of: find.byType(ShareSheet), matching: find.text('Share…'));
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(button);
        for (var i = 0; i < 20 && sharer.shared.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();
      expect(sharer.shared.single.name, 'momentum-quote.png');
      expect(pngSize(sharer.shared.single.png), (1080, 1350));
    });

    testWidgets('saves and unsaves the quote', (tester) async {
      await pump(tester, const InspireScreen());
      await tester.tap(find.byKey(const Key('quoteSave')));
      await tester.pumpAndSettle();
      expect(quotes.isSaved(today().id), isTrue);
      expect(find.text('Saved'), findsOneWidget);

      await tester.tap(find.byKey(const Key('quoteSave')));
      await tester.pumpAndSettle();
      expect(quotes.isSaved(today().id), isFalse);
    });

    testWidgets('copies the quote with who said it', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await pump(tester, const InspireScreen());
      await tester.tap(find.byKey(const Key('quoteCopy')));
      await tester.pumpAndSettle();
      expect(copied, contains(today().text));
      expect(copied, contains(today().author));
      expect(find.text('Copied'), findsOneWidget);
    });

    testWidgets('keeps the quote with a habit', (tester) async {
      await pump(tester, const InspireScreen());
      await tester.tap(find.byKey(const Key('quoteAddToHabit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('quoteHabit_$habitId')));
      await tester.pumpAndSettle();
      expect(habits.habits.single.quoteIds, [today().id]);
      expect(find.text('Added to Read'), findsOneWidget);
    });

    testWidgets('the options open sources, and the saved and own quote lists', (tester) async {
      await pump(tester, const InspireScreen());
      await tester.tap(find.byKey(const Key('inspireOptions')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('inspireOption_sources')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quoteFamily_scripture')));
      await tester.pumpAndSettle();
      expect(settings.quoteFamilies, isNot(contains(QuoteFamily.scripture)));
      Navigator.of(tester.element(find.byKey(const Key('quoteFamily_scripture')))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('inspireOptions')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('inspireOption_saved')));
      await tester.pumpAndSettle();
      expect(find.byType(QuoteSearchScreen), findsOneWidget);
      expect(find.byKey(const Key('activeFilter_list')), findsOneWidget);
      expect(find.text('Tap the heart on a quote to keep it here.'), findsOneWidget);
    });
  });

  group('quote search', () {
    testWidgets('finds quotes by their words, and by theme', (tester) async {
      await pump(tester, const QuoteSearchScreen());
      await tester.enterText(find.byKey(const Key('quoteSearchField')), 'walking running');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quote_epictetus-walking-by-walking')), findsOneWidget);
      expect(find.byType(InkWell).evaluate().where((e) => (e.widget.key as ValueKey?)?.value.toString().startsWith('quote_') ?? false),
          hasLength(1));

      await tester.enterText(find.byKey(const Key('quoteSearchField')), 'zebra');
      await tester.pumpAndSettle();
      expect(find.text('Nothing matches. Try other words, or fewer filters.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('quoteSearchField')), '');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('browseTheme_comeback')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('quoteSearchField')), 'seven');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quote_kjv-proverbs-24-16')), findsOneWidget);
      expect(find.text('1 quote'), findsOneWidget);
    });

    testWidgets('a quote opens in a sheet to save, keep or copy', (tester) async {
      await pump(tester, const QuoteSearchScreen());
      await tester.enterText(find.byKey(const Key('quoteSearchField')), 'snail');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quote_spurgeon-snail')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quoteSheetText')), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.byKey(const Key('quoteSave'))));
      await tester.pumpAndSettle();
      expect(quotes.savedIds, ['spurgeon-snail']);
      expect(find.byKey(const Key('quoteSheetEdit')), findsNothing, reason: 'only their own can be edited');
    });

    testWidgets('their own quotes are added, edited and deleted (and come off habits)', (tester) async {
      await pump(tester, const QuoteSearchScreen(start: QuoteList.mine));
      expect(find.text('Quotes you add show here. Tap + to add one.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('quoteSearchAdd')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('myQuoteSave')));
      await tester.pumpAndSettle();
      expect(find.text('Type the quote'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('myQuoteText')), 'Journey before destination.');
      await tester.enterText(find.byKey(const Key('myQuoteSource')), 'Words of Radiance');
      await tester.tap(find.byKey(const Key('myQuoteSave')));
      await tester.pumpAndSettle();
      final mine = quotes.mine.single;
      expect(find.byKey(Key('quote_${mine.id}')), findsOneWidget);
      await habits.addQuote(habitId, mine.id);

      await tester.tap(find.byKey(Key('quote_${mine.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quoteSheetEdit')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('myQuoteText')), 'Life before death.');
      await tester.tap(find.byKey(const Key('myQuoteSave')));
      await tester.pumpAndSettle();
      expect(quotes.mine.single.text, 'Life before death.');
      expect(find.text('Life before death.'), findsWidgets);

      await tester.tap(find.byKey(const Key('quoteSheetDelete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmDeleteQuote')));
      await tester.pumpAndSettle();
      expect(quotes.mine, isEmpty);
      expect(habits.habits.single.quoteIds, isEmpty);
      expect(find.byKey(const Key('quoteSheetText')), findsNothing, reason: 'the sheet closes');
    });
  });

  group('on the habit page', () {
    testWidgets('quotes are chosen for the habit, shown, and taken off', (tester) async {
      await pump(tester, HabitDetailScreen(habitId: habitId));
      await tester.scrollUntilVisible(find.byKey(const Key('detailAddQuote')), 300, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.text('A line to come back to on the days it\'s hard.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('detailAddQuote')));
      await tester.pumpAndSettle();
      expect(find.text('Choose a quote'), findsWidgets);
      await tester.enterText(find.byKey(const Key('quoteSearchField')), 'fig');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quote_epictetus-fig')));
      await tester.pumpAndSettle();

      expect(find.byType(QuoteSearchScreen), findsNothing, reason: 'back on the habit page');
      expect(habits.habits.single.quoteIds, ['epictetus-fig']);
      expect(find.byKey(const Key('detailQuote_epictetus-fig')), findsOneWidget);

      await tester.tap(find.byKey(const Key('detailRemoveQuote_epictetus-fig')));
      await tester.pumpAndSettle();
      expect(habits.habits.single.quoteIds, isEmpty);
      expect(find.byKey(const Key('detailQuote_epictetus-fig')), findsNothing);
    });

    testWidgets('a quote whose source is turned off still shows on the habit', (tester) async {
      await habits.addQuote(habitId, 'kjv-proverbs-24-16');
      await settings.setQuoteFamily(QuoteFamily.scripture, false);
      await pump(tester, HabitDetailScreen(habitId: habitId));
      await tester.scrollUntilVisible(find.byKey(const Key('detailQuote_kjv-proverbs-24-16')), 300, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.text('For a righteous man may fall seven times and rise again.'), findsOneWidget);
    });
  });

  group('browsing and filtering the library', () {
    Finder count(String text) =>
        find.byWidgetPredicate((w) => w is Text && w.key == const Key('quoteResultCount') && w.data == text);

    testWidgets('shows the sources turned on, with counts, and links to the ones off', (tester) async {
      await settings.setQuoteFamily(QuoteFamily.scripture, false);
      await pump(tester, const QuoteSearchScreen());
      for (final family in [QuoteFamily.stoic, QuoteFamily.christian, QuoteFamily.stories, QuoteFamily.mine]) {
        expect(find.byKey(Key('browseFamily_${family.name}')), findsOneWidget, reason: family.name);
      }
      expect(find.byKey(const Key('browseFamily_scripture')), findsNothing);
      final stoics = quotes.all.where((q) => q.family == QuoteFamily.stoic).length;
      expect(find.descendant(of: find.byKey(const Key('browseFamily_stoic')), matching: find.text('$stoics')),
          findsOneWidget);
      expect(find.text('1 source off · Quote sources'), findsOneWidget);
      expect(find.byKey(const Key('browseAuthor_Seneca')), findsOneWidget);
      expect(find.byKey(const Key('browseSaved')), findsOneWidget);
    });

    testWidgets('a source, theme or author narrows the list; its chip takes it off', (tester) async {
      await pump(tester, const QuoteSearchScreen());
      await tester.tap(find.byKey(const Key('browseFamily_stoic')));
      await tester.pumpAndSettle();
      final stoics = quotes.all.where((q) => q.family == QuoteFamily.stoic).length;
      expect(count('$stoics quotes'), findsOneWidget);
      expect(find.text('Filter · 1'), findsOneWidget);

      await tester.tap(find.byKey(const Key('activeFilter_family_stoic')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('browseFamily_stoic')), findsOneWidget, reason: 'back to browsing');

      await tester.scrollUntilVisible(find.byKey(const Key('browseAuthor_Seneca')).hitTestable(), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byKey(const Key('browseAuthor_Seneca')));
      await tester.pumpAndSettle();
      expect(count('${Quotes.library.where((q) => q.author == 'Seneca').length} quotes'), findsOneWidget);
      expect(find.byKey(const Key('activeFilter_author')).hitTestable(), findsOneWidget, reason: 'back at the top');
    });

    testWidgets('the filter sheet combines an author and a theme, with counts', (tester) async {
      await pump(tester, const QuoteSearchScreen());
      await tester.tap(find.byKey(const Key('quoteFilterButton')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(const Key('filterAuthor_Seneca')).hitTestable(), 200,
          scrollable: find.descendant(of: find.byType(QuoteFilterSheet), matching: find.byType(Scrollable)).first);
      await tester.tap(find.byKey(const Key('filterAuthor_Seneca')));
      await tester.pumpAndSettle();
      expect(find.text('Show ${Quotes.library.where((q) => q.author == 'Seneca').length} quotes'), findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(const Key('filterTheme_hardDays')).hitTestable(), -200,
          scrollable: find.descendant(of: find.byType(QuoteFilterSheet), matching: find.byType(Scrollable)).first);
      await tester.tap(find.byKey(const Key('filterTheme_hardDays')));
      await tester.pumpAndSettle();
      expect(find.text('Show 2 quotes'), findsOneWidget);
      await tester.tap(find.byKey(const Key('quoteFilterApply')));
      await tester.pumpAndSettle();

      expect(count('2 quotes'), findsOneWidget);
      expect(find.byKey(const Key('quote_seneca-imagination')), findsOneWidget);
      expect(find.byKey(const Key('quote_seneca-we-do-not-dare')), findsOneWidget);
      expect(find.text('Filter · 2'), findsOneWidget);
    });

    testWidgets('their own quote, filed under a source and a theme, is found by both', (tester) async {
      await pump(tester, const QuoteSearchScreen());
      await tester.tap(find.byKey(const Key('quoteSearchAdd')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('myQuoteText')), 'Courage, dear heart.');
      await tester.enterText(find.byKey(const Key('myQuoteAuthor')), 'Aslan');
      await tester.ensureVisible(find.byKey(const Key('myQuoteFamily_stories')));
      await tester.tap(find.byKey(const Key('myQuoteFamily_stories')));
      await tester.ensureVisible(find.byKey(const Key('myQuoteTheme_hardDays')));
      await tester.tap(find.byKey(const Key('myQuoteTheme_hardDays')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('myQuoteSave')));
      await tester.tap(find.byKey(const Key('myQuoteSave')));
      await tester.pumpAndSettle();

      final mine = quotes.mine.single;
      expect(mine.family, QuoteFamily.stories);
      expect(mine.themes, {QuoteTheme.hardDays});
      expect(mine.isMine, isTrue);

      await tester.tap(find.byKey(const Key('activeFilter_list')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('browseFamily_stories')));
      await tester.pumpAndSettle();
      final stories = Quotes.library.where((q) => q.family == QuoteFamily.stories).length;
      expect(count('${stories + 1} quotes'), findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(Key('quote_${mine.id}')), 300, scrollable: find.byType(Scrollable).first);
      expect(find.byKey(Key('quote_${mine.id}')), findsOneWidget);
      expect(find.byKey(const Key('browseFamily_mine')), findsNothing);
    });

    testWidgets('typing an author suggests names already in the library', (tester) async {
      await pump(tester, const QuoteSearchScreen());
      await tester.tap(find.byKey(const Key('quoteSearchAdd')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('myQuoteAuthor')), 'sene');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('authorSuggestion_Seneca')));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Seneca'), findsOneWidget);
    });

    testWidgets('the (i) explains Inspire, from the tab and from the library', (tester) async {
      await pump(tester, const InspireScreen());
      await tester.tap(find.byKey(const Key('info_inspire')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('infoSheet_inspire')), findsOneWidget);
      await tester.tap(find.byKey(const Key('infoGotIt')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('inspireSearch')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('info_inspire')).hitTestable());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('infoSheet_inspire')), findsOneWidget);
    });
  });

  test('a copied verse names its translation; other quotes their source', () {
    final verse = Quotes.library.firstWhere((q) => q.id == 'kjv-proverbs-24-16');
    expect(quoteToCopy(verse), '"${verse.text}"\n— Proverbs 24:16 (NKJV)');
    final stoic = Quotes.library.firstWhere((q) => q.id == 'marcus-be-such');
    expect(quoteToCopy(stoic), endsWith('— Marcus Aurelius, Meditations 10.16 · tr. George Long'));
  });

  testWidgets('Sources & credits carries the NKJV notice, from the Inspire options', (tester) async {
    await pump(tester, const InspireScreen());
    await tester.tap(find.byKey(const Key('inspireOptions')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('inspireOption_credits')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quoteCredits')), findsOneWidget);
    expect(find.text(Quotes.nkjvNotice), findsOneWidget);
  });

  testWidgets('browse lists the Puritans and Thinkers with their counts', (tester) async {
    await pump(tester, const QuoteSearchScreen());
    for (final family in [QuoteFamily.puritans, QuoteFamily.thinkers]) {
      final count = Quotes.library.where((q) => q.family == family).length;
      expect(find.descendant(of: find.byKey(Key('browseFamily_${family.name}')), matching: find.text('$count')),
          findsOneWidget, reason: family.name);
    }
  });

  testWidgets('Settings turns the tab off, and opens the sources while it is on', (tester) async {
    await pump(tester, const SettingsScreen());
    await tester.scrollUntilVisible(find.byKey(const Key('quoteSourcesSetting')), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.byKey(const Key('quoteSourcesSetting')));
      await tester.pumpAndSettle();
    expect(find.text('${QuoteFamily.values.length} of ${QuoteFamily.values.length}'), findsOneWidget);
    await tester.tap(find.byKey(const Key('quoteSourcesSetting')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quoteFamily_stoic')), findsOneWidget);
    Navigator.of(tester.element(find.byKey(const Key('quoteFamily_stoic')))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('inspireTabSwitch')));
    await tester.pumpAndSettle();
    expect(settings.showInspireTab, isFalse);
    expect(find.byKey(const Key('quoteSourcesSetting')), findsNothing);
  });
}
