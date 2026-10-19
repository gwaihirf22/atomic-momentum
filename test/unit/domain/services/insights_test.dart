import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/habit_goal.dart';
import 'package:atomic_momentum/domain/entities/habit_metadata.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/entities/streak_data.dart';
import 'package:atomic_momentum/domain/entities/two_minute_version.dart';
import 'package:atomic_momentum/domain/services/insights.dart';

/// Statistics across habits: the heatmap, momentum by month, two-minute
/// days, weekdays and totals.
void main() {
  // 2024-01-15 is a Monday
  DateTime jan(int day) => DateTime(2024, 1, day);
  final now = DateTime(2024, 1, 15, 12);

  Habit habit({
    String id = 'h',
    ResetFrequency frequency = ResetFrequency.daily,
    int target = 1,
    Map<DateTime, int> history = const {},
    DateTime? created,
    List<int>? weekdays,
    Set<DateTime> twoMinuteDays = const {},
    HabitGoal goal = HabitGoal.build,
    DateTime? at,
  }) {
    final made = created ?? jan(1);
    return Habit(
      id: id,
      name: 'Habit $id',
      progress: 0,
      target: target,
      color: HabitColor.teal,
      categoryId: BuiltInCategoryIds.mind,
      lastUpdatedDate: at ?? now,
      resetFrequency: frequency,
      history: history,
      streak: StreakData.empty(),
      metadata: HabitMetadata(createdDate: made, lastModifiedDate: made, version: 1, customFields: const {}),
      resetAnchorDate: made,
      scheduledWeekdays: weekdays,
      twoMinute: const TwoMinuteVersion(description: 'One page'),
      twoMinuteDays: twoMinuteDays,
      goal: goal,
    ).refresh(at ?? now);
  }

  Map<DateTime, DayRecord> byDay(List<DayRecord> records) => {for (final r in records) r.day: r};

  group('days (the heatmap)', () {
    test('one record per day; a daily habit counts each day: done, two-minute, missed', () {
      final h = habit(history: {jan(10): 1, jan(12): 1}, twoMinuteDays: {jan(11)});
      final days = Insights.days([h], from: jan(8), to: jan(15), now: now);
      expect(days.map((d) => d.day), [for (var d = 8; d <= 15; d++) jan(d)]);

      final d = byDay(days);
      expect(d[jan(10)]!.level, 1);
      expect(d[jan(10)]!.perfect, isTrue);
      expect(d[jan(11)]!.twoMinute, 1);
      expect(d[jan(11)]!.level, 0.5);
      expect(d[jan(11)]!.perfect, isFalse, reason: 'two-minute is kept, not perfect');
      expect(d[jan(13)]!.due, 1);
      expect(d[jan(13)]!.level, 0, reason: 'missed');
    });

    test('days before a habit was tracked, and rest days, are empty', () {
      final made = habit(created: jan(10), history: {jan(10): 1});
      expect(byDay(Insights.days([made], from: jan(8), to: jan(10), now: now))[jan(9)]!.isEmpty, isTrue);

      // Mon/Wed/Fri: Sunday the 14th is a rest day
      final mwf = habit(weekdays: const [1, 3, 5], history: {jan(12): 1});
      expect(byDay(Insights.days([mwf], from: jan(8), to: jan(15), now: now))[jan(14)]!.isEmpty, isTrue);
    });

    test('perfect only when every habit counted that day was done', () {
      final a = habit(id: 'a', history: {jan(12): 1, jan(13): 1});
      final b = habit(id: 'b', history: {jan(12): 1}, target: 2);
      final d = byDay(Insights.days([a, b], from: jan(12), to: jan(13), now: now));
      expect(d[jan(12)]!.perfect, isFalse, reason: 'b did 1 of 2');
      expect(d[jan(12)]!.level, closeTo(0.75, 1e-9));
      expect(d[jan(13)]!.done, 1);
      expect(d[jan(13)]!.perfect, isFalse);
    });

    test('today shows what is done so far', () {
      final h = habit(target: 4, history: {jan(15): 1});
      expect(byDay(Insights.days([h], from: jan(15), to: jan(15), now: now))[jan(15)]!.level, 0.25);
    });

    test('a weekly habit shows on the day its week was kept, and a missed week nowhere', () {
      // Weeks start on Mondays (created Monday the 1st): week of the 1st kept on Wednesday the 3rd
      final h = habit(frequency: ResetFrequency.weekly, target: 3, history: {jan(2): 2, jan(3): 1, jan(9): 1});
      final d = byDay(Insights.days([h], from: jan(1), to: jan(14), now: now));
      expect(d[jan(3)]!.done, 1);
      expect([for (final r in d.values) if (!r.isEmpty) r.day], [jan(3)], reason: 'the week of the 8th was missed');
    });

    test('a habit being broken: clean days are done, a slip is not', () {
      final h = habit(goal: HabitGoal.quit, target: 0, history: {jan(12): 1});
      final d = byDay(Insights.days([h], from: jan(11), to: jan(13), now: now));
      expect(d[jan(11)]!.perfect, isTrue);
      expect(d[jan(12)]!.level, 0);
      expect(d[jan(13)]!.perfect, isTrue);
    });

    test('a year of days is consecutive across clock changes', () {
      final h = habit(created: DateTime(2023, 1, 1));
      final days = Insights.days([h], from: DateTime(2023, 1, 1), to: DateTime(2023, 12, 31), now: now);
      expect(days, hasLength(365));
      for (var i = 1; i < days.length; i++) {
        final prev = days[i - 1].day;
        expect(days[i].day, DateTime(prev.year, prev.month, prev.day + 1));
      }
    });

    test('a year for 20 habits is quick', () {
      final yearAgo = DateTime(2023, 1, 15);
      final habits = [
        for (var i = 0; i < 20; i++)
          habit(
            id: '$i',
            created: yearAgo,
            history: {for (var d = 0; d < 365; d += 1 + i % 3) DateTime(2023, 1, 15 + d): 1},
          ),
      ];
      final watch = Stopwatch()..start();
      Insights.days(habits, from: yearAgo, to: jan(15), now: now);
      expect(watch.elapsedMilliseconds, lessThan(3000));
    });
  });

  group('momentum by month', () {
    test('none before anything was tracked, then the average at each month end, this month so far', () {
      final at = DateTime(2024, 3, 20, 12);
      final h = habit(
        created: DateTime(2024, 1, 10),
        at: at,
        history: {for (var d = 10; d < 80; d++) DateTime(2024, 1, d): 1},
      );
      final months = Insights.momentumByMonth([h], at, count: 4);
      expect(months.map((m) => m.month), [DateTime(2023, 12), DateTime(2024, 1), DateTime(2024, 2), DateTime(2024, 3)]);
      expect(months[0].score, isNull);
      expect(months[2].score!, greaterThan(months[1].score!));
      expect(months[3].score!, closeTo(h.momentum.score, 1e-9));
    });

    test('averages the habits tracked at each month end, each as formed as it is', () {
      final at = DateTime(2024, 3, 20, 12);
      final steady = habit(id: 'a', created: DateTime(2024, 1, 1), at: at, history: {
        for (var d = 1; d < 80; d++) DateTime(2024, 1, d): 1,
      });
      final late = habit(id: 'b', created: DateTime(2024, 3, 1), at: at, history: {DateTime(2024, 3, 2): 1});
      final months = Insights.momentumByMonth([steady, late], at, count: 2);
      expect(months[0].score!, closeTo(steady.momentumSeries([DateTime(2024, 2, 29, 23, 59)]).single, 1e-9));
      // Each weighed by how formed it is, as on the Habits ring
      final a = steady.momentum, b = late.momentum;
      expect(months[1].score!, closeTo((a.score * a.formed + b.score * b.formed) / (a.formed + b.formed), 1e-9));
    });

    test('asking for fewer months first (the widgets) never shortens a later, longer ask (the Insights tab)', () {
      final at = DateTime(2024, 3, 20, 12);
      final h = habit(created: DateTime(2024, 1, 1), at: at, history: {
        for (var d = 1; d < 80; d++) DateTime(2024, 1, d): 1,
      });
      expect(Insights.momentumByMonth([h], at, count: 2), hasLength(2));
      final six = Insights.momentumByMonth([h], at);
      expect(six, hasLength(6));
      expect(six.last.score!, closeTo(h.momentum.score, 1e-9));
      expect(Insights.momentumByMonth([h], at, count: 2), hasLength(2));
    });
  });

  group('kept and two-minute days', () {
    test('counts the ended periods in range; today is not counted yet', () {
      final h = habit(history: {jan(10): 1, jan(12): 1}, twoMinuteDays: {jan(11)});
      final kept = Insights.kept([h], from: jan(10), now: now);
      expect(kept.full, 2);
      expect(kept.twoMinute, 1);
      expect(kept.missed, 2, reason: 'the 13th and 14th; the 15th is under way');
    });

    test('a two-minute day right after a miss saved a streak; after two misses it starts a new one', () {
      final h = habit(
        created: jan(5),
        history: {jan(5): 1, jan(6): 1, jan(10): 1},
        twoMinuteDays: {jan(8), jan(13)},
      );
      // 5 done, 6 done, 7 missed, 8 two-minute (saved), 9 missed, 10 done,
      // 11 missed, 12 missed, 13 two-minute (streak had ended), 14 missed
      expect(Insights.kept([h], from: jan(5), now: now).streaksSaved, 1);
    });

    test('a two-minute day with no miss before it saved nothing', () {
      final h = habit(created: jan(10), history: {jan(10): 1}, twoMinuteDays: {jan(11)});
      expect(Insights.kept([h], from: jan(10), now: now).streaksSaved, 0);
    });
  });

  group('weekdays', () {
    test('the best and hardest weekday once each has enough days', () {
      final made = DateTime(2023, 11, 6); // a Monday, ten weeks back
      final history = <DateTime, int>{
        for (var d = made; d.isBefore(jan(15)); d = DateTime(d.year, d.month, d.day + 1))
          if (d.weekday != DateTime.saturday && !(d.weekday == DateTime.wednesday && d.day.isEven)) d: 1,
      };
      final pattern = Insights.weekdays([habit(created: made, history: history)], from: made, now: now);
      expect(pattern.isEmpty, isFalse);
      expect(pattern.hardest, DateTime.saturday);
      expect(pattern.rates[DateTime.saturday], 0);
      expect(pattern.best, DateTime.monday);
    });

    test('says nothing with too few days', () {
      final pattern = Insights.weekdays([habit(created: jan(10), history: {jan(10): 1})], from: jan(1), now: now);
      expect(pattern.isEmpty, isTrue);
      expect(pattern.best, isNull);
    });
  });

  test('totals: habits formed and the longest streak', () {
    final made = DateTime(2023, 6, 1);
    final formed = habit(id: 'a', created: made, history: {
      for (var d = made; d.isBefore(jan(15)); d = DateTime(d.year, d.month, d.day + 1)) d: 1,
    });
    final fresh = habit(id: 'b', created: jan(12), history: {jan(12): 1, jan(13): 1});
    expect(Insights.formed([formed, fresh]), 1);
    expect(Insights.longestStreak([formed, fresh]), formed.streak.current);
    expect(Insights.longestStreak([formed, fresh]), greaterThan(200));
  });
}
