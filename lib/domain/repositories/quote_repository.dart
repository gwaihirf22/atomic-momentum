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

  /// The quote picked with "Another quote" and the day it was picked for
  /// ('yyyy-MM-dd'), or null if none.
  Future<({String day, String id})?> getChosenToday();

  Future<void> saveChosenToday(String day, String id);
}
