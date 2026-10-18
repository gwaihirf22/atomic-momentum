import 'package:clock/clock.dart';
import '../entities/quote.dart';
import '../repositories/quote_repository.dart';
import '../../core/exceptions/storage_exceptions.dart';

/// Rules for the person's own quotes and their saved list. Each operation
/// loads what's stored, applies its rule, saves, and returns the new list.
class ManageQuotesUseCase {
  final QuoteRepository _repository;

  ManageQuotesUseCase(this._repository);

  /// The most quotes of their own a person can keep.
  static const maxMine = 500;

  static int _idCounter = 0;

  /// Adds one of their own, filed under [family] (My quotes unless they
  /// choose another source) with [themes].
  Future<List<Quote>> addMine({
    required String text,
    required String author,
    String source = '',
    QuoteFamily family = QuoteFamily.mine,
    Set<QuoteTheme> themes = const {},
  }) async {
    final mine = await _repository.getMine();
    if (mine.length >= maxMine) throw const ValidationException('You can keep up to $maxMine quotes of your own');
    final quote = _checked(Quote(
      id: '${Quote.mineIdPrefix}${clock.now().microsecondsSinceEpoch}_${_idCounter++}',
      text: text,
      author: author,
      source: source,
      family: family,
      themes: themes,
    ));
    final updated = [...mine, quote];
    await _repository.saveMine(updated);
    return updated;
  }

  Future<List<Quote>> updateMine(Quote changed) async {
    final mine = await _repository.getMine();
    if (!mine.any((q) => q.id == changed.id)) throw const ValidationException('That quote no longer exists');
    final quote = _checked(changed);
    final updated = [for (final q in mine) q.id == quote.id ? quote : q];
    await _repository.saveMine(updated);
    return updated;
  }

  /// Deletes one of their own quotes, and takes it off the saved list.
  Future<List<Quote>> deleteMine(String id) async {
    final mine = await _repository.getMine();
    final updated = [for (final q in mine) if (q.id != id) q];
    await _repository.saveMine(updated);
    final saved = await _repository.getSaved();
    if (saved.contains(id)) await _repository.saveSaved([for (final s in saved) if (s != id) s]);
    return updated;
  }

  /// Saves (newest first) or unsaves a quote.
  Future<List<String>> setSaved(String id, bool save) async {
    final without = [for (final s in await _repository.getSaved()) if (s != id) s];
    final updated = save ? [id, ...without] : without;
    await _repository.saveSaved(updated);
    return updated;
  }

  /// Trimmed, with each part checked.
  static Quote _checked(Quote quote) {
    final text = quote.text.trim();
    final author = quote.author.trim();
    final source = quote.source.trim();
    if (text.isEmpty) throw const ValidationException('Type the quote');
    if (text.length > Quote.maxTextLength) {
      throw const ValidationException('Keep the quote under ${Quote.maxTextLength} characters');
    }
    if (author.length > Quote.maxAuthorLength) {
      throw const ValidationException('Keep the name under ${Quote.maxAuthorLength} characters');
    }
    if (source.length > Quote.maxSourceLength) {
      throw const ValidationException('Keep the source under ${Quote.maxSourceLength} characters');
    }
    return quote.copyWith(text: text, author: author, source: source);
  }
}
