import 'dart:math';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import '../../core/copy/quotes.dart';
import '../../core/exceptions/storage_exceptions.dart';
import '../../domain/entities/quote.dart';
import '../../domain/repositories/quote_repository.dart';
import '../../domain/services/quote_facets.dart';
import '../../domain/services/quote_of_the_day.dart';
import '../../domain/usecases/manage_quotes_usecase.dart';

/// The quote library (the app's own quotes plus the person's), what they've
/// saved, and the quote of the day.
class QuoteProvider extends ChangeNotifier {
  final QuoteRepository _repository;
  final ManageQuotesUseCase _manage;

  QuoteProvider(this._repository, this._manage);

  /// Source of "Another quote" picks; tests seed it (test/flutter_test_config.dart).
  static Random random = Random();

  List<Quote> _mine = const [];

  /// The quote picked with "Another quote", for the day it was picked.
  ({String day, String id})? _chosen;
  List<String> _saved = const [];
  String? _error;

  /// Why the last change failed, in words to show the person.
  String? get error => _error;

  Future<void> load() async {
    _mine = await _repository.getMine();
    _saved = await _repository.getSaved();
    _chosen = await _repository.getChosenToday();
    notifyListeners();
  }

  /// Their own quotes, newest first.
  List<Quote> get mine => _mine.reversed.toList();

  /// Every quote: the app's, then theirs.
  List<Quote> get all => [...Quotes.library, ..._mine];

  /// Every author's name in the library (theirs too), A to Z, for
  /// suggestions while they type one.
  List<String> get authors => QuoteFacets.authors(all).map((a) => a.name).toList();

  /// Every quote from the [families] turned on.
  List<Quote> from(Set<QuoteFamily> families) => [for (final q in all) if (families.contains(q.family)) q];

  /// Today's quote (or [now]'s) from the [families] turned on: the one
  /// picked with "Another quote" if it's for that day and its source is
  /// still on, otherwise the day's turn.
  Quote? today(Set<QuoteFamily> families, {DateTime? now}) {
    final date = now ?? clock.now();
    final chosen = _chosen;
    if (chosen != null && chosen.day == _dayKey(date)) {
      final quote = find(chosen.id);
      if (quote != null && families.contains(quote.family)) return quote;
    }
    return QuoteOfTheDay.pick(date, from(families));
  }

  /// Swaps today's quote for another at random from the [families] turned
  /// on (never the one showing). It stays for the rest of the day; the
  /// days' turns go on at midnight. False if there's nothing else to show.
  Future<bool> another(Set<QuoteFamily> families, {DateTime? now}) async {
    final date = now ?? clock.now();
    final current = today(families, now: date);
    final others = [for (final q in from(families)) if (q.id != current?.id) q];
    if (others.isEmpty) return false;
    final pick = others[random.nextInt(others.length)];
    _chosen = (day: _dayKey(date), id: pick.id);
    notifyListeners();
    try {
      await _repository.saveChosenToday(_chosen!.day, pick.id);
    } on AppException catch (e) {
      // Still shown for this session
      _error = e.message;
    }
    return true;
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Quote? find(String id) {
    for (final q in all) {
      if (q.id == id) return q;
    }
    return null;
  }

  /// [ids] as quotes, skipping any since deleted.
  List<Quote> resolve(Iterable<String> ids) => [for (final id in ids) if (find(id) case final quote?) quote];

  /// Saved ids, newest first.
  List<String> get savedIds => _saved;

  bool isSaved(String id) => _saved.contains(id);

  Future<bool> setSaved(String id, bool save) => _run(() async => _saved = await _manage.setSaved(id, save));

  /// Adds one of their own; returns the new quote, or null (see [error]).
  Future<Quote?> addMine({
    required String text,
    required String author,
    String source = '',
    QuoteFamily family = QuoteFamily.mine,
    Set<QuoteTheme> themes = const {},
  }) async {
    final ok = await _run(() async => _mine = await _manage.addMine(
          text: text,
          author: author,
          source: source,
          family: family,
          themes: themes,
        ));
    return ok ? _mine.last : null;
  }

  Future<bool> updateMine(Quote quote) => _run(() async => _mine = await _manage.updateMine(quote));

  Future<bool> deleteMine(String id) => _run(() async {
        _mine = await _manage.deleteMine(id);
        _saved = [for (final s in _saved) if (s != id) s];
      });

  Future<bool> _run(Future<void> Function() change) async {
    try {
      await change();
      _error = null;
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }
}
