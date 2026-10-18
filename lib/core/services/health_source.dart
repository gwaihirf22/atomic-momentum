import 'dart:io' show Platform;
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:health/health.dart';
import '../../domain/entities/health_link.dart';
import '../../domain/services/health_days.dart';
import '../logging/log.dart';

/// Whether this phone can share health data with the app.
enum HealthAvailability {
  available,

  /// Android without the Health Connect app (or an out-of-date one).
  needsHealthConnect,

  /// No health store here (web, desktop, an old Android).
  unsupported,
}

/// What the app wrote to Health, so it can take it back.
typedef HealthRecord = ({HealthMetric metric, DateTime start, DateTime end});

/// The phone's health store: Apple Health on iPhone, Health Connect on
/// Android. Tests use a fake (test/helpers/fake_health_source.dart).
abstract class HealthSource {
  /// "Apple Health" or "Health Connect".
  String get name;

  bool get isAndroid;

  Future<HealthAvailability> availability();

  /// Asks to read [read] and write [write]. Apple never says whether reading
  /// was allowed (a refusal just reads as nothing), so true means "asked".
  Future<bool> requestAccess({required Set<HealthMetric> read, Set<HealthMetric> write = const {}});

  /// Opens the store to install Health Connect (Android).
  Future<void> installHealthConnect();

  /// [metric] for each day from [from] to [to] (date-only), in its base
  /// unit: steps, workouts, minutes (exercise, sleep, mindful) or ml (water).
  /// The habit's own unit converts it (HealthUnit.fromBase).
  Future<Map<DateTime, int>> dailyValues(HealthMetric metric, DateTime from, DateTime to);

  /// Logs [baseAmount] (ml of water, minutes of mindfulness) of a writable
  /// metric ending at [at]; null if it failed.
  Future<HealthRecord?> log(HealthMetric metric, double baseAmount, DateTime at);

  /// Takes back something [log] wrote.
  Future<bool> remove(HealthRecord record);

  /// Development only: writes a day or two of realistic data (a run,
  /// steps, sleep, mindful minutes, water), since a simulator can't record
  /// any. False if it couldn't.
  Future<bool> addSampleData();
}

/// The real store, through package:health.
class PluginHealthSource implements HealthSource {
  final Health _health;
  bool _configured = false;

  PluginHealthSource([Health? health]) : _health = health ?? Health();

  @override
  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  @override
  String get name => isAndroid ? 'Health Connect' : 'Apple Health';

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  static List<HealthDataType> _readTypes(HealthMetric metric, {required bool android}) => switch (metric) {
        HealthMetric.steps => [HealthDataType.STEPS],
        // On iPhone, Exercise minutes come only from an Apple Watch; workouts
        // logged by any app (Strava, Nike Run Club) count too
        HealthMetric.exerciseMinutes => [if (!android) HealthDataType.EXERCISE_TIME, HealthDataType.WORKOUT],
        HealthMetric.workouts => [HealthDataType.WORKOUT],
        HealthMetric.sleepHours => [
            HealthDataType.SLEEP_ASLEEP,
            HealthDataType.SLEEP_LIGHT,
            HealthDataType.SLEEP_DEEP,
            HealthDataType.SLEEP_REM,
          ],
        HealthMetric.mindfulMinutes => [HealthDataType.MINDFULNESS],
        HealthMetric.water => [HealthDataType.WATER],
      };

  static HealthDataType _writeType(HealthMetric metric) =>
      metric == HealthMetric.water ? HealthDataType.WATER : HealthDataType.MINDFULNESS;

  @override
  Future<HealthAvailability> availability() async {
    if (kIsWeb || !(Platform.isIOS || Platform.isAndroid)) return HealthAvailability.unsupported;
    if (!isAndroid) return HealthAvailability.available;
    try {
      await _configure();
      final status = await _health.getHealthConnectSdkStatus();
      return status == HealthConnectSdkStatus.sdkAvailable
          ? HealthAvailability.available
          : HealthAvailability.needsHealthConnect;
    } catch (e) {
      logWarning('Health: could not check Health Connect: $e');
      return HealthAvailability.unsupported;
    }
  }

  @override
  Future<bool> requestAccess({required Set<HealthMetric> read, Set<HealthMetric> write = const {}}) async {
    try {
      await _configure();
      final types = <HealthDataType>[];
      final access = <HealthDataAccess>[];
      for (final metric in read) {
        for (final type in _readTypes(metric, android: isAndroid)) {
          final writes = write.contains(metric) && type == _writeType(metric);
          types.add(type);
          access.add(writes ? HealthDataAccess.READ_WRITE : HealthDataAccess.READ);
        }
      }
      if (types.isEmpty) return true;
      return await _health.requestAuthorization(types, permissions: access);
    } catch (e) {
      logWarning('Health: could not ask for access: $e');
      return false;
    }
  }

  @override
  Future<void> installHealthConnect() => _health.installHealthConnect();

