import 'package:equatable/equatable.dart';

/// Where a quote comes from; each can be turned off (Settings → Quote
/// sources, or the Inspire screen's options).
enum QuoteFamily {
  stoic('Stoics'),
  christian('Christian writers'),
  scripture('Scripture'),
  stories('Classic stories'),
  mine('My quotes');

  final String label;
  const QuoteFamily(this.label);

  static QuoteFamily? fromName(Object? name) => values.where((f) => f.name == name).firstOrNull;
}

/// What a quote speaks to: search chips now, and later the moments a quote
/// can mark (a comeback, a two-minute day, a habit formed).
enum QuoteTheme {
  starting('Starting'),
  smallSteps('Small steps'),
  momentum('Momentum'),
  hardDays('Hard days'),
  comeback('Comebacks'),
  perseverance('Keeping on'),
  breaking('Breaking habits'),
  purpose('Purpose');

  final String label;
  const QuoteTheme(this.label);

  static QuoteTheme? fromName(Object? name) => values.where((t) => t.name == name).firstOrNull;
}

/// A quote: one of the app's own (public domain, see core/copy/quotes.dart)
/// or one the person added ([QuoteFamily.mine]).
class Quote extends Equatable {
  /// Stable: habits and the saved list keep quotes by id.
  final String id;
  final String text;
  final String author;

  /// The work and place, with the translation where there is one
  /// ("Discourses 2.18 · tr. George Long"); empty for none.
  final String source;
  final QuoteFamily family;
  final Set<QuoteTheme> themes;

  const Quote({
    required this.id,
    required this.text,
    required this.author,
    this.source = '',
    required this.family,
    this.themes = const {},
  });

  bool get isMine => family == QuoteFamily.mine;

  static const maxTextLength = 400;
  static const maxAuthorLength = 80;
  static const maxSourceLength = 80;

  /// Prefix of the ids of the person's own quotes.
  static const mineIdPrefix = 'mine-';

  Quote copyWith({String? text, String? author, String? source}) => Quote(
        id: id,
        text: text ?? this.text,
        author: author ?? this.author,
        source: source ?? this.source,
        family: family,
        themes: themes,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'author': author,
        if (source.isNotEmpty) 'source': source,
        'family': family.name,
        if (themes.isNotEmpty) 'themes': [for (final t in themes) t.name],
      };

  /// Throws [FormatException] for anything without an id and text.
  factory Quote.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final text = json['text'];
    if (id is! String || id.isEmpty || text is! String || text.isEmpty) {
      throw const FormatException('A quote needs an id and text');
    }
    final themes = json['themes'];
    return Quote(
      id: id,
      text: text,
      author: json['author'] is String ? json['author'] as String : '',
      source: json['source'] is String ? json['source'] as String : '',
      family: QuoteFamily.fromName(json['family']) ?? QuoteFamily.mine,
      themes: {
        if (themes is List)
          for (final name in themes)
            if (QuoteTheme.fromName(name) case final theme?) theme,
      },
    );
  }

  @override
  List<Object?> get props => [id, text, author, source, family, themes];
}
