import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/habit_metadata.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/entities/streak_data.dart';
import 'package:atomic_momentum/domain/entities/two_minute_version.dart';
import 'package:atomic_momentum/domain/services/habit_stats.dart';

/// What the habit page shows about how a habit is going.
void main() {
  // Monday 2024-03-04, noon
  final now = DateTime(2024, 3, 4, 12);
  DateTime daysAgo(int n) => DateTime(2024, 3, 4 - n);

  Habit habit({
    ResetFrequency frequency = ResetFrequency.daily,
    Map<DateTime, int> history = const {},
    Set<DateTime> twoMinuteDays = const {},
    DateTime? created,
  }) =>
      Habit(
        id: 'h',
        name: 'Read',
        progress: 0,
        target: 2,
        color: HabitColor.teal,
        categoryId: BuiltInCategoryIds.mind,
        lastUpdatedDate: now,
        resetFrequency: frequency,
        history: history,
        streak: StreakData.empty(),
        metadata: HabitMetadata(
            createdDate: created ?? DateTime(2024, 1, 1), lastModifiedDate: now, version: 1, customFields: const {}),
        resetAnchorDate: DateTime(2024, 1, 1), // a Monday
        twoMinute: twoMinuteDays.isEmpty ? null : const TwoMinuteVersion(description: 'One page'),
        twoMinuteDays: twoMinuteDays,
      ).refresh(now);

  test('a daily habit: streaks, the last 30 days, and two-minute days among them', () {
    // Done the last 10 days (two of them with the two-minute version), missed before
    final h = habit(
      history: {for (var i = 1; i <= 10; i++) if (i != 3 && i != 6) daysAgo(i): 2},
      twoMinuteDays: {daysAgo(3), daysAgo(6)},
    );
    final stats = HabitStats.of(h, now);
    expect(stats.streak, 10);
    expect(stats.best, 10);
    expect(stats.recentLabel, 'Last 30 days');
    expect(stats.due, 29, reason: "today isn't over and isn't kept yet");
    expect(stats.kept, 10);
    expect(stats.keptWithTwoMinute, 2);
    expect(stats.keptShare, closeTo(10 / 29, 1e-9));
  });

  test('today counts once it is kept', () {
    final stats = HabitStats.of(habit(history: {daysAgo(0): 2}), now);
    expect(stats.due, 30);
    expect(stats.kept, 1);
  });

  test("momentum's last 30 days, oldest first, rising as days are kept", () {
    final h = habit(history: {for (var i = 0; i < 20; i++) daysAgo(i): 2});
    final stats = HabitStats.of(h, now);
    expect(stats.momentumTrend, hasLength(HabitStats.trendDays + 1));
    expect(stats.momentumTrend.last, greaterThan(stats.momentumTrend.first));
    expect(stats.momentumTrend.last, closeTo(stats.momentum.score, 1));
    expect(stats.momentumChange, greaterThan(0));
  });

  test("a daily habit's bars are its last 8 weeks, labelled with days kept", () {
    // Weeks start Monday: this week is just today
    final h = habit(history: {daysAgo(0): 2, daysAgo(1): 2, daysAgo(2): 2, daysAgo(8): 2});
    final stats = HabitStats.of(h, now);
    expect(stats.barsLabel, 'Last 8 weeks');
    expect(stats.bars, hasLength(8));
    expect(stats.bars.last.start, daysAgo(0));
    expect(stats.bars.last.label, '1');
    expect(stats.bars.last.fraction, 1.0, reason: 'only today is due so far this week');
    expect(stats.bars[6].label, '2', reason: 'last week: Sat and Sun');
    expect(stats.bars[5].label, '1');
  });

  test('weeks follow the chosen first day', () {
    final stats = HabitStats.of(habit(), now, weekStart: DateTime.sunday);
    expect(stats.bars.last.start, daysAgo(1));
  });

  test('a weekly habit counts weeks; its bars are its last 8 weeks', () {
    final h = habit(frequency: ResetFrequency.weekly, history: {daysAgo(7): 2, daysAgo(14): 1});
    final stats = HabitStats.of(h, now);
    expect(stats.recentLabel, 'Last 8 weeks');
    expect(stats.kept, 1);
    expect(stats.bars, hasLength(8));
    expect(stats.bars[6].fraction, 1.0);
    expect(stats.bars[5].fraction, 0.5);
  });

  test('a habit that never resets just has its total', () {
    final stats = HabitStats.of(habit(frequency: ResetFrequency.never, history: {daysAgo(3): 4, daysAgo(1): 5}), now);
    expect(stats.total, 9);
    expect(stats.bars, isEmpty);
    expect(stats.momentumTrend, isEmpty);
  });
}
