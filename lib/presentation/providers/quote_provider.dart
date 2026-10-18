import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import '../../core/copy/quotes.dart';
import '../../core/exceptions/storage_exceptions.dart';
import '../../domain/entities/quote.dart';
import '../../domain/repositories/quote_repository.dart';
import '../../domain/services/quote_of_the_day.dart';
import '../../domain/usecases/manage_quotes_usecase.dart';

/// The quote library (the app's own quotes plus the person's), what they've
/// saved, and the quote of the day.
class QuoteProvider extends ChangeNotifier {
  final QuoteRepository _repository;
  final ManageQuotesUseCase _manage;

  QuoteProvider(this._repository, this._manage);

  List<Quote> _mine = const [];
  List<String> _saved = const [];
  String? _error;

  /// Why the last change failed, in words to show the person.
  String? get error => _error;

  Future<void> load() async {
    _mine = await _repository.getMine();
    _saved = await _repository.getSaved();
    notifyListeners();
  }

  /// Their own quotes, newest first.
  List<Quote> get mine => _mine.reversed.toList();

  /// Every quote: the app's, then theirs.
  List<Quote> get all => [...Quotes.library, ..._mine];

  /// Every quote from the [families] turned on.
  List<Quote> from(Set<QuoteFamily> families) => [for (final q in all) if (families.contains(q.family)) q];

  /// Today's quote (or [now]'s) from the [families] turned on.
  Quote? today(Set<QuoteFamily> families, {DateTime? now}) => QuoteOfTheDay.pick(now ?? clock.now(), from(families));

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
  Future<Quote?> addMine({required String text, required String author, String source = ''}) async {
    final ok = await _run(() async => _mine = await _manage.addMine(text: text, author: author, source: source));
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
