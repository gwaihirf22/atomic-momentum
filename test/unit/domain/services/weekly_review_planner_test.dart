import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/quiet_hours.dart';
import 'package:atomic_momentum/domain/services/vacation_notice_planner.dart';
import 'package:atomic_momentum/domain/services/weekly_review_planner.dart';

void main() {
  // Wednesday, October 14, 2026; tracked since September
  final now = DateTime(2026, 10, 14, 9);
  final since = DateTime(2026, 9, 1);

  List<DateTime> plan({
    DateTime? at,
    int weekStart = DateTime.monday,
    DateTime? trackedSince,
    VacationPlan? vacation,
    QuietHours quiet = QuietHours.off,
    bool noHabits = false,
  }) =>
      [
        for (final p in WeeklyReviewPlanner.plan(
          now: at ?? now,
          weekStart: weekStart,
          hour: 18,
          minute: 0,
          trackedSince: noHabits ? null : trackedSince ?? since,
          vacation: vacation,
          quiet: quiet,
        ))
          p.at,
      ];

  test("on each week's last day at the review time, the next two", () {
    expect(plan(), [DateTime(2026, 10, 18, 18), DateTime(2026, 10, 25, 18)]);
    // Weeks starting Sunday end on Saturday
    expect(plan(weekStart: DateTime.sunday), [DateTime(2026, 10, 17, 18), DateTime(2026, 10, 24, 18)]);
  });

  test("on the last day, once it's past the time, the next week's", () {
    expect(plan(at: DateTime(2026, 10, 18, 18, 1)).first, DateTime(2026, 10, 25, 18));
    expect(plan(at: DateTime(2026, 10, 18, 17, 59)).first, DateTime(2026, 10, 18, 18));
  });

  test('none without habits, nor for a week with too little tracked to review', () {
    expect(plan(noHabits: true), isEmpty);
    // Tracked from Saturday: this Sunday's week has two days; next week's comes
    expect(plan(trackedSince: DateTime(2026, 10, 17)), [DateTime(2026, 10, 25, 18), DateTime(2026, 11, 1, 18)]);
  });

  test('none for weeks on vacation', () {
    expect(plan(vacation: VacationPlan(since: DateTime(2026, 10, 12))), isEmpty);
    expect(plan(vacation: VacationPlan(since: DateTime(2026, 10, 12), back: DateTime(2026, 10, 20))),
        [DateTime(2026, 10, 25, 18), DateTime(2026, 11, 1, 18)]);
  });

  test('moved out of quiet hours, the same day', () {
    const late = QuietHours(enabled: true, start: TimeOfDay(hour: 17, minute: 0), end: TimeOfDay(hour: 7, minute: 0));
    expect(plan(quiet: late).first, DateTime(2026, 10, 18, 16, 45));
  });
}
