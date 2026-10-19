import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:atomic_momentum/core/services/health_source.dart';
import 'package:atomic_momentum/domain/entities/health_link.dart';

void main() {
  group('PluginHealthSource.accessTypes', () {
    test('Android: workouts also need their distance, calories and steps (found on the emulator)', () {
      for (final metric in [HealthMetric.workouts, HealthMetric.exerciseMinutes]) {
        final asked = PluginHealthSource.accessTypes(read: {metric}, android: true);
        expect(asked.keys, containsAll([
          HealthDataType.WORKOUT,
          HealthDataType.DISTANCE_DELTA,
          HealthDataType.TOTAL_CALORIES_BURNED,
          HealthDataType.STEPS,
        ]), reason: '$metric');
        expect(asked.values, everyElement(HealthDataAccess.READ));
      }
    });

    test('iPhone asks only for what it reads', () {
      expect(PluginHealthSource.accessTypes(read: {HealthMetric.workouts}, android: false).keys, [HealthDataType.WORKOUT]);
      expect(PluginHealthSource.accessTypes(read: {HealthMetric.exerciseMinutes}, android: false).keys,
          [HealthDataType.EXERCISE_TIME, HealthDataType.WORKOUT]);
    });

    test('each type once; writing wins over reading', () {
      final asked = PluginHealthSource.accessTypes(
        read: {HealthMetric.steps, HealthMetric.workouts, HealthMetric.water},
        write: {HealthMetric.water},
        android: true,
      );
      expect(asked.keys.where((t) => t == HealthDataType.STEPS), hasLength(1));
      expect(asked[HealthDataType.WATER], HealthDataAccess.READ_WRITE);
      expect(asked[HealthDataType.STEPS], HealthDataAccess.READ);
    });
  });
}
