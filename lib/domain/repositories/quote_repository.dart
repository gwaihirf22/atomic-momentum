import '../entities/quote.dart';

/// The person's own quotes and the ids of quotes they've saved. The app's
/// built-in quotes live in code (core/copy/quotes.dart), not here.
abstract class QuoteRepository {
  /// Their own quotes, oldest first. Never throws: unreadable data comes
  /// back empty (and is kept aside).
  Future<List<Quote>> getMine();

  Future<void> saveMine(List<Quote> quotes);

  /// Saved quote ids, newest first.
  Future<List<String>> getSaved();

  Future<void> saveSaved(List<String> ids);
}
