import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/streak_data.dart';

void main() {
  group('StreakData', () {
    final now = DateTime.now();
    final testDate = DateTime(now.year, now.month, now.day);
    final yesterday = testDate.subtract(const Duration(days: 1));
    final twoDaysAgo = testDate.subtract(const Duration(days: 2));

    group('constructor and factory', () {
      test('should create StreakData with all parameters', () {
        final streakData = StreakData(
          current: 5,
          longest: 10,
          lastUpdateDate: testDate,
          history: const [],
        );

        expect(streakData.current, 5);
        expect(streakData.longest, 10);
        expect(streakData.lastUpdateDate, testDate);
        expect(streakData.history, isEmpty);
      });

      test('empty factory should create zero streak', () {
        final streakData = StreakData.empty();

        expect(streakData.current, 0);
        expect(streakData.longest, 0);
        expect(streakData.lastUpdateDate, isNull);
        expect(streakData.history, isEmpty);
      });
    });

    group('JSON serialization', () {
      test('should serialize to JSON correctly', () {
        final streakData = StreakData(
          current: 3,
          longest: 7,
          lastUpdateDate: testDate,
          history: [
            StreakPeriod(startDate: twoDaysAgo, endDate: yesterday, length: 2),
            StreakPeriod(startDate: testDate, endDate: null, length: 3),
          ],
        );

        final json = streakData.toJson();

        expect(json['current'], 3);
        expect(json['longest'], 7);
        expect(json['lastUpdateDate'], testDate.toIso8601String());
        expect(json['history'], hasLength(2));
      });

      test('should deserialize from JSON correctly', () {
        final json = {
          'current': 4,
          'longest': 8,
          'lastUpdateDate': testDate.toIso8601String(),
          'history': [
            {
              'startDate': twoDaysAgo.toIso8601String(),
              'endDate': null,
              'length': 4,
            }
          ],
        };

        final streakData = StreakData.fromJson(json);

        expect(streakData.current, 4);
        expect(streakData.longest, 8);
        expect(streakData.lastUpdateDate, testDate);
        expect(streakData.history, hasLength(1));
        expect(streakData.history.first.length, 4);
      });

      test('should handle null lastUpdateDate in JSON', () {
        final json = {
          'current': 0,
          'longest': 0,
          'lastUpdateDate': null,
          'history': [],
        };

        final streakData = StreakData.fromJson(json);

        expect(streakData.lastUpdateDate, isNull);
        // Saved before "never miss twice" existed
        expect(streakData.atRisk, isFalse);
      });

      test('round-trips atRisk', () {
        const streak = StreakData(current: 5, longest: 5, history: [], atRisk: true);
        final restored = StreakData.fromJson(streak.toJson());
        expect(restored.atRisk, isTrue);
        expect(restored, streak);
        expect(restored, isNot(streak.copyWith(atRisk: false)));
      });
    });

    group('equality', () {
      test('should be equal when all properties match', () {
        final streak1 = StreakData(
          current: 3,
          longest: 5,
          lastUpdateDate: testDate,
          history: [StreakPeriod(startDate: testDate, endDate: null, length: 3)],
        );

        final streak2 = StreakData(
          current: 3,
          longest: 5,
          lastUpdateDate: testDate,
          history: [StreakPeriod(startDate: testDate, endDate: null, length: 3)],
        );

        expect(streak1, streak2);
      });

      test('should not be equal when properties differ', () {
        final streak1 = StreakData(current: 3, longest: 5, lastUpdateDate: testDate, history: const []);
        final streak2 = StreakData(current: 4, longest: 5, lastUpdateDate: testDate, history: const []);

        expect(streak1, isNot(streak2));
      });
    });
  });

  group('StreakPeriod', () {
    final startDate = DateTime(2024, 1, 10);
    final endDate = DateTime(2024, 1, 15);

    group('constructor', () {
      test('should create StreakPeriod with all parameters', () {
        final period = StreakPeriod(
          startDate: startDate,
          endDate: endDate,
          length: 5,
        );

        expect(period.startDate, startDate);
        expect(period.endDate, endDate);
        expect(period.length, 5);
      });

      test('should create active period with null endDate', () {
        final period = StreakPeriod(
          startDate: startDate,
          endDate: null,
          length: 3,
        );

        expect(period.isActive, isTrue);
        expect(period.endDate, isNull);
      });
    });

    group('properties', () {
      test('isActive should return false when endDate is set', () {
        final period = StreakPeriod(
          startDate: startDate,
          endDate: endDate,
          length: 5,
        );

        expect(period.isActive, isFalse);
      });

      test('durationInDays should calculate correctly for ended period', () {
        final period = StreakPeriod(
          startDate: startDate,
          endDate: endDate,
          length: 5,
        );

        expect(period.durationInDays, 6); // 5 days difference + 1
      });

      test('durationInDays should calculate from now for active period', () {
        final now = DateTime.now();
        final period = StreakPeriod(
          startDate: now.subtract(const Duration(days: 2)),
          endDate: null,
          length: 3,
        );

        expect(period.durationInDays, 3); // 2 days + 1
      });
    });

    group('copyWith', () {
      test('should copy with new values', () {
        final original = StreakPeriod(
          startDate: startDate,
          endDate: null,
          length: 3,
        );

        final updated = original.copyWith(
          endDate: endDate,
          length: 5,
        );

        expect(updated.startDate, startDate); // Should remain same
        expect(updated.endDate, endDate); // Should be updated
        expect(updated.length, 5); // Should be updated
      });
    });

    group('JSON serialization', () {
      test('should serialize to JSON correctly', () {
        final period = StreakPeriod(
          startDate: startDate,
          endDate: endDate,
          length: 5,
        );

        final json = period.toJson();

        expect(json['startDate'], startDate.toIso8601String());
        expect(json['endDate'], endDate.toIso8601String());
        expect(json['length'], 5);
      });

      test('should handle null endDate in JSON', () {
        final period = StreakPeriod(
          startDate: startDate,
          endDate: null,
          length: 3,
        );

        final json = period.toJson();

        expect(json['endDate'], isNull);
      });

      test('should deserialize from JSON correctly', () {
        final json = {
          'startDate': startDate.toIso8601String(),
          'endDate': endDate.toIso8601String(),
          'length': 5,
        };

        final period = StreakPeriod.fromJson(json);

        expect(period.startDate, startDate);
        expect(period.endDate, endDate);
        expect(period.length, 5);
      });
    });

    group('equality', () {
      test('should be equal when all properties match', () {
        final period1 = StreakPeriod(startDate: startDate, endDate: endDate, length: 5);
        final period2 = StreakPeriod(startDate: startDate, endDate: endDate, length: 5);

        expect(period1, period2);
      });

      test('should not be equal when properties differ', () {
        final period1 = StreakPeriod(startDate: startDate, endDate: endDate, length: 5);
        final period2 = StreakPeriod(startDate: startDate, endDate: endDate, length: 6);

        expect(period1, isNot(period2));
      });
    });
  });
}