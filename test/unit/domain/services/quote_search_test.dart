import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/core/copy/quotes.dart';
import 'package:atomic_momentum/domain/entities/quote.dart';
import 'package:atomic_momentum/domain/services/quote_search.dart';

void main() {
  const library = Quotes.library;
  List<String> ids(List<Quote> quotes) => [for (final q in quotes) q.id];

  test('every word must appear, in the text, author or source', () {
    expect(ids(QuoteSearch.find(library, query: 'walking running')), ['epictetus-walking-by-walking']);
    expect(ids(QuoteSearch.find(library, query: 'gummere letters 104')), ['seneca-we-do-not-dare']);
    expect(QuoteSearch.find(library, query: 'epictetus').every((q) => q.author == 'Epictetus'), isTrue);
    expect(QuoteSearch.find(library, query: 'walking zebra'), isEmpty);
  });

  test('case, accents, apostrophes and punctuation are ignored', () {
    expect(ids(QuoteSearch.find(library, query: 'KEMPIS habit')), contains('kempis-habit-by-habit'));
    expect(ids(QuoteSearch.find(library, query: 'à kempis vice')), ['kempis-root-out-one-vice']);
    expect(ids(QuoteSearch.find(library, query: 'Isnt it nice')), ['montgomery-no-mistakes-yet']);
    expect(ids(QuoteSearch.find(library, query: 'isn’t it nice')), ['montgomery-no-mistakes-yet']);
    expect(ids(QuoteSearch.find(library, query: 'pilgrims progress cheer')), ['bunyan-feel-the-bottom']);
  });

  test('an empty search finds everything; themes narrow it', () {
    expect(QuoteSearch.find(library), hasLength(library.length));
    final comebacks = QuoteSearch.find(library, themes: {QuoteTheme.comeback});
    expect(comebacks, isNotEmpty);
    expect(comebacks.every((q) => q.themes.contains(QuoteTheme.comeback)), isTrue);
    expect(ids(QuoteSearch.find(library, query: 'seven', themes: {QuoteTheme.comeback})), ['kjv-proverbs-24-16']);
  });

  test('can be limited to some ids (the saved ones)', () {
    expect(ids(QuoteSearch.find(library, onlyIds: {'spurgeon-snail', 'kjv-micah-7-8'})),
        ['spurgeon-snail', 'kjv-micah-7-8']);
  });

  test('words in other alphabets are searchable', () {
    const quote = Quote(id: 'mine-1', text: 'Γνῶθι σεαυτόν', author: 'Delphi', family: QuoteFamily.mine);
    expect(QuoteSearch.find([quote], query: 'σεαυτόν'), [quote]);
  });
}
