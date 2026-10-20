import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/core/services/vacation_notice_service.dart';
import 'package:atomic_momentum/domain/services/vacation_notice_planner.dart';

class _FakeScheduler implements VacationNoticeScheduler {
  final scheduled = <PlannedVacationNotice>[];
  int cancels = 0;

  @override
  Future<void> cancelAll() async {
    cancels++;
    scheduled.clear();
  }

  @override
  Future<void> schedule(PlannedVacationNotice notice) async => scheduled.add(notice);
}

void main() {
  final now = DateTime(2026, 10, 5, 8);
  late _FakeScheduler scheduler;
  late bool enabled;
  late VacationNoticeService service;

  setUp(() {
    scheduler = _FakeScheduler();
    enabled = true;
    service = VacationNoticeService(
      scheduler: scheduler,
      enabled: () => enabled,
      time: () => const TimeOfDay(hour: 9, minute: 0),
      clock: () => now,
    );
  });

  test('schedules what the planner plans, and nothing while vacation mode is off', () async {
    await service.sync(VacationPlan(since: DateTime(2026, 10, 5)));
    expect(scheduler.scheduled, hasLength(VacationNoticePlanner.maxPending));
    await service.sync(null);
    expect(scheduler.scheduled, isEmpty);
  });

  test("doesn't reschedule when nothing changed; a full reload does", () async {
    final away = VacationPlan(since: DateTime(2026, 10, 5), back: DateTime(2026, 10, 9));
    await service.sync(away);
    await service.sync(away);
    expect(scheduler.cancels, 1);
    await service.sync(away, replace: true);
    expect(scheduler.cancels, 2);
    expect(scheduler.scheduled.single.kind, VacationNoticeKind.welcomeBack);
  });

  test('the switch off cancels them', () async {
    await service.sync(VacationPlan(since: DateTime(2026, 10, 5)));
    enabled = false;
    await service.sync(VacationPlan(since: DateTime(2026, 10, 5)));
    expect(scheduler.scheduled, isEmpty);
  });

  test('LocalNotificationVacationNoticeScheduler ids are stable per moment', () {
    final a = PlannedVacationNotice(kind: VacationNoticeKind.checkIn, at: DateTime(2026, 10, 8, 9), title: 't', body: 'b');
    final b = PlannedVacationNotice(kind: VacationNoticeKind.checkIn, at: DateTime(2026, 10, 11, 9), title: 't', body: 'b');
    expect(LocalNotificationVacationNoticeScheduler.noticeId(a), LocalNotificationVacationNoticeScheduler.noticeId(a));
    expect(LocalNotificationVacationNoticeScheduler.noticeId(a), isNot(LocalNotificationVacationNoticeScheduler.noticeId(b)));
  });
}
