import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/habit_goal.dart';
import 'package:atomic_momentum/domain/entities/habit_metadata.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/entities/streak_data.dart';
import 'package:atomic_momentum/domain/services/year_review.dart';

void main() {
  DateTime day(int month, int d, [int year = 2025]) => DateTime(year, month, d);

  Habit habit({
    String id = 'h',
    String name = 'Read',
    required DateTime now,
    Map<DateTime, int> history = const {},
    DateTime? created,
    HabitGoal goal = HabitGoal.build,
  }) {
    final start = created ?? day(1, 1);
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
      goal: goal,
    ).refresh(now);
  }

  /// Logged every day from [from] to [to], except [skip].
  Map<DateTime, int> logged(DateTime from, DateTime to, {Set<DateTime> skip = const {}}) => {
        for (var d = from; !d.isAfter(to); d = DateTime(d.year, d.month, d.day + 1))
          if (!skip.contains(d)) d: 1,
      };

  YearReview? review(List<Habit> habits, DateTime now, {int? year}) =>
      YearReview.of(habits, year: year ?? YearReview.yearFor(now), now: now, weekStart: DateTime.monday);

  test('which year: this one (so far, in review from December 26), last year through January', () {
    expect(YearReview.yearFor(DateTime(2025, 6, 1)), 2025);
    expect(YearReview.yearFor(DateTime(2026, 1, 20)), 2025);
    expect(YearReview.isReviewSeason(DateTime(2025, 12, 25)), isFalse);
    expect(YearReview.isReviewSeason(DateTime(2025, 12, 26)), isTrue);
    expect(YearReview.isReviewSeason(DateTime(2026, 1, 31)), isTrue);
    expect(YearReview.isReviewSeason(DateTime(2026, 2, 1)), isFalse);
  });

  test('none until a week of the year is tracked', () {
    // (In January the review shown is last year's; this asks for this one)
    final now = DateTime(2025, 1, 4, 12);
    expect(review([habit(now: now, history: logged(day(1, 1), day(1, 4)))], now, year: 2025), isNull);
    final later = DateTime(2025, 1, 8, 12);
    expect(review([habit(now: later, history: logged(day(1, 1), day(1, 8)))], later, year: 2025), isNotNull);
  });

  test('a finished year: every day counted, kept, perfect days and the longest streak', () {
    final now = DateTime(2026, 1, 10, 12);
    // Every day of 2025 but two single misses (bridged: never miss twice)
    final read = habit(
      now: now,
      created: day(1, 1),
      history: logged(day(1, 1), day(12, 31), skip: {day(3, 10), day(7, 4)}),
    );
    final r = review([read], now)!;
    expect(r.year, 2025);
    expect(r.underWay, isFalse);
    expect(r.days.length, 365);
    expect(r.kept.total, 365);
    expect(r.kept.kept, 363);
    expect(r.perfectDays, 363);
    expect(r.bestStreak!.length, 363, reason: 'two single misses never end it');
    expect(r.comebacks, 2);
    expect(r.mostConsistent!.habit.id, read.id);
    expect(r.keptRate, closeTo(363 / 365, 1e-9));
  });

  test('a year in progress counts up to today, and a habit begun mid-year from its start', () {
    final now = DateTime(2025, 6, 30, 20);
    final run = habit(id: 'run', name: 'Run', now: now, created: day(6, 1), history: logged(day(6, 1), day(6, 30)));
    final r = review([run], now)!;
    expect(r.underWay, isTrue);
    expect(r.days.first.day, day(6, 1));
    expect(r.days.last.day, day(6, 30));
    expect(r.kept.total, 30);
    expect(r.bestMonth!.month, 6);
    expect(r.momentumStart, isNull, reason: 'nothing tracked before the year');
    expect(r.momentumEnd, isNotNull);
  });

  test('the best month is the one kept most, and needs enough due', () {
    final now = DateTime(2025, 4, 30, 20);
    final h = habit(
      now: now,
      history: {
        ...logged(day(1, 1), day(1, 31), skip: {for (var d = 1; d <= 15; d++) day(1, d)}),
        ...logged(day(2, 1), day(2, 28)),
        ...logged(day(3, 1), day(3, 31), skip: {day(3, 3), day(3, 9)}),
      },
    );
    final r = review([h], now)!;
    expect(r.bestMonth!.month, 2);
    expect(r.bestMonth!.rate, 1.0);
  });

  test('a habit being broken: a clean year keeps every day', () {
    final now = DateTime(2025, 3, 31, 20);
    final quit = habit(id: 'smoking', name: 'Smoking', now: now, goal: HabitGoal.quit, created: day(1, 1));
    final r = review([quit], now)!;
    expect(r.kept.missed, 0);
    expect(r.kept.kept, greaterThan(80));
  });

  test('remembered for the same habits and day', () {
    final now = DateTime(2025, 5, 1, 9);
    final habits = [habit(now: now, history: logged(day(1, 1), day(4, 30)))];
    expect(identical(review(habits, now), review(habits, DateTime(2025, 5, 1, 21))), isTrue);
  });
}
