import 'package:flutter_test/flutter_test.dart';
import '../../../../lib/core/validation/habit_validator.dart';
import '../../../../lib/core/validation/validation_result.dart';
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

      test('should return invalid result for unusually high progress', () {
        final habit = TestData.createTestHabit(progress: 25, target: 10);
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

    group('validateBusinessRules', () {
      test('should return warning for habit needing reset', () {
        final oldDate = DateTime.now().subtract(const Duration(days: 8));
        final habit = TestData.createTestHabit(
          lastUpdatedDate: oldDate,
          progress: 5,
        );
        final result = HabitValidator.validateBusinessRules(habit);

        expect(result.isValid, isTrue);
        expect(result.warnings, contains('Habit may need to be reset based on reset frequency'));
      });

      test('should return warning for disabled reminder', () {
        final reminder = TestData.morningReminder.copyWith(enabled: false);
        final habit = TestData.createTestHabit(reminder: reminder);
        final result = HabitValidator.validateBusinessRules(habit);

        expect(result.isValid, isTrue);
        expect(result.warnings, contains('Reminder is configured but disabled'));
      });
    });

    group('validateHabits', () {
      test('should return valid result for valid habits list', () {
        final habits = TestData.createTestHabits(3);
        final result = HabitValidator.validateHabits(habits);

        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
      });

      test('should return warning for empty habits list', () {
        final result = HabitValidator.validateHabits([]);

        expect(result.isValid, isTrue);
        expect(result.warnings, contains('No habits to validate'));
      });

      test('should return invalid result for duplicate IDs', () {
        final habit1 = TestData.createTestHabit(id: 'duplicate_id');
        final habit2 = TestData.createTestHabit(id: 'duplicate_id');
        final result = HabitValidator.validateHabits([habit1, habit2]);

        expect(result.isValid, isFalse);
        expect(result.errors.first, contains('Duplicate habit IDs found'));
      });

      test('should return warning for duplicate names', () {
        final habit1 = TestData.createTestHabit(id: 'id1', name: 'Same Name');
        final habit2 = TestData.createTestHabit(id: 'id2', name: 'Same Name');
        final result = HabitValidator.validateHabits([habit1, habit2]);

        expect(result.isValid, isTrue);
        expect(result.warnings.any((w) => w.contains('Duplicate habit names found')), isTrue);
      });

      test('should return warning for too many habits', () {
        final habits = TestData.createTestHabits(25);
        final result = HabitValidator.validateHabits(habits);

        expect(result.isValid, isTrue);
        expect(result.warnings, contains('Consider reducing the number of habits for better focus (current: 25)'));
      });

      test('should include individual habit validation errors', () {
        final validHabit = TestData.createTestHabit(id: 'valid');
        final invalidHabit = TestData.createTestHabit(id: 'invalid', name: '');
        final result = HabitValidator.validateHabits([validHabit, invalidHabit]);

        expect(result.isValid, isFalse);
        expect(result.errors.any((e) => e.contains('invalid') && e.contains('Habit name cannot be empty')), isTrue);
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