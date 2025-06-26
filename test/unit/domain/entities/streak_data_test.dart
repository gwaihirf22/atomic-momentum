import 'package:flutter_test/flutter_test.dart';
import '../../../../lib/domain/entities/streak_data.dart';

void main() {
  group('StreakData', () {
    final testDate = DateTime(2024, 1, 15);
    final yesterday = testDate.subtract(const Duration(days: 1));
    final twoDaysAgo = testDate.subtract(const Duration(days: 2));
    final tomorrow = testDate.add(const Duration(days: 1));

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

    group('updateStreak', () {
      test('should start new streak on first completion', () {
        final initial = StreakData.empty();
        final updated = initial.updateStreak(date: testDate, completed: true);

        expect(updated.current, 1);
        expect(updated.longest, 1);
        expect(updated.lastUpdateDate, testDate);
        expect(updated.history, hasLength(1));
        expect(updated.history.first.startDate, testDate);
        expect(updated.history.first.endDate, isNull);
        expect(updated.history.first.length, 1);
      });

      test('should continue streak on consecutive day completion', () {
        final initial = StreakData(
          current: 2,
          longest: 5,
          lastUpdateDate: yesterday,
          history: [
            StreakPeriod(startDate: twoDaysAgo, endDate: null, length: 2),
          ],
        );

        final updated = initial.updateStreak(date: testDate, completed: true);

        expect(updated.current, 3);
        expect(updated.longest, 5); // Should remain same
        expect(updated.lastUpdateDate, testDate);
        expect(updated.history, hasLength(1));
        expect(updated.history.first.length, 3);
      });

      test('should update longest streak when current exceeds it', () {
        final initial = StreakData(
          current: 4,
          longest: 4,
          lastUpdateDate: yesterday,
          history: [
            StreakPeriod(startDate: testDate.subtract(const Duration(days: 4)), endDate: null, length: 4),
          ],
        );

        final updated = initial.updateStreak(date: testDate, completed: true);

        expect(updated.current, 5);
        expect(updated.longest, 5); // Should be updated
      });

      test('should break streak when not completed', () {
        final initial = StreakData(
          current: 3,
          longest: 5,
          lastUpdateDate: yesterday,
          history: [
            StreakPeriod(startDate: twoDaysAgo, endDate: null, length: 3),
          ],
        );

        final updated = initial.updateStreak(date: testDate, completed: false);

        expect(updated.current, 0);
        expect(updated.longest, 5); // Should remain same
        expect(updated.lastUpdateDate, testDate);
        expect(updated.history, hasLength(1));
        expect(updated.history.first.endDate, yesterday); // Should end previous streak
      });

      test('should start new streak after gap in days', () {
        final initial = StreakData(
          current: 2,
          longest: 5,
          lastUpdateDate: testDate.subtract(const Duration(days: 3)), // 3-day gap
          history: [
            StreakPeriod(
              startDate: testDate.subtract(const Duration(days: 4)), 
              endDate: null, 
              length: 2
            ),
          ],
        );

        final updated = initial.updateStreak(date: testDate, completed: true);

        expect(updated.current, 1); // New streak
        expect(updated.longest, 5);
        expect(updated.history, hasLength(2)); // Should have old and new streak periods
        expect(updated.history.last.startDate, testDate);
        expect(updated.history.last.length, 1);
      });

      test('should not change streak for future dates', () {
        final initial = StreakData(
          current: 2,
          longest: 5,
          lastUpdateDate: yesterday,
          history: [
            StreakPeriod(startDate: twoDaysAgo, endDate: null, length: 2),
          ],
        );

        final updated = initial.updateStreak(date: tomorrow, completed: true);

        expect(updated.current, 2); // Should remain unchanged
        expect(updated.longest, 5);
        expect(updated.lastUpdateDate, yesterday); // Should remain unchanged
      });

      test('should handle same day updates correctly', () {
        final initial = StreakData(
          current: 2,
          longest: 5,
          lastUpdateDate: testDate,
          history: [
            StreakPeriod(startDate: yesterday, endDate: null, length: 2),
          ],
        );

        final updated = initial.updateStreak(date: testDate, completed: true);

        expect(updated.current, 2); // Should remain same
        expect(updated.lastUpdateDate, testDate);
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