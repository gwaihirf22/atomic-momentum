import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/core/copy/quotes.dart';
import 'package:atomic_momentum/domain/entities/quote.dart';
import 'package:atomic_momentum/domain/services/quote_of_the_day.dart';

/// The day's quote: one per calendar day, taking turns.
void main() {
  const library = Quotes.library;

  test('the same quote all day, a new one at midnight', () {
    final morning = QuoteOfTheDay.pick(DateTime(2026, 10, 18, 0, 1), library);
    expect(QuoteOfTheDay.pick(DateTime(2026, 10, 18, 23, 59), library), morning);
    expect(QuoteOfTheDay.pick(DateTime(2026, 10, 19, 0, 0), library), isNot(morning));
  });

  test('every quote shows once before any repeats', () {
    final start = DateTime(2026, 1, 1);
    final shown = [
      for (var i = 0; i < library.length; i++)
        QuoteOfTheDay.pick(DateTime(start.year, start.month, start.day + i), library)!.id,
    ];
    expect(shown.toSet().length, library.length);
    expect(
      QuoteOfTheDay.pick(DateTime(start.year, start.month, start.day + library.length), library),
      QuoteOfTheDay.pick(start, library),
    );
  });

  test('a day is its calendar date, whatever the time of day or clock change', () {
    // Clocks go back in New York on 2026-11-01; a 25-hour day is still one day
    expect(QuoteOfTheDay.dayNumber(DateTime(2026, 11, 2)) - QuoteOfTheDay.dayNumber(DateTime(2026, 11, 1)), 1);
    expect(QuoteOfTheDay.dayNumber(DateTime.utc(2024, 1, 1)), 0);
    expect(QuoteOfTheDay.dayNumber(DateTime(2024, 1, 1, 23)), 0);
  });

  test('only the quotes given take part, and none gives nothing', () {
    final stoics = [for (final q in library) if (q.family == QuoteFamily.stoic) q];
    for (var day = 1; day <= 40; day++) {
      expect(QuoteOfTheDay.pick(DateTime(2026, 3, day), stoics)!.family, QuoteFamily.stoic);
    }
    expect(QuoteOfTheDay.pick(DateTime(2026, 3, 1), const []), isNull);
  });

  test('adding a quote keeps the others in the same turn order', () {
    const added = Quote(id: 'mine-new', text: 'New', author: 'Me', family: QuoteFamily.mine);
    final before = QuoteOfTheDay.inTurn(library).map((q) => q.id).toList();
    final after = QuoteOfTheDay.inTurn([...library, added]).map((q) => q.id).where((id) => id != added.id).toList();
    expect(after, before);
  });

  test('the order does not depend on the order quotes are given in', () {
    expect(QuoteOfTheDay.inTurn(library.reversed.toList()), QuoteOfTheDay.inTurn(library));
  });
}
