import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/core/services/notification_service.dart';
import 'package:atomic_momentum/core/services/weekly_review_service.dart';
import 'package:atomic_momentum/domain/services/weekly_review_planner.dart';

class _FakeScheduler implements WeeklyReviewScheduler {
  final scheduled = <PlannedWeeklyReview>[];
  int cancels = 0;

  @override
  Future<void> cancelAll() async {
    cancels++;
    scheduled.clear();
  }

  @override
  Future<void> schedule(PlannedWeeklyReview review) async => scheduled.add(review);
}

void main() {
  final now = DateTime(2026, 10, 14, 9);
  final since = DateTime(2026, 9, 1);
  late _FakeScheduler scheduler;
  late bool enabled;
  late TimeOfDay time;
  late WeeklyReviewService service;

  setUp(() {
    scheduler = _FakeScheduler();
    enabled = true;
    time = const TimeOfDay(hour: 18, minute: 0);
    service = WeeklyReviewService(
      scheduler: scheduler,
      enabled: () => enabled,
      time: () => time,
      weekStart: () => DateTime.monday,
      clock: () => now,
    );
  });

  test('schedules what the planner plans; nothing with the switch off', () async {
    await service.sync((trackedSince: since, vacation: null));
    expect(scheduler.scheduled.map((r) => r.at), [DateTime(2026, 10, 18, 18), DateTime(2026, 10, 25, 18)]);
    enabled = false;
    await service.sync((trackedSince: since, vacation: null));
    expect(scheduler.scheduled, isEmpty);
  });

  test("leaves them alone when nothing changed; a new time replaces them", () async {
    await service.sync((trackedSince: since, vacation: null));
    await service.sync((trackedSince: since, vacation: null));
    expect(scheduler.cancels, 1);
    time = const TimeOfDay(hour: 20, minute: 30);
    await service.sync((trackedSince: since, vacation: null));
    expect(scheduler.cancels, 2);
    expect(scheduler.scheduled.first.at, DateTime(2026, 10, 18, 20, 30));
  });

  test('a stable id for each moment', () {
    final review = PlannedWeeklyReview(DateTime(2026, 10, 18, 18));
    expect(LocalNotificationWeeklyReviewScheduler.reviewId(review),
        LocalNotificationWeeklyReviewScheduler.reviewId(PlannedWeeklyReview(DateTime(2026, 10, 18, 18))));
    expect(LocalNotificationWeeklyReviewScheduler.reviewId(review),
        isNot(LocalNotificationWeeklyReviewScheduler.reviewId(PlannedWeeklyReview(DateTime(2026, 10, 25, 18)))));
  });

  test("a tap asks for the review, never a habit; it isn't a streak warning", () {
    final before = NotificationService.weeklyReviewRequests.value;
    NotificationService.focusRequests.value = null;
    NotificationService.handleResponse(null, NotificationService.weeklyReviewPayload);
    expect(NotificationService.weeklyReviewRequests.value, before + 1);
    expect(NotificationService.focusRequests.value, isNull);
    expect(NotificationService.habitIdFromPayload(NotificationService.weeklyReviewPayload), isNull);
    expect(NotificationService.weeklyReviewDetails().android!.channelId, 'weekly_review');
  });
}
