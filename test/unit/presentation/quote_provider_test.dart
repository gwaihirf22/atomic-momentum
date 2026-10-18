import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/data/repositories/quote_repository_impl.dart';
import 'package:atomic_momentum/domain/entities/quote.dart';
import 'package:atomic_momentum/domain/usecases/manage_quotes_usecase.dart';
import 'package:atomic_momentum/presentation/providers/quote_provider.dart';

/// "Another quote": swapping today's quote, and keeping it for the day.
void main() {
  final all = QuoteFamily.values.toSet();
  final morning = DateTime(2026, 10, 18, 8);
  final evening = DateTime(2026, 10, 18, 22);
  final tomorrow = DateTime(2026, 10, 19, 8);

  Future<QuoteProvider> load() async {
    final repository = QuoteRepositoryImpl(await SharedPreferences.getInstance());
    final quotes = QuoteProvider(repository, ManageQuotesUseCase(repository));
    await quotes.load();
    return quotes;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    QuoteProvider.random = Random(7);
  });

  test('swaps today\'s quote for a different one, every time', () async {
    final quotes = await load();
    var shown = quotes.today(all, now: morning)!;
    for (var i = 0; i < 20; i++) {
      expect(await quotes.another(all, now: morning), isTrue);
      final next = quotes.today(all, now: morning)!;
      expect(next.id, isNot(shown.id));
      shown = next;
    }
  });

  test('the new quote stays all day, after a restart too, and the turns go on tomorrow', () async {
    final quotes = await load();
    final usual = quotes.today(all, now: morning)!;
    final usualTomorrow = quotes.today(all, now: tomorrow)!;
    await quotes.another(all, now: morning);
    final chosen = quotes.today(all, now: morning)!;

    expect(quotes.today(all, now: evening), chosen);
    expect((await load()).today(all, now: evening), chosen, reason: 'kept across a restart');
    expect(quotes.today(all, now: tomorrow), usualTomorrow);
    expect(chosen, isNot(usual));
  });

  test('turning off the chosen quote\'s source brings back the day\'s turn', () async {
    final quotes = await load();
    await quotes.another(all, now: morning);
    final chosen = quotes.today(all, now: morning)!;
    final without = {...all}..remove(chosen.family);
    expect(quotes.today(without, now: morning)!.family, isNot(chosen.family));
  });

  test('with only one quote to show, there is no other', () async {
    final quotes = await load();
    await quotes.addMine(text: 'The only one.', author: 'Me');
    const mineOnly = {QuoteFamily.mine};
    final only = quotes.today(mineOnly, now: morning);
    expect(await quotes.another(mineOnly, now: morning), isFalse);
    expect(quotes.today(mineOnly, now: morning), only);
  });

  test('a stored pick that is unreadable is ignored', () async {
    SharedPreferences.setMockInitialValues({QuoteRepositoryImpl.chosenTodayKey: ['2026-10-18']});
    final quotes = await load();
    expect(quotes.today(all, now: morning), isNotNull);
  });
}
