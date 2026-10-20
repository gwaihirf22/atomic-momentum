import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/habit_goal.dart';
import 'package:atomic_momentum/domain/entities/habit_metadata.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/entities/streak_data.dart';
import 'package:atomic_momentum/domain/entities/two_minute_version.dart';
import 'package:atomic_momentum/domain/services/weekly_review.dart';

void main() {
  // Mon Jan 15 – Sun Jan 21, 2024, reviewed on Sunday evening at 6
  const sixPm = (hour: 18, minute: 0);
  final sunday = DateTime(2024, 1, 21);
  final sundayEvening = DateTime(2024, 1, 21, 19);
  DateTime day(int d) => DateTime(2024, 1, d);

  Habit habit({
    String id = 'h',
    String name = 'Read',
    required DateTime now,
    Map<DateTime, int> history = const {},
    DateTime? created,
    Set<DateTime> frozen = const {},
    HabitGoal goal = HabitGoal.build,
  }) {
    final start = created ?? day(1);
    return Habit(
      id: id,
      name: name,
      progress: 0,
      target: goal == HabitGoal.quit ? 0 : 1,
      color: HabitColor.teal,
      categoryId: BuiltInCategoryIds.mind,
      lastUpdatedDate: now,
      resetFrequency: ResetFrequency.daily,
      history: history,
      streak: StreakData.empty(),
      metadata: HabitMetadata(createdDate: start, lastModifiedDate: start, version: 1, customFields: const {}),
      resetAnchorDate: start,
      twoMinute: goal.isBreak ? null : const TwoMinuteVersion(description: 'One page'),
      frozenDays: frozen,
      goal: goal,
    ).refresh(now);
  }

  /// Logged on each day from [from] to [to] of January, except [skip].
  Map<DateTime, int> logged(int from, int to, {Set<int> skip = const {}}) => {
        for (var d = from; d <= to; d++)
          if (!skip.contains(d)) day(d): 1,
      };

  WeeklyReview? review(List<Habit> habits, DateTime now, {int weekStart = DateTime.monday}) =>
      WeeklyReview.of(habits, now: now, weekStart: weekStart, reviewTime: sixPm);

  group('which week', () {
    test('this week from its last evening, last week before then', () {
      DateTime week(DateTime now, int start) => WeeklyReview.weekFor(now, weekStart: start, reviewTime: sixPm);
      expect(week(DateTime(2024, 1, 21, 17, 59), DateTime.monday), day(8));
      expect(week(DateTime(2024, 1, 21, 18), DateTime.monday), day(15));
      expect(week(DateTime(2024, 1, 24, 9), DateTime.monday), day(15), reason: 'it stays until the next');
      // Weeks starting Sunday end on Saturday
      expect(week(DateTime(2024, 1, 20, 18, 30), DateTime.sunday), day(14));
      expect(week(DateTime(2024, 1, 20, 12), DateTime.sunday), day(7));
    });

    test('none until a habit has been tracked for a few days of the week', () {
      final late = habit(now: sundayEvening, created: day(20), history: logged(20, 21));
      expect(review([late], sundayEvening), isNull);
      final enough = habit(now: sundayEvening, created: day(19), history: logged(19, 21));
      expect(review([enough], sundayEvening), isNotNull);
      expect(review(const [], sundayEvening), isNull);
    });
  });

  test('a week with one miss: what was kept, the comeback, the days', () {
    final read = habit(now: sundayEvening, history: logged(1, 21, skip: {17}));
    final water = habit(id: 'w', name: 'Water', now: sundayEvening, history: logged(1, 21));
    final r = review([read, water], sundayEvening)!;
    expect(r.start, day(15));
    expect(r.end, sunday);
    expect(r.underWay, isTrue, reason: 'Sunday evening is still going');
    expect(r.kept.kept, 13);
    expect(r.kept.missed, 1);
    expect(r.days, hasLength(7));
    expect(r.perfectDays, 6);
    expect(r.perfectWeek, isFalse);
    expect(r.comebacks.single.habit.name, 'Read');
    expect(r.comebacks.single.comeback.missed, day(17));
    expect(r.comebacks.single.comeback.back, day(18));
    expect(r.keptEveryTime.map((k) => (k.habit.name, k.times)), [('Water', 7)]);
    expect(r.bestStreak!.habit.name, 'Water');
  });

  test("on the last evening, what isn't done yet tonight isn't a miss", () {
    final read = habit(now: sundayEvening, history: logged(1, 20));
    final r = review([read], sundayEvening)!;
    expect(r.kept.missed, 0);
    expect(r.kept.kept, 6);
    expect(r.keptEveryTime.single.times, 6);
    expect(r.perfectWeek, isTrue);
  });

  test('looked at later in the next week, the week is final', () {
    final wednesday = DateTime(2024, 1, 24, 9);
    final read = habit(now: wednesday, history: logged(1, 24, skip: {21}));
    final r = review([read], wednesday)!;
    expect(r.start, day(15));
    expect(r.underWay, isFalse);
    expect(r.kept.missed, 1, reason: 'Sunday was missed');
    expect(r.comebacks, isEmpty, reason: "Monday's comeback is next week's");
  });

  test('momentum at both ends of the week', () {
    final read = habit(now: sundayEvening, created: day(8), history: logged(8, 21));
    final r = review([read], sundayEvening)!;
    expect(r.momentumBefore, isNotNull);
    expect(r.momentumAfter, greaterThan(r.momentumBefore!));
    expect(r.momentumChange, greaterThan(0));
  });

  test('wins, most notable first: achievements, the perfect week, then habits kept every time', () {
    // Started the Monday before last: 7 in a row is reached this week
    final read = habit(now: sundayEvening, created: day(15), history: logged(15, 21));
    final r = review([read], sundayEvening)!;
    final wins = r.wins();
    expect(wins.first, isA<EarnedWin>());
    expect((wins.first as EarnedWin).achievement.id, 'streak_7_h');
    expect(wins.whereType<PerfectWeekWin>(), hasLength(1));
    expect(wins.indexWhere((w) => w is PerfectWeekWin), lessThan(wins.indexWhere((w) => w is KeptEveryTimeWin)));
    expect(r.wins(max: 2), hasLength(2));
  });

  test('a habit being broken: a slip, then clean again, is a comeback', () {
    final smoking = habit(
      name: 'Smoking',
      now: sundayEvening,
      goal: HabitGoal.quit,
      history: {day(16): 1},
    );
    final r = review([smoking], sundayEvening)!;
    expect(r.comebacks.single.comeback.missed, day(16));
    expect(r.comebacks.single.comeback.back, day(17));
    // Clean so far tonight counts, as on Insights
    expect(r.kept.total, 7);
    expect(r.kept.missed, 1);
  });

  test('a frozen day is neither kept nor missed', () {
    final read = habit(now: sundayEvening, history: logged(1, 21, skip: {17}), frozen: {day(17)});
    final r = review([read], sundayEvening)!;
    expect(r.kept.missed, 0);
    expect(r.kept.kept, 6);
    expect(r.comebacks, isEmpty);
    expect(r.keptEveryTime.single.times, 6);
  });

  test('a quiet week says so', () {
    final weekly = habit(now: sundayEvening, history: const {});
    final r = review([weekly], sundayEvening)!;
    expect(r.kept.kept, 0);
    expect(r.wins(), isEmpty);
  });
}
