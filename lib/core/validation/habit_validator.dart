import '../validation/validation_result.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/streak_data.dart';
import '../../domain/entities/two_minute_version.dart';
import 'package:clock/clock.dart';

class HabitValidator {
  static ValidationResult validate(Habit habit) {
    final errors = <String>[];
    final warnings = <String>[];

    // Name validation
    _validateName(habit.name, errors);
    
    // Progress and target validation
    _validateProgress(habit.progress, habit.target, errors);
    
    // Date validation
    _validateDates(habit, errors, warnings);
    
    // History validation
    _validateHistory(habit.history, habit.target, warnings);
    
    // Streak validation
    _validateStreak(habit.streak, errors);

    _validateTwoMinute(habit, errors);

    final isValid = errors.isEmpty;
    return ValidationResult(
      isValid: isValid,
      errors: errors,
      warnings: warnings,
    );
  }

  static void _validateTwoMinute(Habit habit, List<String> errors) {
    final tiny = habit.twoMinute;
    if (tiny == null) return;
    final description = tiny.description.trim();
    if (description.isEmpty) {
      errors.add('The two-minute version needs a description');
    } else if (description.length > TwoMinuteVersion.maxLength) {
      errors.add('The two-minute version cannot exceed ${TwoMinuteVersion.maxLength} characters');
    }
    final minimum = tiny.minimum;
    if (minimum != null && (minimum < 1 || minimum >= habit.target)) {
      errors.add('The two-minute amount must be between 1 and ${habit.target - 1}');
    }
  }

  static void _validateName(String name, List<String> errors) {
    final trimmedName = name.trim();
    
    if (trimmedName.isEmpty) {
      errors.add("Habit name cannot be empty");
      return;
    }
    
    if (trimmedName.length > 50) {
      errors.add("Habit name cannot exceed 50 characters");
    }
    
    if (trimmedName.length < 2) {
      errors.add("Habit name must be at least 2 characters long");
    }
    
    // Check for invalid characters
    if (trimmedName.contains(RegExp(r'[<>]'))) {
      errors.add("Habit name contains invalid characters");
    }
  }

  static void _validateProgress(int progress, int target, List<String> errors) {
    if (target <= 0) {
      errors.add("Target must be greater than 0");
      return; // Can't validate progress if target is invalid
    }
    
    if (progress < 0) {
      errors.add("Progress cannot be negative");
    }
    
    // Going past the target is fine ("10/8"), up to Habit.maxOverTarget times it
    if (progress > target * Habit.maxOverTarget) {
      errors.add("Progress seems unusually high compared to target");
    }
  }

  static void _validateDates(Habit habit, List<String> errors, List<String> warnings) {
    final now = clock.now();
    
    // Check if last updated date is in the future
    if (habit.lastUpdatedDate.isAfter(now.add(const Duration(hours: 1)))) {
      errors.add("Last updated date cannot be in the future");
    }
    
    // Check if creation date is after last modified date
    if (habit.metadata.createdDate.isAfter(habit.metadata.lastModifiedDate)) {
      errors.add("Creation date cannot be after last modified date");
    }
    
    // Check if creation date is after last updated date
    if (habit.metadata.createdDate.isAfter(habit.lastUpdatedDate)) {
      warnings.add("Creation date is after last updated date");
    }
    
    // Check if habit is very old without recent updates
    final daysSinceUpdate = now.difference(habit.lastUpdatedDate).inDays;
    if (daysSinceUpdate > 90) {
      warnings.add("Habit hasn't been updated in over 90 days");
    }
  }

  static void _validateHistory(Map<DateTime, int> history, int target, List<String> warnings) {
    if (history.isEmpty) {
      return; // Empty history is valid for new habits
    }
    
    // Check for unrealistic progress values in history
    final invalidEntries = history.entries.where((entry) => 
      entry.value < 0 || entry.value > target * Habit.maxOverTarget
    );
    
    if (invalidEntries.isNotEmpty) {
      warnings.add("History contains ${invalidEntries.length} entries with unrealistic progress values");
    }
    
    // Check for future dates in history
    final now = clock.now();
    final futureEntries = history.keys.where((date) => 
      date.isAfter(now.add(const Duration(days: 1)))
    );
    
    if (futureEntries.isNotEmpty) {
      warnings.add("History contains ${futureEntries.length} entries with future dates");
    }
    
    // Check for very old history entries
    final oldEntries = history.keys.where((date) => 
      now.difference(date).inDays > 365
    );
    
    if (oldEntries.length > 100) {
      warnings.add("History contains ${oldEntries.length} entries older than 1 year");
    }
  }

  static void _validateStreak(StreakData streak, List<String> errors) {
    // Current streak cannot be negative
    if (streak.current < 0) {
      errors.add("Current streak cannot be negative");
    }
    
    // Longest streak cannot be less than current streak
    if (streak.longest < streak.current) {
      errors.add("Longest streak cannot be less than current streak");
    }
    
    // Validate streak history
    for (final period in streak.history) {
      if (period.length <= 0) {
        errors.add("Streak period length must be positive");
      }
      
      if (period.endDate != null && period.endDate!.isBefore(period.startDate)) {
        errors.add("Streak period end date cannot be before start date");
      }
    }
    
    // Check for overlapping streak periods
    final sortedPeriods = List.from(streak.history)
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    
    for (int i = 0; i < sortedPeriods.length - 1; i++) {
      final current = sortedPeriods[i];
      final next = sortedPeriods[i + 1];
      
      if (current.endDate != null && 
          current.endDate!.isAfter(next.startDate)) {
        errors.add("Streak periods cannot overlap");
        break;
      }
    }
  }
}
