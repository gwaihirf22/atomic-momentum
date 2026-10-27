import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/services/health_source.dart';
import 'package:atomic_momentum/core/services/health_sync_service.dart';
import 'package:atomic_momentum/core/services/health_watch.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/health_link.dart';

/// What the unit tests can't prove: that the real store (Apple Health on a
/// simulator, Health Connect on an emulator) holds, reads back and deletes
/// what the app expects. It writes real samples into quiet hours
/// (02:00–03:00 and a nap at 14:00 yesterday), checks every metric reads back exactly as the
/// app's rules say (a workout two apps recorded counts once; a nap counts
/// toward its day), checks the app's + and − write and delete real
/// water and mindful samples, then deletes its own samples in that hour and
/// checks Health is back where it started. What else is in Health is never
/// touched (the stores only let the app delete what it wrote).
///
/// Run with tool/device_health_check.sh "<simulator or emulator>". The first
/// time on an iPhone simulator, tap Allow on Health's sheet (tests can't
/// tap system sheets); the script grants Android's permissions itself.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final android = Platform.isAndroid;

  testWidgets('the real health store reads, writes and deletes as the app expects', (tester) async {
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final source = PluginHealthSource();
      final plugin = Health();
      await plugin.configure();
      expect(await source.availability(), HealthAvailability.available,
          reason: android ? 'Install or update Health Connect on this emulator' : 'HealthKit unavailable');

      final metrics = {
        HealthMetric.steps,
        HealthMetric.exerciseMinutes,
        HealthMetric.workouts,
        HealthMetric.sleepHours,
        HealthMetric.water,
        if (!android) HealthMetric.mindfulMinutes,
      };
      // The sample types the test writes itself
      final sampleTypes = [
        HealthDataType.STEPS,
        HealthDataType.WORKOUT,
        HealthDataType.SLEEP_ASLEEP,
        if (!android) HealthDataType.MINDFULNESS,
        HealthDataType.WATER,
      ];
      if (android) {
        // Health Connect's screen can't be tapped here: the script grants it all
        expect(await source.ensureAccess(read: metrics, write: {HealthMetric.water}), isTrue,
            reason: 'Run tool/device_health_check.sh, which grants the permissions');
        expect(await plugin.hasPermissions(sampleTypes, permissions: [for (final _ in sampleTypes) HealthDataAccess.READ_WRITE]),
            isTrue, reason: 'writing the test samples needs a debug build (src/debug/AndroidManifest.xml)');
      } else {
        // The first time, tap Allow on the sheet
        await source.requestAccess(read: metrics, write: {HealthMetric.water, HealthMetric.mindfulMinutes});
        await plugin.requestAuthorization(sampleTypes, permissions: [for (final _ in sampleTypes) HealthDataAccess.READ_WRITE]);
      }

      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      DateTime at(int hour, [int minute = 0]) => DateTime(yesterday.year, yesterday.month, yesterday.day, hour, minute);
      final from = at(2), to = at(3);

      Future<Map<HealthMetric, int>> read() async => {
            for (final m in metrics) m: (await source.dailyValues(m, yesterday, yesterday))[yesterday] ?? 0,
          };

      // Sleep goes in an afternoon nap (it counts toward that day until
      // 6 PM): a night's sleep already in Health would overlap 2 AM
      final napFrom = at(14), napTo = at(15);

      Future<void> cleanUp() async {
        for (final type in sampleTypes) {
          await plugin.delete(type: type, startTime: from, endTime: to);
        }
        await plugin.delete(type: HealthDataType.SLEEP_ASLEEP, startTime: napFrom, endTime: napTo);
      }

      // Start clean (an earlier run stopped half way leaves samples here)
      await cleanUp();
      final before = await read();
      final asleep = await plugin.getHealthDataFromTypes(types: [HealthDataType.SLEEP_ASLEEP], startTime: napFrom, endTime: napTo);
      expect(asleep, isEmpty, reason: 'Health already has sleep at 2–3 PM yesterday; the test needs that hour free');

      // iPhone: Health says when steps change (HealthWatch.swift), which is
      // how the app follows Health while it's open. It may say so once as
      // the watch starts; a write has to make it say so again
      var heard = 0;
      final watch = PlatformHealthWatch();
      if (!android) {
        await watch.watch({HealthMetric.steps}, () => heard++);
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      final heardBefore = heard;

      // Steps; a nap (sleep counts toward the day until 6 PM);
      // a run, and the copy another app keeps of it; mindful minutes
      expect(await plugin.writeHealthData(value: 1234, type: HealthDataType.STEPS, startTime: at(2, 0), endTime: at(2, 20)), isTrue);
      if (!android) {
        for (var i = 0; i < 50 && heard == heardBefore; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        expect(heard, greaterThan(heardBefore), reason: 'Health said steps changed');
        await watch.watch({}, () {});
      }
      expect(await plugin.writeHealthData(value: 0, type: HealthDataType.SLEEP_ASLEEP, startTime: at(14, 0), endTime: at(14, 50)), isTrue);
      expect(await plugin.writeWorkoutData(activityType: HealthWorkoutActivityType.RUNNING, start: at(2, 10), end: at(2, 40), title: 'Test run'), isTrue);
      expect(await plugin.writeWorkoutData(activityType: HealthWorkoutActivityType.RUNNING, start: at(2, 11), end: at(2, 39), title: 'Test run copy'), isTrue);

      final after = await read();
      if (android) {
        // Health Connect's total (what the app reads, and what its own app
        // shows) counts only apps on its steps priority list, which the
        // shell's grant doesn't add this one to: check the record is there and
        // that the app reads exactly Health Connect's total
        final records = await plugin.getHealthDataFromTypes(types: [HealthDataType.STEPS], startTime: from, endTime: to);
        expect([for (final p in records) (p.value as NumericHealthValue).numericValue.round()], [1234], reason: 'the steps record');
        final day = DateTime(yesterday.year, yesterday.month, yesterday.day + 1);
        expect(after[HealthMetric.steps], await plugin.getTotalStepsInInterval(yesterday, day), reason: 'Health Connect\'s steps total');
      } else {
        expect(after[HealthMetric.steps]! - before[HealthMetric.steps]!, 1234, reason: 'steps');
      }
      expect(after[HealthMetric.sleepHours]! - before[HealthMetric.sleepHours]!, 50, reason: 'sleep minutes');
      expect(after[HealthMetric.workouts]! - before[HealthMetric.workouts]!, 1, reason: 'a run two apps recorded counts once');
      expect(after[HealthMetric.exerciseMinutes]! - before[HealthMetric.exerciseMinutes]!, greaterThanOrEqualTo(29),
          reason: 'exercise: the run\'s minutes, once');

      // The app's own writes: water (a second-long sample) and mindful
      // minutes, and taking them back
      final water = await source.log(HealthMetric.water, 500, at(2, 30));
      expect(water, isNotNull, reason: 'writing water');
      final mindful = android ? null : await source.log(HealthMetric.mindfulMinutes, 10, at(2, 55));
      if (!android) expect(mindful, isNotNull, reason: 'writing mindful minutes');
      final logged = await read();
      expect(logged[HealthMetric.water]! - after[HealthMetric.water]!, 500, reason: 'water in ml');
      if (!android) expect(logged[HealthMetric.mindfulMinutes]! - after[HealthMetric.mindfulMinutes]!, 10);

      expect(await source.remove(water!), isTrue, reason: 'taking water back');
      if (mindful != null) expect(await source.remove(mindful), isTrue, reason: 'taking mindful minutes back');
      final taken = await read();
      expect(taken[HealthMetric.water], after[HealthMetric.water], reason: 'water back to what it was');
      if (!android) expect(taken[HealthMetric.mindfulMinutes], after[HealthMetric.mindfulMinutes]);

      // The app's bookkeeping, end to end, on today: + writes, − takes back
      final sync = HealthSyncService(source: () => source, prefs: prefs);
      final today = DateTime(now.year, now.month, now.day);
      final habit = Habit.create(name: 'Water', target: 8, units: 'glasses', color: HabitColor.blue, categoryId: BuiltInCategoryIds.body)
          .copyWith(health: HealthLink(metric: HealthMetric.water, logToHealth: true, linkedOn: today));
      final todayBefore = (await source.dailyValues(HealthMetric.water, today, today))[today] ?? 0;
      final two = habit.copyWith(history: {today: 2});
      expect(await sync.logChange(habit, two), isNull);
      expect(((await source.dailyValues(HealthMetric.water, today, today))[today] ?? 0) - todayBefore, 500);
      expect(await sync.logChange(two, habit), isNull, reason: 'took back its own 500 ml');
      expect((await source.dailyValues(HealthMetric.water, today, today))[today] ?? 0, todayBefore);

      await cleanUp();
      final end = await read();
      expect(end, before, reason: 'Health is back where it started');
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}
