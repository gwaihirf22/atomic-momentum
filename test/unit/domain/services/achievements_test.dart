import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/habit_goal.dart';
import 'package:atomic_momentum/domain/entities/habit_metadata.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/entities/streak_data.dart';
import 'package:atomic_momentum/domain/entities/two_minute_version.dart';
import 'package:atomic_momentum/domain/services/achievements.dart';

void main() {
  // 2024-01-15 is a Monday
  final now = DateTime(2024, 1, 15, 12);
  final today = DateTime(2024, 1, 15);
  DateTime ago(int n) => DateTime(today.year, today.month, today.day - n);

  Habit habit({
    String id = 'h',
    String name = 'Read',
    ResetFrequency frequency = ResetFrequency.daily,
    int target = 1,
    Map<DateTime, int> history = const {},
    required DateTime created,
    List<int>? weekdays,
    Set<DateTime> twoMinuteDays = const {},
    HabitGoal goal = HabitGoal.build,
  }) =>
      Habit(
        id: id,
        name: name,
        progress: 0,
        target: target,
        color: HabitColor.teal,
        categoryId: BuiltInCategoryIds.mind,
        lastUpdatedDate: now,
        resetFrequency: frequency,
        history: history,
        streak: StreakData.empty(),
        metadata: HabitMetadata(createdDate: created, lastModifiedDate: created, version: 1, customFields: const {}),
        resetAnchorDate: created,
        scheduledWeekdays: weekdays,
        twoMinute: const TwoMinuteVersion(description: 'One page'),
        twoMinuteDays: twoMinuteDays,
        goal: goal,
      ).refresh(now);

  /// Logged on each of the days [from] days ago to [to] days ago, except [skip].
  Map<DateTime, int> logged(int from, int to, {Set<int> skip = const {}}) => {
        for (var i = from; i >= to; i--)
          if (!skip.contains(i)) ago(i): 1,
      };

  Map<String, Achievement> byId(List<Achievement> list) => {for (final a in list) a.id: a};

  group('streaks', () {
    test('7 and 21 days, on the day each was reached', () {
      final h = habit(created: ago(20), history: logged(20, 0));
      final earned = byId(Achievements.earned([h], now));
      expect(earned['streak_7_h']!.earnedOn, ago(14));
      expect(earned['streak_21_h']!.earnedOn, today);
      expect(earned['streak_21_h']!.title, '21 days');
      expect(earned['streak_21_h']!.unit, 'DAYS');
      expect(earned.containsKey('streak_66_h'), isFalse);
    });

    test('one miss is bridged (never miss twice); the streak goes on', () {
      // 6 days, a miss, then on: the 7th kept day reaches 7
      final h = habit(created: ago(10), history: logged(10, 0, skip: {4}));
      expect(byId(Achievements.earned([h], now))['streak_7_h']!.earnedOn, ago(3));
    });

    test('rest days and every few days count "in a row"', () {
      final mwf = habit(created: DateTime(2023, 12, 1), weekdays: const [1, 3, 5], history: {
        for (var d = DateTime(2023, 12, 1); !d.isAfter(today); d = DateTime(d.year, d.month, d.day + 1))
          if (d.weekday == 1 || d.weekday == 3 || d.weekday == 5) d: 1,
      });
      final streak = byId(Achievements.earned([mwf], now))['streak_7_h']!;
      expect(streak.title, '7 in a row');
      expect(streak.unit, 'IN A ROW');
    });

    test('weekly habits count weeks', () {
      final weekly = habit(
        created: DateTime(2023, 12, 4),
        frequency: ResetFrequency.weekly,
        history: {for (var w = 0; w < 6; w++) DateTime(2023, 12, 4 + 7 * w): 1},
      );
      expect(byId(Achievements.earned([weekly], now))['streak_4_h']!.title, '4 weeks');
    });

    test('the 66-day milestone cites the research', () {
      final h = habit(created: ago(70), history: logged(70, 0));
      expect(byId(Achievements.earned([h], now))['streak_66_h']!.message, contains('Lally'));
    });
  });

  group('breaking a habit', () {
    test('quit: days without it, counting a day once it is over', () {
      final h = habit(name: 'Smoking', goal: HabitGoal.quit, target: 0, created: DateTime(2023, 12, 15, 9));
      final earned = byId(Achievements.earned([h], now));
      expect(earned['clean_1_h']!.title, '1 day without smoking');
      expect(earned['clean_1_h']!.earnedOn, DateTime(2023, 12, 15));
      expect(earned['clean_30_h']!.title, '30 days without smoking');
      expect(earned['clean_30_h']!.message, contains('real change'));
      expect(earned.containsKey('clean_90_h'), isFalse);
    });

    test('added today: nothing yet, the day is not over', () {
      final h = habit(name: 'Smoking', goal: HabitGoal.quit, target: 0, created: DateTime(2024, 1, 15, 9));
      expect(Achievements.earned([h], now), isEmpty);
    });

    test('a limit reads "within your limit"; a slip day breaks the run', () {
      final h = habit(
        name: 'Alcohol',
        goal: HabitGoal.limit,
        target: 2,
        created: ago(12),
        history: {ago(5): 3, ago(4): 3},
      );
      final earned = byId(Achievements.earned([h], now));
      expect(earned['clean_7_h']!.title, '7 days within your limit');
      expect(earned['clean_7_h']!.earnedOn, ago(6));
    });
  });

  test('habit formed: momentum reached 80, with how many days it took', () {
    final h = habit(created: ago(80), history: logged(80, 0));
    final formed = byId(Achievements.earned([h], now))['formed_h']!;
    expect(formed.earnedOn.isAfter(ago(20)), isTrue);
    expect(formed.earnedOn.isBefore(ago(10)), isTrue);
    expect(formed.message, contains('Momentum reached 80 in'));
  });

  test('showed up anyway: the 10th two-minute day', () {
    final tiny = {for (var i = 12; i >= 1; i--) ago(i)};
    final h = habit(created: ago(12), twoMinuteDays: tiny);
    final earned = byId(Achievements.earned([h], now));
    expect(earned['showedUp_10']!.earnedOn, ago(3));
    expect(earned.containsKey('showedUp_50'), isFalse);
  });

  test('never missed twice: five comebacks', () {
    // Kept, then a miss every third day, five times
    final h = habit(created: ago(16), history: logged(16, 0, skip: {14, 11, 8, 5, 2}));
    final earned = byId(Achievements.earned([h], now));
    expect(earned['neverTwice_5']!.earnedOn, ago(1));
  });

  test('a perfect week: every habit kept every day; a miss spoils it', () {
    // The week of Mon 1 Jan to Sun 7 Jan, and the week after
    final a = habit(id: 'a', created: DateTime(2024, 1, 1), history: logged(14, 1));
    final b = habit(id: 'b', created: DateTime(2024, 1, 1), history: logged(14, 1, skip: {3}));
    final earned = byId(Achievements.earned([a, b], now));
    expect(earned['perfectWeek_1']!.earnedOn, DateTime(2024, 1, 7));
    expect(earned.containsKey('perfectWeek_4'), isFalse);
  });

  test('a comeback: a new streak built to 7 after one ended', () {
    final h = habit(created: ago(20), history: {...logged(20, 12), ...logged(8, 0)});
    // 9 days, two misses (ended), then 9 more: the 7th of them is 2 days ago
    final earned = byId(Achievements.earned([h], now));
    expect(earned['comeback_h']!.earnedOn, ago(2));
  });

  test('a new best: the current run passed the longest before it', () {
    final h = habit(created: ago(20), history: {...logged(20, 16), ...logged(9, 0)});
    // 5 days, misses, then 10 days: the 6th of them passed the 5
    final best = Achievements.earned([h], now).firstWhere((a) => a.kind == AchievementKind.personalBest);
    expect(best.earnedOn, ago(4));
    expect(best.badge, '10');
    expect(best.onShelf, isFalse);
  });

  test('next: the closest milestone for each habit', () {
    final h = habit(created: ago(2), history: logged(2, 0));
    final next = Achievements.next([h], now);
    expect(next.single.title, '7 days');
    expect(next.single.current, 3);
    expect(next.single.goal, 7);
  });
}
