import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/habit_metadata.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/entities/streak_data.dart';

/// Setting several days at once: what holding a done habit's ring (clear)
/// and its Undo use.
void main() {
  // Wednesday 2024-01-17; weeks anchored on Monday the 15th
  DateTime jan(int day) => DateTime(2024, 1, day);
  final wednesdayNoon = DateTime(2024, 1, 17, 12);

  Habit weekly(Map<DateTime, int> history) => Habit(
        id: 'h',
        name: 'Swim',
        progress: 0,
        target: 3,
        color: HabitColor.teal,
        categoryId: BuiltInCategoryIds.body,
        lastUpdatedDate: wednesdayNoon,
        resetFrequency: ResetFrequency.weekly,
        history: history,
        streak: StreakData.empty(),
        metadata: HabitMetadata(createdDate: jan(1), lastModifiedDate: jan(1), version: 1, customFields: const {}),
        resetAnchorDate: jan(15),
      );

  T at<T>(T Function() body) => withClock(Clock.fixed(wednesdayNoon), body);

  test("the period's days run from its start to today, with 0 for empty days", () {
    final habit = weekly({jan(14): 1, jan(15): 1, jan(17): 2});
    expect(at(() => habit.periodDays(wednesdayNoon)), {jan(15): 1, jan(16): 0, jan(17): 2});
  });

  test('clearing the period empties every day of it, and only it', () {
    final habit = weekly({jan(14): 1, jan(15): 1, jan(17): 2});
    final days = at(() => habit.periodDays(wednesdayNoon));
    final cleared = at(() => habit.setDays({for (final d in days.keys) d: 0}));
    expect(at(() => cleared.progressForPeriodContaining(wednesdayNoon)), 0);
    expect(cleared.history, {jan(14): 1}, reason: 'last week is untouched');
    expect(cleared.progress, 0);

    final restored = at(() => cleared.setDays(days));
    expect(restored.history, {jan(14): 1, jan(15): 1, jan(17): 2});
    expect(restored.progress, 3);
    expect(restored.isCompleted, isTrue);
  });

  test('a period can go past its target, but not past ten times it, nor into the future', () {
    final habit = weekly({jan(15): 2});
    expect(at(() => habit.setDays({jan(16): 2})).progress, 4);
    expect(() => at(() => habit.setDays({jan(16): 29})), throwsArgumentError);
    expect(() => at(() => habit.setDays({jan(18): 1})), throwsArgumentError);
    expect(() => at(() => habit.setDays({jan(16): -1})), throwsArgumentError);
  });
}
