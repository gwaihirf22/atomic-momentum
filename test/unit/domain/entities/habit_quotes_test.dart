import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/data/models/habit_model.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import '../../../helpers/test_data.dart';

/// Quotes kept with a habit (by id).
void main() {
  T at<T>(T Function() body) => withClock(Clock.fixed(DateTime(2024, 1, 15, 12)), body);

  test('quotes are added once, in order, and removed', () {
    final habit = TestData.createTestHabit();
    expect(habit.quoteIds, isEmpty);
    final kept = habit.addQuote('a').addQuote('b').addQuote('a');
    expect(kept.quoteIds, ['a', 'b']);
    expect(kept.removeQuote('a').quoteIds, ['b']);
    expect(identical(kept.removeQuote('missing'), kept), isTrue);
  });

  test('a habit keeps up to ten quotes', () {
    var habit = TestData.createTestHabit();
    for (var i = 0; i < Habit.maxQuotes; i++) {
      habit = habit.addQuote('q$i');
    }
    expect(() => habit.addQuote('one more'), throwsArgumentError);
    expect(() => habit.setQuotes([for (var i = 0; i <= Habit.maxQuotes; i++) 'q$i']), throwsArgumentError);
    expect(habit.setQuotes(['x', 'x', '', 'y']).quoteIds, ['x', 'y']);
  });

  test('quotes survive saving and loading, in both formats', () {
    final habit = TestData.createTestHabit().addQuote('epictetus-fig').addQuote('mine-1');

    expect(Habit.fromJson(habit.toJson()).quoteIds, ['epictetus-fig', 'mine-1']);
    final stored = HabitModel.fromDomain(habit).toJson();
    expect(stored['quotes'], ['epictetus-fig', 'mine-1']);
    expect(HabitModel.fromJson(stored).toDomain().quoteIds, ['epictetus-fig', 'mine-1']);
    expect(HabitModel.fromJson(stored).toDomain(), habit);
  });

  test('habits saved before quotes existed load with none, and store none', () {
    final json = HabitModel.fromDomain(TestData.createTestHabit()).toJson()..remove('quotes');
    final habit = HabitModel.fromJson(json).toDomain();
    expect(habit.quoteIds, isEmpty);
    expect(HabitModel.fromDomain(habit).toJson().containsKey('quotes'), isFalse);
  });

  test('bad stored quote lists are cleaned up', () {
    expect(Habit.quoteIdsFromJson(['a', 3, '', 'a', 'b', null]), ['a', 'b']);
    expect(Habit.quoteIdsFromJson('a'), isEmpty);
    expect(Habit.quoteIdsFromJson(null), isEmpty);
  });

  test('editing the habit, or changing when it counts from, keeps its quotes', () {
    final habit = TestData.createTestHabit().addQuote('epictetus-fig');
    expect(at(() => habit.updateDetails(name: 'Renamed', target: 4)).quoteIds, ['epictetus-fig']);
    expect(at(() => habit.setWhy('Why')).quoteIds, ['epictetus-fig']);
  });

  test('quotes count toward equality', () {
    final habit = TestData.createTestHabit();
    expect(habit.copyWith(quoteIds: ['a']) == habit, isFalse);
  });
}
