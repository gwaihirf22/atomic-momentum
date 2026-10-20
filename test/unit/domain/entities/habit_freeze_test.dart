import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/data/models/habit_model.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/habit_goal.dart';
import 'package:atomic_momentum/domain/entities/habit_pause.dart';
import 'package:atomic_momentum/domain/entities/reminder_settings.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/services/insights.dart';
import 'package:atomic_momentum/domain/services/recent_periods.dart';
import 'package:atomic_momentum/domain/services/reminder_planner.dart';
import 'package:flutter/material.dart' show TimeOfDay;

/// Freezes and vacation mode: a paused period is neither kept nor missed,
/// unless it was kept anyway.
void main() {
  DateTime oct(int d, [int hour = 20]) => DateTime(2026, 10, d, hour);
  DateTime day(int d) => DateTime(2026, 10, d);

  /// A daily habit created Oct 1, done on [done] days.
  Habit daily({Iterable<int> done = const [], HabitGoal goal = HabitGoal.build, int target = 1}) {
    var habit = withClock(Clock.fixed(oct(1, 8)), () => Habit.create(
          name: 'Read',
          target: target,
          color: HabitColor.blue,
          categoryId: BuiltInCategoryIds.mind,
          goal: goal,
        ));
    for (final d in done) {
      habit = withClock(Clock.fixed(oct(d)), () => habit.setProgressForDate(day(d), target == 0 ? 1 : target));
    }
    return habit;
  }

  T at<T>(DateTime now, T Function() body) => withClock(Clock.fixed(now), body);

  group('streaks', () {
    test('a frozen miss holds the streak: no +1, no miss, not at risk', () {
      var h = daily(done: [1, 2, 3, 4, 5]);
      h = at(oct(6, 9), () => h.freeze(day(6)));
      final streak = at(oct(7, 21), () => h.setProgressForDate(day(7), 1).refresh(oct(7, 21)).streak);
      expect(streak.current, 6, reason: '5 + Oct 7; the frozen 6th adds nothing');
      expect(streak.atRisk, isFalse);
    });

    test('without the freeze, the same miss leaves the streak at risk', () {
      final h = daily(done: [1, 2, 3, 4, 5]);
      final streak = at(oct(7, 9), () => h.refresh(oct(7, 9)).streak);
      expect(streak.current, 5);
      expect(streak.atRisk, isTrue);
    });

    test("a freeze in never-miss-twice's gap: a miss and then a frozen day don't end it", () {
      var h = daily(done: [1, 2, 3, 4, 5]);
      h = at(oct(7, 9), () => h.freeze(day(7)));
      final after = at(oct(8, 21), () => h.setProgressForDate(day(8), 1).refresh(oct(8, 21)).streak);
      expect(after.current, 6, reason: 'missed the 6th, froze the 7th, kept the 8th');

      final unfrozen = daily(done: [1, 2, 3, 4, 5, 8]);
      expect(at(oct(8, 21), () => unfrozen.refresh(oct(8, 21)).streak.current), 1, reason: 'two misses end it');
    });

    test('a freeze ahead covers tomorrow: no warning deadline there', () {
      var h = daily(done: [1, 2, 3, 4, 5, 6]);
      final before = at(oct(6, 21), () => h.streakDeadline(oct(6, 21)));
      h = at(oct(6, 21), () => h.freeze(day(7)));
      final after = at(oct(6, 21), () => h.streakDeadline(oct(6, 21)));
      expect(after!.isAfter(before!), isTrue, reason: 'the frozen 7th is skipped');
      expect(at(oct(6, 21), () => h.nextMissAt(oct(6, 21))), day(9), reason: 'the 8th is the next one that can be missed');
    });

    test('kept beats frozen: a frozen day that gets done counts, and its freeze is no longer needed', () {
      var h = daily(done: [1, 2, 3]);
      h = at(oct(4, 9), () => h.freeze(day(4)));
      expect(h.unneededFreezes(oct(4, 9)), isEmpty);
      h = at(oct(4, 20), () => h.setProgressForDate(day(4), 1));
      expect(h.streak.current, 4);
      expect(h.unneededFreezes(oct(4, 20)), [day(4)]);
    });

    test('a habit being broken: a slip on a frozen day is no miss; a clean frozen day gives its freeze back once over', () {
      var quit = daily(goal: HabitGoal.quit, target: 0);
      quit = at(oct(5, 9), () => quit.freeze(day(5)));
      quit = at(oct(5, 20), () => quit.setProgressForDate(day(5), 2));
      final streak = at(oct(6, 21), () => quit.refresh(oct(6, 21)).streak);
      expect(streak.atRisk, isFalse);
      expect(streak.current, greaterThanOrEqualTo(4), reason: 'Oct 1–4 and 6 clean, the slipped 5th skipped');

      var clean = daily(goal: HabitGoal.quit, target: 0);
      clean = at(oct(5, 9), () => clean.freeze(day(5)));
      expect(clean.unneededFreezes(oct(5, 20)), isEmpty, reason: 'still under way');
      expect(clean.unneededFreezes(oct(6, 9)), [day(5)]);
    });

    test('a weekly habit freezes its whole week', () {
      var weekly = withClock(Clock.fixed(DateTime(2026, 9, 7, 8)), () => Habit.create(
            name: 'Long run',
            target: 1,
            color: HabitColor.green,
            categoryId: BuiltInCategoryIds.body,
            resetFrequency: ResetFrequency.weekly,
          ));
      for (final d in [DateTime(2026, 9, 8), DateTime(2026, 9, 15), DateTime(2026, 9, 22)]) {
        weekly = at(d, () => weekly.setProgressForDate(d, 1));
      }
      weekly = at(DateTime(2026, 9, 30), () => weekly.freeze(DateTime(2026, 9, 30)));
      expect(weekly.isFrozenOn(DateTime(2026, 9, 28)), isTrue, reason: 'the same week');
      final streak = at(DateTime(2026, 10, 7, 9), () => weekly.refresh(DateTime(2026, 10, 7, 9)).streak);
      expect(streak.current, 3);
      expect(streak.atRisk, isFalse);
    });
  });

  test('momentum holds exactly on a frozen day', () {
    var h = daily(done: [for (var d = 1; d <= 10; d++) d]);
    h = at(oct(11, 9), () => h.freeze(day(11)));
    final before = h.momentumAt(DateTime(2026, 10, 10, 23, 59)).score;
    final after = h.momentumAt(DateTime(2026, 10, 11, 23, 59)).score;
    expect(after, closeTo(before, 1e-9));
    final series = h.momentumSeries([DateTime(2026, 10, 10, 23, 59), DateTime(2026, 10, 12, 0, 1)]);
    expect(series[1], closeTo(series[0], 1e-9), reason: 'the 11th, over, skipped');
  });

  group('where a freeze can go', () {
    final h = daily(done: [1, 2]);
    final now = oct(20, 12);

    test('a week back to a month ahead, on days not kept, after the habit began', () {
      expect(h.whyNoFreeze(day(19), now), isNull);
      expect(h.whyNoFreeze(day(13), now), isNull, reason: '7 days back');
      expect(h.whyNoFreeze(day(12), now), contains('week'));
      expect(h.whyNoFreeze(DateTime(2026, 11, 19), now), isNull);
      expect(h.whyNoFreeze(DateTime(2026, 11, 20), now), contains('month'));
      expect(h.whyNoFreeze(DateTime(2026, 9, 30), now), isNotNull);
    });

    test('not twice, and not on a kept day', () {
      final frozen = at(now, () => h.freeze(day(20)));
      expect(frozen.whyNoFreeze(day(20), now), 'Already frozen');
      final kept = daily(done: [1, 2, 20]);
      expect(kept.whyNoFreeze(day(20), now), contains('kept'));
      expect(() => at(now, () => kept.freeze(day(20))), throwsArgumentError);
    });

    test('unfreezing takes it off; one freeze per period', () {
      final frozen = at(now, () => h.freeze(day(20)));
      expect(frozen.frozenDays, {day(20)});
      expect(at(now, () => frozen.unfreeze(day(20))).frozenDays, isEmpty);
    });
  });

  group('vacation mode', () {
    test('pauses every day it covers: the streak holds across it', () {
      var h = daily(done: [1, 2, 3, 4, 5]);
      h = at(oct(6, 9), () => h.startPause(day(6)));
      expect(h.isOnVacation, isTrue);
      h = at(oct(12, 9), () => h.endPause(day(12)));
      expect(h.isOnVacation, isFalse);
      expect(h.pauses.single, HabitPause(from: day(6), to: day(12)));
      final streak = at(oct(13, 21), () => h.setProgressForDate(day(13), 1).refresh(oct(13, 21)).streak);
      expect(streak.current, 6);
      expect(streak.atRisk, isFalse);
    });

    test('no reminders while on vacation or on a frozen day', () {
      var h = daily(done: [1, 2]).copyWith(reminder: ReminderSettings.smart(time: const TimeOfDay(hour: 18, minute: 0)));
      final now = oct(10, 9);
      expect(ReminderPlanner.plan(h, now: now).map((r) => r.at.day), contains(10));
      h = at(now, () => h.freeze(day(10)));
      expect(ReminderPlanner.plan(h, now: now).map((r) => r.at.day), isNot(contains(10)));
      h = at(now, () => h.startPause(day(10)));
      expect(ReminderPlanner.plan(h, now: now), isEmpty);
    });

    test('with a return date: on until that morning, then it ends by itself', () {
      var h = daily(done: [1, 2, 3, 4, 5]);
      h = at(oct(6, 9), () => h.startPause(day(6), back: day(10)));
      expect(h.pauses.single, HabitPause(from: day(6), back: day(10)));
      expect(at(oct(9, 23), () => h.isOnVacation), isTrue);
      expect(at(oct(9, 23), () => h.vacationBack), day(10));
      expect(at(oct(9, 23), () => h.isOnOpenVacation), isFalse);
      expect(at(oct(10, 0), () => h.isOnVacation), isFalse, reason: 'back on the 10th, without the app');
      expect(at(oct(10, 9), () => h.isOnVacationOn(day(9))), isTrue);
      expect(at(oct(10, 9), () => h.isOnVacationOn(day(10))), isFalse);
      // Kept from the day back: the streak runs through the days away
      final streak = at(oct(10, 21), () => h.setProgressForDate(day(10), 1).refresh(oct(10, 21)).streak);
      expect(streak.current, 6);
      expect(streak.atRisk, isFalse);
    });

    test('with a return date, reminders are planned from that day', () {
      var h = daily(done: [1, 2]).copyWith(reminder: ReminderSettings.smart(time: const TimeOfDay(hour: 18, minute: 0)));
      final now = oct(6, 9);
      h = at(now, () => h.startPause(day(6), back: day(9)));
      final days = at(now, () => ReminderPlanner.plan(h, now: now)).map((r) => r.at.day);
      expect(days.first, 9, reason: 'nothing on the 6th, 7th or 8th');
      h = at(now, () => h.planReturn(null));
      expect(h.isOnOpenVacation, isTrue);
      expect(at(now, () => ReminderPlanner.plan(h, now: now)), isEmpty, reason: 'no return date: nothing planned');
    });

    test('the return date moves, and ending early wins over it', () {
      var h = daily();
      h = at(oct(6, 9), () => h.startPause(day(6), back: day(20)));
      h = at(oct(7, 9), () => h.planReturn(day(12)));
      expect(h.pauses.single, HabitPause(from: day(6), back: day(12)));
      h = at(oct(8, 9), () => h.endPause(day(8)));
      expect(h.pauses.single, HabitPause(from: day(6), to: day(8)), reason: 'today stays paused; the date is gone');
      expect(at(oct(8, 10), () => h.isOnVacation), isFalse);
      expect(at(oct(8, 10), () => h.planReturn(day(15))), same(h), reason: 'not on vacation: nothing to move');
    });

    test("a pause's last day: to, the day before back, or none while open", () {
      expect(HabitPause(from: day(6), to: day(8)).lastDay, day(8));
      expect(HabitPause(from: day(6), back: day(10)).lastDay, day(9));
      expect(HabitPause(from: day(6)).lastDay, isNull);
      expect(HabitPause(from: day(6), back: day(10)).covers(day(10)), isFalse);
      expect(HabitPause(from: day(6), back: day(10)).isOpen, isFalse, reason: 'its end is decided');
      expect(HabitPause(from: day(6), back: day(10)).closedOn(day(15)), HabitPause(from: day(6), to: day(9)),
          reason: 'never past the return');
      expect(HabitPause(from: day(6), to: day(8), back: day(12)).back, isNull, reason: 'ended: no return to plan');
    });
  });

  test('frozen days show as frozen, and leave the heatmap\'s due count', () {
    var h = daily(done: [1, 2, 3]);
    h = at(oct(4, 9), () => h.freeze(day(4)));
    final marks = at(oct(5, 9), () => recentPeriods(h, oct(5, 9), count: 3));
    expect(marks.map((p) => p.mark), [PeriodMark.done, PeriodMark.frozen, PeriodMark.current]);
    final days = Insights.days([h], from: day(4), to: day(4), now: oct(5, 9));
    expect(days.single.due, 0);
    expect(days.single.frozen, 1);
  });

  test('frozen days and pauses survive storage; older saves have none', () {
    var h = daily(done: [1]);
    h = at(oct(2, 9), () => h.freeze(day(2)));
    h = at(oct(3, 9), () => h.startPause(day(3), back: day(9)));
    final json = jsonDecode(jsonEncode(HabitModel.fromDomain(h).toJson())) as Map<String, dynamic>;
    expect(json['frozen'], ['2026-10-02']);
    expect(json['pauses'], [
      {'from': '2026-10-03', 'back': '2026-10-09'}
    ]);
    final back = HabitModel.fromJson(json).toDomain();
    expect(back.frozenDays, {day(2)});
    expect(back.pauses, [HabitPause(from: day(3), back: day(9))]);

    json.remove('frozen');
    json.remove('pauses');
    final old = HabitModel.fromJson(json).toDomain();
    expect(old.frozenDays, isEmpty);
    expect(old.pauses, isEmpty);
    expect(Habit.fromJson(h.toJson()).frozenDays, {day(2)});
  });
}
