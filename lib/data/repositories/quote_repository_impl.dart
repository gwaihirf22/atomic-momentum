import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/exceptions/storage_exceptions.dart';
import '../../core/logging/log.dart';
import '../../domain/entities/quote.dart';
import '../../domain/repositories/quote_repository.dart';

class QuoteRepositoryImpl implements QuoteRepository {
  static const mineKey = 'quotes_mine_v1';
  static const savedKey = 'quotes_saved_v1';

  /// Where unreadable quotes are kept instead of being thrown away.
  static const corruptBackupKey = 'quotes_mine_v1_corrupt';

  final SharedPreferences _prefs;

  const QuoteRepositoryImpl(this._prefs);

  @override
  Future<List<Quote>> getMine() async {
    final raw = _prefs.getString(mineKey);
    if (raw == null) return [];
    final quotes = _parse(raw);
    if (quotes == null) {
      logWarning('Warning: Unreadable quotes, starting empty (raw data kept in $corruptBackupKey)');
      await _prefs.setString(corruptBackupKey, raw);
      await _prefs.remove(mineKey);
      return [];
    }
    return quotes;
  }

  @override
  Future<void> saveMine(List<Quote> quotes) async {
    final ok = await _prefs.setString(mineKey, jsonEncode([for (final q in quotes) q.toJson()]));
    if (!ok) throw const StorageException('Failed to write quotes to storage');
  }

  @override
  Future<List<String>> getSaved() async => _prefs.getStringList(savedKey) ?? [];

  @override
  Future<void> saveSaved(List<String> ids) async {
    final ok = await _prefs.setStringList(savedKey, ids);
    if (!ok) throw const StorageException('Failed to write saved quotes to storage');
  }

  /// Null when the data is unusable as a whole. Bad entries are skipped; for
  /// a repeated id the first wins. Everything stored is the person's own.
  List<Quote>? _parse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final seen = <String>{};
      final quotes = <Quote>[];
      for (final item in decoded) {
        try {
          final quote = Quote.fromJson(item as Map<String, dynamic>);
          if (quote.isMine && seen.add(quote.id)) quotes.add(quote);
        } catch (e) {
          logWarning('Warning: Skipping invalid quote: $item');
        }
      }
      return quotes;
    } catch (e) {
      return null;
    }
  }
}
