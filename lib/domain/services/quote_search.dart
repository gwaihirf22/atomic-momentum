import '../entities/quote.dart';

/// Finds quotes by words in their text, author or source. Every word typed
/// must appear somewhere; case, accents and apostrophe styles don't matter.
class QuoteSearch {
  const QuoteSearch._();

  static List<Quote> find(
    List<Quote> quotes, {
    String query = '',
    Set<QuoteTheme> themes = const {},
    Set<String>? onlyIds,
  }) {
    final words = normalize(query).split(' ').where((w) => w.isNotEmpty).toList();
    return [
      for (final quote in quotes)
        if ((onlyIds == null || onlyIds.contains(quote.id)) &&
            (themes.isEmpty || quote.themes.any(themes.contains)) &&
            _matches(quote, words))
          quote,
    ];
  }

  static bool _matches(Quote quote, List<String> words) {
    if (words.isEmpty) return true;
    final haystack = normalize('${quote.text} ${quote.author} ${quote.source}');
    return words.every(haystack.contains);
  }

  static const _plain = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
    'ç': 'c',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ñ': 'n',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    '‘': "'", '’': "'", '“': '"', '”': '"',
    '–': ' ', '—': ' ',
  };

  static final _wordChar = RegExp(r"[\p{L}\p{N}']", unicode: true);

  /// Lower case, accents and curly quotes made plain, punctuation spaced out.
  static String normalize(String text) {
    final buffer = StringBuffer();
    for (final char in text.toLowerCase().split('')) {
      final plain = _plain[char] ?? char;
      buffer.write(_wordChar.hasMatch(plain) ? plain : ' ');
    }
    return buffer.toString().replaceAll("'", '');
  }
}
