import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/core/validation/habit_validator.dart';
import 'package:atomic_momentum/core/validation/validation_result.dart';
import '../../../helpers/test_data.dart';

void main() {
  group('HabitValidator', () {
    group('validate', () {
      test('should return valid result for valid habit', () {
        final habit = TestData.createTestHabit();
        final result = HabitValidator.validate(habit);

        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
      });

      test('should return invalid result for empty name', () {
        final habit = TestData.createTestHabit(name: '');
        final result = HabitValidator.validate(habit);

        expect(result.isValid, isFalse);
        expect(result.errors, contains('Habit name cannot be empty'));
      });

      test('should return invalid result for too long name', () {
        final longName = 'a' * 51; // 51 characters
        final habit = TestData.createTestHabit(name: longName);
        final result = HabitValidator.validate(habit);

        expect(result.isValid, isFalse);
        expect(result.errors, contains('Habit name cannot exceed 50 characters'));
      });

      test('should return invalid result for too short name', () {
        final habit = TestData.createTestHabit(name: 'a');
        final result = HabitValidator.validate(habit);

        expect(result.isValid, isFalse);
        expect(result.errors, contains('Habit name must be at least 2 characters long'));
      });

      test('should return invalid result for name with invalid characters', () {
        final habit = TestData.createTestHabit(name: 'Test<>Habit');
        final result = HabitValidator.validate(habit);

        expect(result.isValid, isFalse);
        expect(result.errors, contains('Habit name contains invalid characters'));
      });

      test('should return invalid result for zero target', () {
        final habit = TestData.createTestHabit(target: 0);
        final result = HabitValidator.validate(habit);

        expect(result.isValid, isFalse);
        expect(result.errors, contains('Target must be greater than 0'));
      });

      test('should return invalid result for negative progress', () {
        final habit = TestData.createTestHabit(progress: -1);
        final result = HabitValidator.validate(habit);

        expect(result.isValid, isFalse);
        expect(result.errors, contains('Progress cannot be negative'));
      });

      test('going past the target is fine, up to ten times it', () {
        expect(HabitValidator.validate(TestData.createTestHabit(progress: 25, target: 10)).isValid, isTrue);
        expect(HabitValidator.validate(TestData.createTestHabit(progress: 100, target: 10)).isValid, isTrue);
      });

      test('should return invalid result for unusually high progress', () {
        final habit = TestData.createTestHabit(progress: 101, target: 10);
        final result = HabitValidator.validate(habit);

        expect(result.isValid, isFalse);
        expect(result.errors, contains('Progress seems unusually high compared to target'));
      });

      test('should return invalid result for future last updated date', () {
        final futureDate = DateTime.now().add(const Duration(days: 1));
        final habit = TestData.createTestHabit(lastUpdatedDate: futureDate);
        final result = HabitValidator.validate(habit);

        expect(result.isValid, isFalse);
        expect(result.errors, contains('Last updated date cannot be in the future'));
      });

      test('should return warning for old habit without recent updates', () {
        final oldDate = DateTime.now().subtract(const Duration(days: 100));
        final habit = TestData.createTestHabit(lastUpdatedDate: oldDate);
        final result = HabitValidator.validate(habit);

        expect(result.isValid, isTrue);
        expect(result.warnings, contains("Habit hasn't been updated in over 90 days"));
      });

      test('should return invalid result for negative current streak', () {
        final streak = TestData.sampleStreak.copyWith(current: -1);
        final habit = TestData.createTestHabit(streak: streak);
        final result = HabitValidator.validate(habit);

        expect(result.isValid, isFalse);
        expect(result.errors, contains('Current streak cannot be negative'));
      });

      test('should return invalid result when longest streak < current streak', () {
        final streak = TestData.sampleStreak.copyWith(current: 10, longest: 5);
        final habit = TestData.createTestHabit(streak: streak);
        final result = HabitValidator.validate(habit);

        expect(result.isValid, isFalse);
        expect(result.errors, contains('Longest streak cannot be less than current streak'));
      });
    });
  });

  group('ValidationResult', () {
    test('should create valid result', () {
      final result = ValidationResult.valid();

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
    });

    test('should create invalid result', () {
      final result = ValidationResult.invalid(['Error 1', 'Error 2'], ['Warning 1']);

      expect(result.isValid, isFalse);
      expect(result.errors, ['Error 1', 'Error 2']);
      expect(result.warnings, ['Warning 1']);
    });

    test('should create warning result', () {
      final result = ValidationResult.warning(['Warning 1']);

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.warnings, ['Warning 1']);
    });

    test('should combine results correctly', () {
      final result1 = ValidationResult.invalid(['Error 1'], ['Warning 1']);
      final result2 = ValidationResult.warning(['Warning 2']);

      final combined = result1.combine(result2);

      expect(combined.isValid, isFalse);
      expect(combined.errors, ['Error 1']);
      expect(combined.warnings, ['Warning 1', 'Warning 2']);
    });

    test('should get first error', () {
      final result = ValidationResult.invalid(['First Error', 'Second Error']);

      expect(result.firstError, 'First Error');
    });

    test('should return empty string for first error when no errors', () {
      final result = ValidationResult.valid();

      expect(result.firstError, '');
    });

    test('should detect errors and warnings', () {
      final resultWithErrors = ValidationResult.invalid(['Error']);
      final resultWithWarnings = ValidationResult.warning(['Warning']);
      final validResult = ValidationResult.valid();

      expect(resultWithErrors.hasErrors, isTrue);
      expect(resultWithErrors.hasWarnings, isFalse);
      expect(resultWithWarnings.hasErrors, isFalse);
      expect(resultWithWarnings.hasWarnings, isTrue);
      expect(validResult.hasErrors, isFalse);
      expect(validResult.hasWarnings, isFalse);
    });

    test('should have proper toString implementation', () {
      final validResult = ValidationResult.valid();
      final invalidResult = ValidationResult.invalid(['Error 1'], ['Warning 1']);
      final warningResult = ValidationResult.warning(['Warning 1']);

      expect(validResult.toString(), 'Valid');
      expect(invalidResult.toString(), contains('Errors: Error 1'));
      expect(invalidResult.toString(), contains('Warnings: Warning 1'));
      expect(warningResult.toString(), contains('Warnings: Warning 1'));
      expect(warningResult.toString(), isNot(contains('Errors')));
    });
  });
}