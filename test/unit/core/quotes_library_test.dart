import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/core/copy/quotes.dart';
import 'package:atomic_momentum/domain/entities/quote.dart';

/// The app's own quotes: well-formed, credited, and none of the person's.
void main() {
  const library = Quotes.library;

  test('ids are unique, stable-looking, and never look like the person\'s own', () {
    final ids = [for (final q in library) q.id];
    expect(ids.toSet(), hasLength(ids.length));
    for (final id in ids) {
      expect(RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$').hasMatch(id), isTrue, reason: id);
      expect(id.startsWith(Quote.mineIdPrefix), isFalse, reason: id);
    }
  });

  test('every quote is credited and themed, with tidy text', () {
    for (final q in library) {
      expect(q.text.trim(), q.text, reason: q.id);
      expect(q.text, isNot(contains('  ')), reason: q.id);
      expect(q.text.length, inInclusiveRange(10, Quote.maxTextLength), reason: q.id);
      expect(q.author, isNotEmpty, reason: q.id);
      expect(q.author.length, lessThanOrEqualTo(Quote.maxAuthorLength), reason: q.id);
      expect(q.source.length, lessThanOrEqualTo(Quote.maxSourceLength), reason: q.id);
      expect(q.themes, isNotEmpty, reason: q.id);
      expect(q.family, isNot(QuoteFamily.mine), reason: q.id);
    }
  });

  test('scripture is the King James Version, cited by verse', () {
    for (final q in library.where((q) => q.family == QuoteFamily.scripture)) {
      expect(q.source, 'King James Version', reason: q.id);
      expect(RegExp(r'\d+:\d+').hasMatch(q.author), isTrue, reason: q.id);
    }
  });

  test('each built-in source has a good number of quotes, and every theme is used', () {
    for (final family in QuoteFamily.values.where((f) => f != QuoteFamily.mine)) {
      expect(library.where((q) => q.family == family).length, greaterThanOrEqualTo(10), reason: family.name);
    }
    for (final theme in QuoteTheme.values) {
      expect(library.where((q) => q.themes.contains(theme)), isNotEmpty, reason: theme.name);
    }
  });

  test('copyrighted authors are left to the person\'s own quotes', () {
    const notPublicDomain = ['Tolkien', 'C. S. Lewis', 'C.S. Lewis', 'Sanderson', 'Hays', 'Holiday'];
    for (final q in library) {
      for (final name in notPublicDomain) {
        expect('${q.author} ${q.source}', isNot(contains(name)), reason: q.id);
      }
    }
  });
}
