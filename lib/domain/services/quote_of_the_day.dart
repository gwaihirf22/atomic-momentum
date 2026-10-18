import '../entities/quote.dart';

/// The day's quote: the same one all day, everywhere it shows (the Inspire
/// tab now, a widget later), changing at local midnight. Quotes take turns
/// in an order set by their ids, so none repeats until every one has been
/// shown, and adding a quote doesn't shuffle the rest.
class QuoteOfTheDay {
  const QuoteOfTheDay._();

  /// Day numbers count from here.
  static final _epoch = DateTime.utc(2024, 1, 1);

  /// The quote for [date] from [quotes], or null if there are none.
  static Quote? pick(DateTime date, List<Quote> quotes) {
    if (quotes.isEmpty) return null;
    final ordered = inTurn(quotes);
    return ordered[dayNumber(date) % ordered.length];
  }

  /// [quotes] in the order they take turns.
  static List<Quote> inTurn(List<Quote> quotes) => [...quotes]..sort((a, b) {
        final byHash = _hash(a.id).compareTo(_hash(b.id));
        return byHash != 0 ? byHash : a.id.compareTo(b.id);
      });

  /// Days since 2024-01-01 for [date]'s calendar day (clock changes don't
  /// matter: it's counted from the date's own fields).
  static int dayNumber(DateTime date) => DateTime.utc(date.year, date.month, date.day).difference(_epoch).inDays;

  /// 32-bit FNV-1a: the same on every platform and every run.
  static int _hash(String text) {
    var hash = 0x811c9dc5;
    for (final unit in text.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }
}