  @override
  Future<Map<DateTime, int>> dailyValues(HealthMetric metric, DateTime from, DateTime to) async {
    final first = DateTime(from.year, from.month, from.day);
    final last = DateTime(to.year, to.month, to.day);
    final end = DateTime(last.year, last.month, last.day + 1);
    try {
      await _configure();
      if (metric == HealthMetric.steps) {
        return {
          for (var day = first; day.isBefore(end); day = DateTime(day.year, day.month, day.day + 1))
            day: await _health.getTotalStepsInInterval(day, DateTime(day.year, day.month, day.day + 1)) ?? 0,
        };
      }
      // Sleep counts toward the morning you wake, so starts the evening before
      final start = metric == HealthMetric.sleepHours ? DateTime(first.year, first.month, first.day - 1, 18) : first;
      final points = await _health.getHealthDataFromTypes(
        types: _readTypes(metric, android: isAndroid),
        startTime: start,
        endTime: end,
      );
      final spans = [for (final p in points) (start: p.dateFrom, end: p.dateTo)];
      return switch (metric) {
        HealthMetric.steps => const {},
        HealthMetric.exerciseMinutes => HealthDays.exerciseMinutesByDay(
            exercise: [for (final p in points) if (p.type == HealthDataType.EXERCISE_TIME) (start: p.dateFrom, end: p.dateTo)],
            workouts: [for (final p in points) if (p.type == HealthDataType.WORKOUT) (start: p.dateFrom, end: p.dateTo)],
            from: first,
            to: last,
          ),
        HealthMetric.mindfulMinutes => HealthDays.minutesByDay(spans, first, last),
        HealthMetric.sleepHours => HealthDays.sleepMinutesByDay(spans, first, last),
        HealthMetric.workouts => HealthDays.countByStartDay(points.map((p) => p.dateFrom), first, last),
        HealthMetric.water => HealthDays.waterMlByDay([
            for (final p in points)
              if (p.value case NumericHealthValue(:final numericValue)) (at: p.dateFrom, liters: numericValue.toDouble()),
          ], first, last),
      };
    } catch (e) {
      logWarning('Health: could not read ${metric.name}: $e');
      return const {};
    }
  }

  @override
  Future<HealthRecord?> log(HealthMetric metric, double baseAmount, DateTime at) async {
    if (!metric.writable || baseAmount <= 0) return null;
    // Water: an instant; mindful minutes: a session ending now
    final start =
        metric == HealthMetric.water ? at : at.subtract(Duration(seconds: (baseAmount * 60).round()));
    try {
      await _configure();
      final ok = await _health.writeHealthData(
        value: metric == HealthMetric.water ? baseAmount / 1000 : baseAmount,
        type: _writeType(metric),
        unit: metric == HealthMetric.water ? HealthDataUnit.LITER : HealthDataUnit.MINUTE,
        startTime: start,
        endTime: at,
        recordingMethod: RecordingMethod.manual,
      );
      return ok ? (metric: metric, start: start, end: at) : null;
    } catch (e) {
      logWarning('Health: could not log ${metric.name}: $e');
      return null;
    }
  }

  @override
  Future<bool> addSampleData() async {
    final now = clock.now();
    DateTime at(int daysAgo, int hour, [int minute = 0]) => DateTime(now.year, now.month, now.day - daysAgo, hour, minute);
    try {
      await _configure();
      final types = [
        HealthDataType.STEPS,
        HealthDataType.WORKOUT,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.WATER,
        if (!isAndroid) HealthDataType.MINDFULNESS,
      ];
      final allowed = await _health.requestAuthorization(types,
          permissions: [for (final _ in types) HealthDataAccess.READ_WRITE]);
      if (!allowed) return false;
      final hour = now.hour;
      // Today: what's happened by now; yesterday: a full day
      final ok = await Future.wait([
        _health.writeHealthData(value: 3200, type: HealthDataType.STEPS, startTime: at(0, 0), endTime: hour > 1 ? at(0, hour - 1) : now),
        _health.writeHealthData(value: 9400, type: HealthDataType.STEPS, startTime: at(1, 8), endTime: at(1, 20)),
        _health.writeWorkoutData(activityType: HealthWorkoutActivityType.RUNNING, start: now.subtract(const Duration(minutes: 40)), end: now.subtract(const Duration(minutes: 8)), totalDistance: 5000, title: 'Sample run'),
        _health.writeWorkoutData(activityType: HealthWorkoutActivityType.RUNNING, start: at(1, 7), end: at(1, 7, 45), totalDistance: 7000, title: 'Sample run'),
        _health.writeHealthData(value: 0, type: HealthDataType.SLEEP_ASLEEP, startTime: at(1, 23, 10), endTime: at(0, 6, 25)),
        _health.writeHealthData(value: 0, type: HealthDataType.SLEEP_ASLEEP, startTime: at(2, 23, 40), endTime: at(1, 6, 50)),
        _health.writeHealthData(value: 0.75, type: HealthDataType.WATER, unit: HealthDataUnit.LITER, startTime: now, endTime: now),
        if (!isAndroid)
          _health.writeHealthData(value: 10, type: HealthDataType.MINDFULNESS, startTime: now.subtract(const Duration(minutes: 15)), endTime: now.subtract(const Duration(minutes: 5))),
      ]);
      return ok.every((written) => written);
    } catch (e) {
      logWarning('Health: could not add sample data: $e');
      return false;
    }
  }

  @override
  Future<bool> remove(HealthRecord record) async {
    try {
      await _configure();
      return await _health.delete(type: _writeType(record.metric), startTime: record.start, endTime: record.end);
    } catch (e) {
      logWarning('Health: could not remove ${record.metric.name}: $e');
      return false;
    }
  }
}
