import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/quiet_hours.dart';
import 'package:atomic_momentum/domain/services/vacation_notice_planner.dart';

/// Vacation mode's notifications: a welcome back on the return date, or
/// check-ins every 3 days easing to weekly without one.
void main() {
  DateTime oct(int d, [int hour = 0, int minute = 0]) => DateTime(2026, 10, d, hour, minute);

  List<PlannedVacationNotice> plan(VacationPlan vacation, DateTime now, {QuietHours quiet = QuietHours.off}) =>
      VacationNoticePlanner.plan(vacation, now: now, hour: 9, minute: 0, quiet: quiet);

  test('with a return date: only a welcome back, that morning', () {
    final notices = plan(VacationPlan(since: oct(5), back: oct(12)), oct(5, 8));
    expect(notices, [
      PlannedVacationNotice(
        kind: VacationNoticeKind.welcomeBack,
        at: oct(12, 9),
        title: VacationNoticePlanner.welcomeTitle,
        body: VacationNoticePlanner.welcomeBody,
      ),
    ]);
  });

  test('the welcome back is still planned early on the return day, not after it', () {
    expect(plan(VacationPlan(since: oct(5), back: oct(12)), oct(12, 7)), hasLength(1));
    expect(plan(VacationPlan(since: oct(5), back: oct(12)), oct(12, 9, 1)), isEmpty);
  });

  test('without one: every 3 days for two weeks, then weekly', () {
    expect([for (var n = 0; n < 7; n++) VacationNoticePlanner.checkInDay(n)], [3, 6, 9, 12, 19, 26, 33]);
    final notices = plan(VacationPlan(since: oct(5)), oct(5, 8));
    expect(notices.map((n) => n.at), [oct(8, 9), oct(11, 9), oct(14, 9), oct(17, 9)]);
    expect(notices.every((n) => n.kind == VacationNoticeKind.checkIn), isTrue);
    expect(notices, hasLength(VacationNoticePlanner.maxPending));
  });

  test('later on, the next ones roll forward (weekly after two weeks)', () {
    final notices = plan(VacationPlan(since: oct(1)), oct(14, 10));
    expect(notices.map((n) => n.at), [oct(20, 9), oct(27, 9), DateTime(2026, 11, 3, 9), DateTime(2026, 11, 10, 9)]);
  });

  test('check-ins take turns through their wording', () {
    final notices = plan(VacationPlan(since: oct(5)), oct(5, 8));
    expect(notices.map((n) => n.title).toSet(), hasLength(VacationNoticePlanner.checkIns.length));
  });

  test('quiet hours move them, the way reminders move', () {
    const quiet = QuietHours(enabled: true, start: TimeOfDay(hour: 22, minute: 0), end: TimeOfDay(hour: 10, minute: 0));
    final notices = plan(VacationPlan(since: oct(5), back: oct(8)), oct(5, 8), quiet: quiet);
    expect(notices.single.at, oct(8, 10));
  });
}
