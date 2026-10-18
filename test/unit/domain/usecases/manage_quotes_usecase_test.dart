import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/exceptions/storage_exceptions.dart';
import 'package:atomic_momentum/data/repositories/quote_repository_impl.dart';
import 'package:atomic_momentum/domain/entities/quote.dart';
import 'package:atomic_momentum/domain/usecases/manage_quotes_usecase.dart';

void main() {
  late QuoteRepositoryImpl repository;
  late ManageQuotesUseCase manage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = QuoteRepositoryImpl(await SharedPreferences.getInstance());
    manage = ManageQuotesUseCase(repository);
  });

  test('adds their own quote, trimmed, with a new id each time', () async {
    final first = await manage.addMine(text: '  Journey before destination. ', author: ' Sanderson ');
    final second = await manage.addMine(text: 'Courage, dear heart.', author: 'Aslan', source: 'Dawn Treader');
    expect(second, hasLength(2));
    final quote = first.single;
    expect(quote.text, 'Journey before destination.');
    expect(quote.author, 'Sanderson');
    expect(quote.family, QuoteFamily.mine);
    expect(quote.id, startsWith(Quote.mineIdPrefix));
    expect(second.last.id, isNot(quote.id));
    expect(await repository.getMine(), second);
  });

  test('files their quote under the source and themes they choose', () async {
    final quote = (await manage.addMine(
      text: 'Courage, dear heart.',
      author: 'Aslan',
      family: QuoteFamily.stories,
      themes: {QuoteTheme.hardDays},
    ))
        .single;
    expect(quote.family, QuoteFamily.stories);
    expect(quote.themes, {QuoteTheme.hardDays});
    expect(quote.isMine, isTrue);

    final refiled = await manage.updateMine(quote.copyWith(family: QuoteFamily.christian, themes: {}));
    expect(refiled.single.family, QuoteFamily.christian);
    expect(refiled.single.themes, isEmpty);
    expect(await repository.getMine(), refiled, reason: 'stored, and read back as theirs');
  });

  test('checks the words', () async {
    expect(manage.addMine(text: '   ', author: 'x'), throwsA(isA<ValidationException>()));
    expect(manage.addMine(text: 'x' * (Quote.maxTextLength + 1), author: ''), throwsA(isA<ValidationException>()));
    expect(manage.addMine(text: 'ok', author: 'x' * (Quote.maxAuthorLength + 1)), throwsA(isA<ValidationException>()));
    expect(manage.addMine(text: 'ok', author: '', source: 'x' * (Quote.maxSourceLength + 1)),
        throwsA(isA<ValidationException>()));
  });

  test('edits and deletes; deleting also unsaves', () async {
    final quote = (await manage.addMine(text: 'One', author: 'A')).single;
    await manage.setSaved(quote.id, true);
    final edited = await manage.updateMine(quote.copyWith(text: ' Two '));
    expect(edited.single.text, 'Two');
    expect(edited.single.id, quote.id);

    expect(await manage.deleteMine(quote.id), isEmpty);
    expect(await repository.getSaved(), isEmpty);
    expect(manage.updateMine(quote), throwsA(isA<ValidationException>()));
  });

  test('saved quotes are newest first, each once', () async {
    await manage.setSaved('a', true);
    await manage.setSaved('b', true);
    expect(await manage.setSaved('a', true), ['a', 'b']);
    expect(await manage.setSaved('b', false), ['a']);
  });
}
