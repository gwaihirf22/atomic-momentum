import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/core/services/reminder_service.dart';
import 'package:atomic_momentum/domain/entities/reminder_settings.dart';
import 'package:atomic_momentum/domain/services/reminder_planner.dart';
import '../../../helpers/fake_reminder_scheduler.dart';
import '../../../helpers/test_data.dart';

void main() {
  final eightAm = DateTime(2026, 10, 12, 8);
  late FakeReminderScheduler scheduler;
  late ReminderService service;

  setUp(() {
    scheduler = FakeReminderScheduler();
    service = ReminderService(scheduler: scheduler, clock: () => eightAm);
  });

  final smart = ReminderSettings.smart(time: const TimeOfDay(hour: 9, minute: 0));

  test("schedules every habit's planned reminders, soonest first", () async {
    final a = TestData.createTestHabit(id: 'a', target: 1, reminder: smart);
    final b = TestData.createTestHabit(
            id: 'b', target: 1, reminder: smart.copyWith(time: const TimeOfDay(hour: 7, minute: 0)))
        .copyWith(resetAnchorDate: DateTime(2026, 10, 12));
    await service.syncAll([a, b]);

    expect(scheduler.forHabit('a'), hasLength(14));
    expect(scheduler.forHabit('b'), hasLength(13)); // today's 7:00 has passed
    expect(scheduler.scheduled.map((r) => r.at).toList(), [...scheduler.scheduled.map((r) => r.at)]..sort());
  });

  test('keeps only the soonest ${ReminderService.budget}, under the iOS limit', () async {
    final habits = [
      for (var i = 0; i < 6; i++) TestData.createTestHabit(id: 'h$i', target: 1, reminder: smart),
    ];
    await service.syncAll(habits);

    expect(scheduler.scheduled, hasLength(ReminderService.budget));
    final latest = scheduler.scheduled.map((r) => r.at).reduce((a, b) => a.isAfter(b) ? a : b);
    // 6 habits x 8 days = 48: the first 8 days, nothing later
    expect(latest, DateTime(2026, 10, 19, 9));
  });

  test('leaves room for streak warnings, so the total stays under iOS\'s 64', () async {
    final habits = [
      for (var i = 0; i < 12; i++) TestData.createTestHabit(id: 'h$i', target: 1, reminder: smart),
    ];
    final sharing = ReminderService(scheduler: scheduler, clock: () => eightAm, reservedFor: (h) => 2 * h.length);
    await sharing.syncAll(habits);

    // 64 - 4 spare - 24 warnings
    expect(scheduler.scheduled, hasLength(36));
    expect(sharing.roomFor(habits), 36);
    expect(ReminderService(scheduler: scheduler, reservedFor: (_) => 100).roomFor(habits), 0);
  });

  test('the first sync replaces everything (older versions\' reminders too); later ones change only what moved', () async {
    final habit = TestData.createTestHabit(id: 'a', target: 1, reminder: smart);
    await service.syncAll([habit]);
    expect(scheduler.cancelCount, 1);
    expect(scheduler.cancelledHabitIds, contains('a'));
    final first = List.of(scheduler.scheduled);
    expect(first, isNotEmpty);

    // The same again: nothing to do
    await service.syncAll([habit]);
    expect(scheduler.cancelCount, 1);
    expect(scheduler.scheduled, first);

    // Turned off: its reminders go, one by one
    await service.syncAll([habit.copyWith(reminder: smart.copyWith(enabled: false))]);
    expect(scheduler.cancelCount, 1);
    expect(scheduler.scheduled, isEmpty);

    // A full reload replaces everything again
    await service.syncAll([habit], replace: true);
    expect(scheduler.cancelCount, 2);
    expect(scheduler.scheduled, hasLength(first.length));
  });

  test('a new default sound reschedules everything', () async {
    final habit = TestData.createTestHabit(id: 'a', target: 1, reminder: smart);
    await service.syncAll([habit]);
    scheduler.detailsKey = 'another sound';
    await service.syncAll([habit]);
    expect(scheduler.cancelCount, 2);
  });

  test('reminder ids are stable for the same habit and moment, and differ otherwise', () {
    PlannedReminder at(String id, int day) =>
        PlannedReminder(habitId: id, at: DateTime(2026, 10, day, 9), title: 't', body: 'b');
    expect(LocalNotificationReminderScheduler.reminderId(at('a', 12)),
        LocalNotificationReminderScheduler.reminderId(at('a', 12)));
    expect(LocalNotificationReminderScheduler.reminderId(at('a', 12)),
        isNot(LocalNotificationReminderScheduler.reminderId(at('a', 13))));
    expect(LocalNotificationReminderScheduler.reminderId(at('a', 12)),
        isNot(LocalNotificationReminderScheduler.reminderId(at('b', 12))));
  });
}
