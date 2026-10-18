import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/data/repositories/quote_repository_impl.dart';
import 'package:atomic_momentum/domain/entities/quote.dart';

void main() {
  Future<(QuoteRepositoryImpl, SharedPreferences)> repoWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    return (QuoteRepositoryImpl(prefs), prefs);
  }

  const mine = Quote(id: 'mine-1', text: 'Keep going.', author: 'Gran', family: QuoteFamily.mine);

  test('nothing stored is nothing of their own and nothing saved', () async {
    final (repo, _) = await repoWith({});
    expect(await repo.getMine(), isEmpty);
    expect(await repo.getSaved(), isEmpty);
  });

  test('their quotes and saved ids are stored', () async {
    final (repo, _) = await repoWith({});
    await repo.saveMine([mine]);
    await repo.saveSaved(['spurgeon-snail', 'mine-1']);
    expect(await repo.getMine(), [mine]);
    expect(await repo.getSaved(), ['spurgeon-snail', 'mine-1']);
  });

  test('bad entries and repeats are skipped; only their own quotes are read', () async {
    final (repo, _) = await repoWith({
      QuoteRepositoryImpl.mineKey: jsonEncode([
        mine.toJson(),
        {'text': 'no id'},
        mine.toJson(),
        {'id': 'spurgeon-snail', 'text': 'By perseverance', 'family': 'christian'},
      ]),
    });
    expect(await repo.getMine(), [mine]);
  });

  test('unreadable data is kept aside, not lost', () async {
    final (repo, prefs) = await repoWith({QuoteRepositoryImpl.mineKey: '{not json'});
    expect(await repo.getMine(), isEmpty);
    expect(prefs.getString(QuoteRepositoryImpl.corruptBackupKey), '{not json');
    expect(prefs.getString(QuoteRepositoryImpl.mineKey), isNull);
  });
}
