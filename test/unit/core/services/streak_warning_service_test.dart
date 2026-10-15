import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/core/services/streak_warning_service.dart';
import 'package:atomic_momentum/domain/entities/streak_warning_settings.dart';
import '../../../helpers/fake_streak_warning_scheduler.dart';
import '../../../helpers/test_data.dart';

void main() {
  final noon = DateTime(2024, 1, 15, 12);
  late FakeStreakWarningScheduler scheduler;
  late StreakWarningSettings settings;
  late StreakWarningService service;

  setUp(() {
    scheduler = FakeStreakWarningScheduler();
    settings = StreakWarningSettings.defaults;
    service = StreakWarningService(
      scheduler: scheduler,
      readSettings: () => settings,
      clock: () => noon,
    );
  });

  final atRisk = TestData.createTestHabit(
    id: 'at_risk',
    target: 1,
    history: {DateTime(2024, 1, 14): 1},
  ).refresh(DateTime(2024, 1, 15, 12));

  test('schedules a warning for a habit with a streak at stake', () async {
    await service.sync(atRisk);
    expect(scheduler.scheduled['at_risk']!.at, DateTime(2024, 1, 15, 20));
  });

  test('cancels when there is nothing to warn about', () async {
    await service.sync(atRisk);
    await service.sync(atRisk.setProgressForDate(DateTime(2024, 1, 14), 0).refresh(noon));

    expect(scheduler.scheduled, isEmpty);
    expect(scheduler.cancelled, contains('at_risk'));
  });

  test('reads the current settings on every sync', () async {
    settings = const StreakWarningSettings(enabled: false, leadTime: Duration(hours: 4));
    await service.sync(atRisk);
    expect(scheduler.scheduled, isEmpty);

    settings = const StreakWarningSettings(enabled: true, leadTime: Duration(hours: 2));
    await service.sync(atRisk);
    expect(scheduler.scheduled['at_risk']!.at, DateTime(2024, 1, 15, 22));
  });

  test('syncAll handles every habit', () async {
    final other = TestData.createTestHabit(id: 'other', target: 1, history: {DateTime(2024, 1, 14): 1})
        .refresh(noon);
    await service.syncAll([atRisk, other]);

    expect(scheduler.scheduled.keys, containsAll(['at_risk', 'other']));
  });

  test('swallows scheduler failures so habit updates never break', () async {
    scheduler.throwOnSchedule = true;
    await expectLater(service.sync(atRisk), completes);
  });
}
