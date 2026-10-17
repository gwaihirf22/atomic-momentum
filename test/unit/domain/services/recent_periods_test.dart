import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/habit_metadata.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/entities/streak_data.dart';
import 'package:atomic_momentum/domain/entities/two_minute_version.dart';
import 'package:atomic_momentum/domain/services/recent_periods.dart';
import 'package:atomic_momentum/presentation/widgets/recent_periods_bar.dart';

/// The last seven days (or weeks, or months) on a habit card.
void main() {
  // 2024-01-15 is a Monday
  DateTime jan(int day) => DateTime(2024, 1, day);
  final mondayNoon = DateTime(2024, 1, 15, 12);

  Habit habit({
    ResetFrequency frequency = ResetFrequency.daily,
    int target = 2,
    Map<DateTime, int> history = const {},
    DateTime? created,
    DateTime? anchor,
    List<int>? weekdays,
    Set<DateTime> twoMinuteDays = const {},
  }) {
    final made = created ?? jan(1);
    return Habit(
      id: 'h',
      name: 'Read',
      progress: 0,
      target: target,
      color: HabitColor.teal,
      categoryId: BuiltInCategoryIds.mind,
      lastUpdatedDate: mondayNoon,
      resetFrequency: frequency,
      history: history,
      streak: StreakData.empty(),
      metadata: HabitMetadata(createdDate: made, lastModifiedDate: made, version: 1, customFields: const {}),
      resetAnchorDate: anchor ?? made,
      scheduledWeekdays: weekdays,
      twoMinute: twoMinuteDays.isEmpty ? null : const TwoMinuteVersion(description: 'One page'),
      twoMinuteDays: twoMinuteDays,
    );
  }

  List<PeriodMark> marks(Habit h) => recentPeriods(h, mondayNoon).map((p) => p.mark).toList();

  test('daily: the last seven days, oldest first, ending today', () {
    final periods = recentPeriods(habit(), mondayNoon);
    expect(periods.map((p) => p.start), [for (var d = 9; d <= 15; d++) jan(d)]);
  });

  test('each day says how it went', () {
    final h = habit(
      history: {jan(9): 2, jan(10): 1, jan(13): 3, jan(15): 1},
      twoMinuteDays: {jan(12)},
    );
    expect(marks(h), [
      PeriodMark.done, // 9
      PeriodMark.partial, // 10: 1 of 2
      PeriodMark.missed, // 11
      PeriodMark.twoMinute, // 12
      PeriodMark.done, // 13
      PeriodMark.missed, // 14
      PeriodMark.current, // 15: today, 1 of 2 so far
    ]);
    final periods = recentPeriods(h, mondayNoon);
    expect(periods[1].fraction, 0.5);
    expect(periods[3].fraction, 0.5, reason: 'two-minute days count half');
    expect(periods[6].fraction, 0.5);
  });

  test('today shows as done once it is', () {
    expect(marks(habit(history: {jan(15): 2})).last, PeriodMark.done);
  });

  test('rest days are marked as rest', () {
    // Mon, Wed, Fri: Jan 9 is a Tuesday
    final h = habit(weekdays: const [1, 3, 5], history: {jan(10): 2, jan(12): 2});
    expect(marks(h), [
      PeriodMark.rest, // Tue 9
      PeriodMark.done, // Wed 10
      PeriodMark.rest, // Thu 11
      PeriodMark.done, // Fri 12
      PeriodMark.rest, // Sat 13
      PeriodMark.rest, // Sun 14
      PeriodMark.current, // Mon 15
    ]);
  });

  test('days before the habit was tracked are left blank', () {
    final h = habit(created: jan(13));
    expect(marks(h).take(4), everyElement(PeriodMark.untracked));
    expect(marks(h)[4], PeriodMark.missed);
  });

  test('earlier logged history counts as tracked', () {
    final h = habit(created: jan(14), history: {jan(11): 2});
    expect(marks(h)[2], PeriodMark.done);
    expect(marks(h).take(2), everyElement(PeriodMark.untracked));
  });

  test('weekly habits show their last seven weeks', () {
    final h = habit(
      frequency: ResetFrequency.weekly,
      created: DateTime(2023, 11, 20), // a Monday: weeks run Monday to Sunday
      history: {jan(1): 2, jan(9): 1, jan(15): 2},
    );
    final periods = recentPeriods(h, mondayNoon);
    expect(periods.map((p) => p.start), [
      DateTime(2023, 12, 4),
      DateTime(2023, 12, 11),
      DateTime(2023, 12, 18),
      DateTime(2023, 12, 25),
      jan(1),
      jan(8),
      jan(15),
    ]);
    expect(periods.map((p) => p.mark), [
      PeriodMark.missed,
      PeriodMark.missed,
      PeriodMark.missed,
      PeriodMark.missed,
      PeriodMark.done,
      PeriodMark.partial,
      PeriodMark.done,
    ]);
  });

  test('monthly habits show their last seven months', () {
    final h = habit(frequency: ResetFrequency.monthly, created: DateTime(2023, 1, 1));
    expect(recentPeriods(h, mondayNoon).map((p) => p.start).toList(),
        [for (var m = 7; m <= 13; m++) DateTime(2023, m, 1)]);
  });

  test('habits that never reset have no periods to show', () {
    expect(recentPeriods(habit(frequency: ResetFrequency.never), mondayNoon), isEmpty);
  });

  group('read out for VoiceOver', () {
    test('counts each kind over the tracked periods', () {
      final h = habit(history: {jan(9): 2, jan(10): 1, jan(13): 3}, twoMinuteDays: {jan(12)});
      expect(RecentPeriodsBar.describe(recentPeriods(h, mondayNoon), 'day'),
          'Last 7 days: 2 done, 1 two-minute, 1 partly done, 2 missed');
    });

    test('a habit with one period so far', () {
      final h = habit(frequency: ResetFrequency.weekly, created: jan(15), history: {jan(15): 2});
      expect(RecentPeriodsBar.describe(recentPeriods(h, mondayNoon), 'week'), 'This week: 1 done');
    });
  });
}
