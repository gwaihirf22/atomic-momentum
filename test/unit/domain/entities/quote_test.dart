import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/quote.dart';

void main() {
  const quote = Quote(
    id: 'mine-1',
    text: 'Journey before destination.',
    author: 'Words of Radiance',
    source: 'Brandon Sanderson',
    family: QuoteFamily.mine,
    themes: {QuoteTheme.momentum},
  );

  test('round-trips through JSON', () {
    expect(Quote.fromJson(quote.toJson()), quote);
    const bare = Quote(id: 'mine-2', text: 'Just this.', author: '', family: QuoteFamily.mine);
    expect(bare.toJson().containsKey('source'), isFalse);
    expect(Quote.fromJson(bare.toJson()), bare);
  });

  test('reading is forgiving, but a quote needs an id and text', () {
    final read = Quote.fromJson({'id': 'x', 'text': 'Hi', 'family': 'nonsense', 'themes': ['momentum', 'nope', 4]});
    expect(read.family, QuoteFamily.mine);
    expect(read.themes, {QuoteTheme.momentum});
    expect(read.author, '');
    expect(() => Quote.fromJson({'text': 'Hi'}), throwsFormatException);
    expect(() => Quote.fromJson({'id': 'x', 'text': ''}), throwsFormatException);
  });

  test('copyWith changes only the words', () {
    final changed = quote.copyWith(text: 'Life before death.');
    expect(changed.text, 'Life before death.');
    expect(changed.id, quote.id);
    expect(changed.family, quote.family);
    expect(changed.themes, quote.themes);
  });
}
