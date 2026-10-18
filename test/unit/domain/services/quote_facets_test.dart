import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/core/copy/quotes.dart';
import 'package:atomic_momentum/domain/entities/quote.dart';
import 'package:atomic_momentum/domain/services/quote_facets.dart';

/// Narrowing the library by list, source, theme and author, and counting
/// what each choice would show.
void main() {
  const mine = Quote(
    id: 'mine-1',
    text: 'Courage, dear heart.',
    author: 'Aslan',
    family: QuoteFamily.stories,
    themes: {QuoteTheme.hardDays},
  );
  const mineToo = Quote(id: 'mine-2', text: 'Journey before destination.', author: 'aslan', family: QuoteFamily.mine);
  final library = [...Quotes.library, mine, mineToo];
  final everything = QuoteFamily.values.toSet();
  List<String> ids(List<Quote> quotes) => [for (final q in quotes) q.id];
  int inFamily(QuoteFamily f) => Quotes.library.where((q) => q.family == f).length;

  test('nothing chosen is every quote from the sources turned on', () {
    expect(QuoteFacets.apply(library, const QuoteFilter(), enabled: everything), hasLength(library.length));
    final noScripture = QuoteFacets.apply(library, const QuoteFilter(), enabled: everything..remove(QuoteFamily.scripture));
    expect(noScripture.any((q) => q.family == QuoteFamily.scripture), isFalse);
  });

  test('their own quotes are filed with the source they chose', () {
    final stories = QuoteFacets.apply(library, const QuoteFilter(families: {QuoteFamily.stories}), enabled: everything);
    expect(stories, hasLength(inFamily(QuoteFamily.stories) + 1));
    expect(ids(stories), contains('mine-1'));
    expect(mine.isMine, isTrue);
    expect(Quotes.library.any((q) => q.isMine), isFalse);
  });

  test('Saved and Mine show everything there, whatever the sources', () {
    const onlyStoics = {QuoteFamily.stoic};
    expect(
      ids(QuoteFacets.apply(library, const QuoteFilter(list: QuoteList.mine), enabled: onlyStoics)),
      ['mine-2', 'mine-1'],
      reason: 'newest first',
    );
    expect(
      ids(QuoteFacets.apply(library, const QuoteFilter(list: QuoteList.saved), enabled: onlyStoics,
          savedIds: ['kjv-micah-7-8', 'gone', 'mine-1'])),
      ['kjv-micah-7-8', 'mine-1'],
    );
  });

  test('choices in one group widen it; groups narrow each other', () {
    final stoicOrStories = QuoteFacets.apply(library,
        const QuoteFilter(families: {QuoteFamily.stoic, QuoteFamily.stories}), enabled: everything);
    expect(stoicOrStories, hasLength(inFamily(QuoteFamily.stoic) + inFamily(QuoteFamily.stories) + 1));

    final senecaHardDays = QuoteFacets.apply(library,
        const QuoteFilter(author: 'seneca', themes: {QuoteTheme.hardDays}), enabled: everything);
    expect(ids(senecaHardDays), unorderedEquals(['seneca-imagination', 'seneca-we-do-not-dare']));

    final withWords = QuoteFacets.apply(library,
        const QuoteFilter(author: 'Seneca', query: 'imagination'), enabled: everything);
    expect(ids(withWords), ['seneca-imagination']);
  });

  test('counts say what each choice would show, with the other groups kept', () {
    final counts = QuoteFacets.counts(library, const QuoteFilter(author: 'Seneca'), enabled: everything);
    expect(counts.families[QuoteFamily.stoic], 8);
    expect(counts.families[QuoteFamily.scripture], 0);
    expect(counts.themes[QuoteTheme.hardDays], 2);
    // The author group itself isn't narrowed by its own choice
    expect(counts.authors.map((a) => a.name), containsAll(['Seneca', 'Epictetus', 'Aslan']));

    final stoicCounts = QuoteFacets.counts(library, const QuoteFilter(families: {QuoteFamily.stoic}), enabled: everything);
    expect(stoicCounts.families[QuoteFamily.christian], inFamily(QuoteFamily.christian),
        reason: 'switching source, not adding to it');
    expect(stoicCounts.authors.map((a) => a.name).toSet(), {'Epictetus', 'Marcus Aurelius', 'Seneca'});
  });

  test('authors: one entry per person however written, A to Z, without Scripture', () {
    final authors = QuoteFacets.authors(library);
    final aslan = authors.firstWhere((a) => a.name.toLowerCase() == 'aslan');
    expect(aslan.count, 2);
    expect(authors.any((a) => a.name.contains(':')), isFalse, reason: 'no verse references');
    final keys = authors.map((a) => QuoteFacets.authorKey(a.name)).toList();
    expect(keys, [...keys]..sort());
    expect(QuoteFacets.authorKey('G.K. Chesterton'), QuoteFacets.authorKey('g. k.  Chesterton'));
    expect(QuoteFacets.authorKey('Thomas à Kempis'), 'thomas a kempis');
  });

  test('a filter counts what is on, and clearing keeps the words', () {
    const filter = QuoteFilter(
      list: QuoteList.saved,
      families: {QuoteFamily.stoic},
      themes: {QuoteTheme.momentum, QuoteTheme.starting},
      author: 'Seneca',
      query: 'day',
    );
    expect(filter.count, 5);
    expect(filter.cleared(), const QuoteFilter(query: 'day'));
    expect(filter.cleared().isEmpty, isFalse);
    expect(const QuoteFilter().isEmpty, isTrue);
    expect(filter.toggleTheme(QuoteTheme.momentum).themes, {QuoteTheme.starting});
    expect(filter.copyWith(clearAuthor: true).author, isNull);
  });
}
