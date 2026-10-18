import 'package:equatable/equatable.dart';
import '../entities/quote.dart';
import 'quote_search.dart';

/// Which quotes a list starts from: every quote from the sources turned on,
/// the saved ones, or the person's own (those two whatever the sources).
enum QuoteList { all, saved, mine }

/// What the quote library is narrowed to: a list, then sources, themes and
/// an author (each group any of its choices; groups together), then words.
class QuoteFilter extends Equatable {
  final QuoteList list;
  final Set<QuoteFamily> families;
  final Set<QuoteTheme> themes;
  final String? author;
  final String query;

  const QuoteFilter({
    this.list = QuoteList.all,
    this.families = const {},
    this.themes = const {},
    this.author,
    this.query = '',
  });

  /// How many filters are on (words typed aside).
  int get count => (list == QuoteList.all ? 0 : 1) + families.length + themes.length + (author == null ? 0 : 1);

  bool get hasFilters => count > 0;

  /// Nothing narrows it: the library can be browsed instead.
  bool get isEmpty => !hasFilters && query.trim().isEmpty;

  QuoteFilter copyWith({
    QuoteList? list,
    Set<QuoteFamily>? families,
    Set<QuoteTheme>? themes,
    String? author,
    bool clearAuthor = false,
    String? query,
  }) =>
      QuoteFilter(
        list: list ?? this.list,
        families: families ?? this.families,
        themes: themes ?? this.themes,
        author: clearAuthor ? null : (author ?? this.author),
        query: query ?? this.query,
      );

  QuoteFilter toggleFamily(QuoteFamily family) =>
      copyWith(families: families.contains(family) ? ({...families}..remove(family)) : {...families, family});

  QuoteFilter toggleTheme(QuoteTheme theme) =>
      copyWith(themes: themes.contains(theme) ? ({...themes}..remove(theme)) : {...themes, theme});

  /// Every filter off; the words stay.
  QuoteFilter cleared() => QuoteFilter(query: query);

  @override
  List<Object?> get props => [list, families, themes, author, query];
}

/// An author in the library and how many of their quotes it holds.
class AuthorCount extends Equatable {
  final String name;
  final int count;

  const AuthorCount(this.name, this.count);

  @override
  List<Object?> get props => [name, count];
}

/// How many quotes each choice in the filters would show.
class QuoteFacetCounts {
  final Map<QuoteFamily, int> families;
  final Map<QuoteTheme, int> themes;
  final List<AuthorCount> authors;

  const QuoteFacetCounts({required this.families, required this.themes, required this.authors});
}

/// Narrows the library by a [QuoteFilter], and says what's in it: the
/// sources, themes and authors, each with how many quotes it would show.
class QuoteFacets {
  const QuoteFacets._();

  /// The quotes [filter] lets through. The All list holds only the
  /// [enabled] sources; Saved (in [savedIds] order, newest first) and Mine
  /// (newest first) hold every one.
  static List<Quote> apply(
    List<Quote> library,
    QuoteFilter filter, {
    required Set<QuoteFamily> enabled,
    List<String> savedIds = const [],
  }) {
    final base = switch (filter.list) {
      QuoteList.all => [for (final q in library) if (enabled.contains(q.family)) q],
      QuoteList.saved => [
          for (final id in savedIds)
            if (library.where((q) => q.id == id).firstOrNull case final quote?) quote,
        ],
      QuoteList.mine => [for (final q in library) if (q.isMine) q].reversed.toList(),
    };
    final author = filter.author == null ? null : authorKey(filter.author!);
    final narrowed = [
      for (final q in base)
        if ((filter.families.isEmpty || filter.families.contains(q.family)) &&
            (filter.themes.isEmpty || q.themes.any(filter.themes.contains)) &&
            (author == null || authorKey(q.author) == author))
          q,
    ];
    return QuoteSearch.find(narrowed, query: filter.query);
  }

  /// For each source, theme and author: how many quotes there would be with
  /// it chosen instead of that group's current choices, the rest of
  /// [filter] kept.
  static QuoteFacetCounts counts(
    List<Quote> library,
    QuoteFilter filter, {
    required Set<QuoteFamily> enabled,
    List<String> savedIds = const [],
  }) {
    int count(QuoteFilter f) => apply(library, f, enabled: enabled, savedIds: savedIds).length;
    return QuoteFacetCounts(
      families: {for (final family in QuoteFamily.values) family: count(filter.copyWith(families: {family}))},
      themes: {for (final theme in QuoteTheme.values) theme: count(filter.copyWith(themes: {theme}))},
      authors: authors(apply(library, filter.copyWith(clearAuthor: true), enabled: enabled, savedIds: savedIds)),
    );
  }

  /// The authors of [quotes], A to Z, each with their number of quotes.
  /// Names are matched ignoring case, accents and dots ("G.K." and "G. K."
  /// are one), shown as most often written. Scripture is left out: its
  /// "authors" are verse references.
  static List<AuthorCount> authors(List<Quote> quotes) {
    final spellings = <String, Map<String, int>>{};
    for (final q in quotes) {
      if (q.family == QuoteFamily.scripture) continue;
      final key = authorKey(q.author);
      if (key.isEmpty) continue;
      final names = spellings.putIfAbsent(key, () => {});
      names[q.author.trim()] = (names[q.author.trim()] ?? 0) + 1;
    }
    final result = [
      for (final names in spellings.values)
        AuthorCount(
          names.entries.reduce((a, b) => b.value > a.value ? b : a).key,
          names.values.fold(0, (sum, n) => sum + n),
        ),
    ]..sort((a, b) => authorKey(a.name).compareTo(authorKey(b.name)));
    return result;
  }

  /// An author's name as compared: plain lower case, single spaces.
  static String authorKey(String name) =>
      QuoteSearch.normalize(name).split(' ').where((w) => w.isNotEmpty).join(' ');
}
