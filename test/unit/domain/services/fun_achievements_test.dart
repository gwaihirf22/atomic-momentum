import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/habit_pause.dart';
import 'package:atomic_momentum/domain/services/achievements.dart';

/// The fun achievements: when each is earned, and that it's earned once.
void main() {
  DateTime day(int m, int d, [int y = 2026]) => DateTime(y, m, d);
  final now = DateTime(2026, 11, 30, 21);

  setUp(() => Achievements.freezeSource = null);

  /// A daily habit tracked from [from], with [amounts] logged.
  Habit habit(String name, {DateTime? from, Map<DateTime, int> amounts = const {}, int target = 1}) {
    final start = from ?? day(10, 1);
    var h = withClock(Clock.fixed(DateTime(start.year, start.month, start.day, 8)), () => Habit.create(
          name: name,
          target: target,
          units: target > 1 ? 'glasses' : '',
          color: HabitColor.blue,
          categoryId: BuiltInCategoryIds.body,
        ));
    for (final e in amounts.entries) {
      h = withClock(Clock.fixed(DateTime(e.key.year, e.key.month, e.key.day, 20)), () => h.setProgressForDate(e.key, e.value));
    }
    return h;
  }

  Map<DateTime, int> everyDay(DateTime from, int days, [int amount = 1]) => {
        for (var i = 0; i < days; i++) DateTime(from.year, from.month, from.day + i): amount,
      };

  List<Achievement> fun(List<Habit> habits, {FreezeRecord? freezes}) =>
      Achievements.earned(habits, now, freezes: freezes).where((a) => a.kind == AchievementKind.fun).toList();

  Achievement? find(List<Achievement> list, String prefix) => list.where((a) => a.id.startsWith(prefix)).firstOrNull;

  test('Overachiever: three times the target in a period', () {
    final water = habit('Water', target: 8, amounts: {day(10, 3): 10, day(10, 5): 24});
    final a = find(fun([water]), 'fun_over')!;
    expect(a.earnedOn, day(10, 5));
    expect(a.message, contains('I asked for 8 glasses. You brought 24.'));
    expect(find(fun([habit('Water', target: 8, amounts: {day(10, 3): 23})]), 'fun_over'), isNull);
  });

  test('Speedrunner: the two-minute version five periods in a row', () {
    var read = habit('Read', amounts: everyDay(day(10, 1), 2));
    for (var d = 3; d <= 7; d++) {
      read = withClock(Clock.fixed(DateTime(2026, 10, d, 20)), () => read.setTwoMinuteForDate(day(10, d), true));
    }
    expect(find(fun([read]), 'fun_tiny5')!.earnedOn, day(10, 7));
  });

  test('Respawned: kept again right after a streak ended', () {
    final run = habit('Run', amounts: {...everyDay(day(10, 1), 3), day(10, 7): 1});
    expect(find(fun([run]), 'fun_respawn')!.earnedOn, day(10, 7));
    expect(find(fun([habit('Run', amounts: everyDay(day(10, 1), 9))]), 'fun_respawn'), isNull, reason: 'never ended');
  });

  test('No ice required: the first run of 30 with no freeze in it, on any habit (once)', () {
    final steady = habit('Walk', amounts: everyDay(day(10, 1), 30));
    expect(find(fun([steady]), 'fun_noIce')!.earnedOn, day(10, 30));

    var iced = habit('Walk', amounts: everyDay(day(10, 1), 5));
    iced = withClock(Clock.fixed(DateTime(2026, 10, 6, 9)), () => iced.freeze(day(10, 6)));
    for (final e in everyDay(day(10, 7), 30).entries) {
      iced = withClock(Clock.fixed(DateTime(e.key.year, e.key.month, e.key.day, 20)), () => iced.setProgressForDate(e.key, 1));
    }
    expect(iced.streak.current, 35);
    expect(find(fun([iced]), 'fun_noIce'), isNull, reason: 'the run has a freeze in it');
  });

  test('A lap around the sun: tracked for 365 days', () {
    final old = habit('Stretch', from: day(11, 1, 2025), amounts: {day(11, 2, 2025): 1});
    expect(find(fun([old]), 'fun_lap')!.earnedOn, day(11, 1));
  });

  test('Clean sweep: every habit done in full on a day with at least five due', () {
    final five = [for (var i = 0; i < 5; i++) habit('H$i', amounts: {day(10, 4): 1, if (i < 4) day(10, 3): 1})];
    expect(find(fun(five), 'fun_sweep')!.earnedOn, day(10, 4));
    expect(find(fun(five.take(4).toList()), 'fun_sweep'), isNull, reason: 'only four due');
  });

  test('Weekend warrior: every habit kept on a Saturday and the Sunday after', () {
    // Oct 10 and 11, 2026 are a Saturday and Sunday
    final a = habit('A', amounts: {day(10, 10): 1, day(10, 11): 1});
    final b = habit('B', amounts: {day(10, 10): 1, day(10, 11): 1});
    expect(find(fun([a, b]), 'fun_weekend')!.earnedOn, day(10, 11));
    final c = habit('C', amounts: {day(10, 10): 1});
    expect(find(fun([a, c]), 'fun_weekend'), isNull);
  });

  test('Dear diary: notes on ten days', () {
    var h = habit('Journal');
    for (var d = 1; d <= 10; d++) {
      h = withClock(Clock.fixed(DateTime(2026, 10, d, 20)), () => h.setDayNote(day(10, d), 'Day $d'));
    }
    expect(find(fun([h]), 'fun_diary')!.earnedOn, day(10, 10));
  });

  test('Juggler: ten habits tracked at once, from the day the tenth began', () {
    final habits = [for (var i = 0; i < 10; i++) habit('H$i', from: day(10, 1 + i))];
    expect(find(fun(habits), 'fun_juggler')!.earnedOn, day(10, 10));
  });

  test('Postcard: logged on the day a vacation ended', () {
    final h = habit('Read', amounts: {day(10, 1): 1, day(10, 12): 1})
        .copyWith(pauses: [HabitPause(from: day(10, 5), to: day(10, 12))]);
    expect(find(fun([h]), 'fun_postcard')!.earnedOn, day(10, 12));
  });

  test('Brain freeze and Rainy-day fund come from what the bank remembers', () {
    final h = habit('Read');
    final list = fun([h], freezes: (firstSpentOn: day(10, 9), fundReachedOn: day(11, 8)));
    expect(find(list, 'fun_firstFreeze')!.earnedOn, day(10, 9));
    expect(find(list, 'fun_fund')!.earnedOn, day(11, 8));
    expect(fun([h]), isEmpty);
  });

  test('only streak milestones and habits formed earn a freeze; fun ones come last', () {
    final run = habit('Run', amounts: everyDay(day(10, 1), 30));
    final earned = Achievements.earned([run], now);
    final streak = earned.firstWhere((a) => a.id.startsWith('streak_7'));
    final noIce = earned.firstWhere((a) => a.id == 'fun_noIce');
    expect(Achievements.earnsFreeze(streak), isTrue);
    expect(Achievements.earnsFreeze(noIce), isFalse);
    expect(noIce.rank, greaterThan(streak.rank));
    expect(noIce.onShelf, isTrue);
  });
}
