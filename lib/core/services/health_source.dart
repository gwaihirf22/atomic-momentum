import 'dart:io' show Platform;
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

  /// Whole units of [metric] for each day from [from] to [to] (date-only).
  Future<Map<DateTime, int>> dailyValues(HealthMetric metric, DateTime from, DateTime to);

  /// Logs [amount] of a writable metric ending at [at]; null if it failed.
  Future<HealthRecord?> log(HealthMetric metric, int amount, DateTime at);

  /// Takes back something [log] wrote.
  Future<bool> remove(HealthRecord record);
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
        HealthMetric.exerciseMinutes => [android ? HealthDataType.WORKOUT : HealthDataType.EXERCISE_TIME],
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
        HealthMetric.exerciseMinutes || HealthMetric.mindfulMinutes => HealthDays.minutesByDay(spans, first, last),
        HealthMetric.sleepHours => HealthDays.sleepHoursByDay(spans, first, last),
        HealthMetric.workouts => HealthDays.countByStartDay(points.map((p) => p.dateFrom), first, last),
        HealthMetric.water => HealthDays.waterGlassesByDay([
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
  Future<HealthRecord?> log(HealthMetric metric, int amount, DateTime at) async {
    if (!metric.writable || amount <= 0) return null;
    // Water: an instant; mindful minutes: a session ending now
    final start = metric == HealthMetric.water ? at : at.subtract(Duration(minutes: amount));
    try {
      await _configure();
      final ok = await _health.writeHealthData(
        value: metric == HealthMetric.water ? amount * HealthMetric.glassMl / 1000 : amount.toDouble(),
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
