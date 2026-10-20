import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/habit_goal.dart';
import 'package:atomic_momentum/domain/entities/habit_metadata.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/entities/streak_data.dart';
import 'package:atomic_momentum/domain/entities/two_minute_version.dart';
import 'package:atomic_momentum/domain/services/today.dart';

void main() {
  // Wednesday, January 17, 2024, in the evening
  final now = DateTime(2024, 1, 17, 19);
  DateTime day(int d) => DateTime(2024, 1, d);

  Habit habit(
    String name, {
    Map<DateTime, int> history = const {},
    List<int>? weekdays,
    HabitGoal goal = HabitGoal.build,
    Set<DateTime> twoMinute = const {},
    Set<DateTime> frozen = const {},
  }) =>
      Habit(
        id: name,
        name: name,
        progress: 0,
        target: goal == HabitGoal.quit ? 0 : 1,
        color: HabitColor.teal,
        categoryId: BuiltInCategoryIds.mind,
        lastUpdatedDate: now,
        resetFrequency: ResetFrequency.daily,
        history: history,
        streak: StreakData.empty(),
        metadata: HabitMetadata(createdDate: day(1), lastModifiedDate: day(1), version: 1, customFields: const {}),
        resetAnchorDate: day(1),
        scheduledWeekdays: weekdays,
        twoMinute: goal.isBreak ? null : const TwoMinuteVersion(description: 'One page'),
        twoMinuteDays: twoMinute,
        frozenDays: frozen,
        goal: goal,
      ).refresh(now);

  Map<DateTime, int> every(int from, int to, {Set<int> skip = const {}}) =>
      {for (var d = from; d <= to; d++) if (!skip.contains(d)) day(d): 1};

  test("due today and done: in full or with the two-minute version", () {
    final today = Today.of([
      habit('Read', history: every(1, 17)),
      habit('Walk', history: every(1, 16), twoMinute: {day(17)}),
      habit('Gym', history: every(1, 16)),
    ], now);
    expect((today.due, today.done), (3, 2));
    expect(today.allDone, isFalse);
  });

  test('everything due done: all done', () {
    final today = Today.of([habit('Read', history: every(1, 17)), habit('Walk', history: every(1, 17))], now);
    expect(today.allDone, isTrue);
  });

  test("a rest day, a frozen day and a habit being broken aren't asked of today", () {
    final today = Today.of([
      habit('Read', history: every(1, 17)),
      // Mondays and Fridays only
      habit('Gym', weekdays: [1, 5]),
      habit('Walk', history: every(1, 16), frozen: {day(17)}),
      habit('Smoking', goal: HabitGoal.quit),
    ], now);
    expect((today.due, today.done), (1, 1));
    expect(today.allDone, isTrue);
  });

  test('nothing due: not all done', () {
    expect(Today.of(const [], now).allDone, isFalse);
  });

  test('the longest streak going, and a habit one miss from losing its streak', () {
    final today = Today.of([
      habit('Read', history: every(1, 17)),
      habit('Walk', history: every(10, 15)),
    ], now);
    expect(today.bestStreak!.habit.name, 'Read');
    expect(today.bestStreak!.length, 17);
    expect(today.atRisk?.name, 'Walk', reason: 'missed yesterday, not done today');
  });
}
