import '../entities/habit.dart';
import '../entities/habit_category.dart';
import '../entities/habit_color.dart';
import '../entities/reset_frequency.dart';
import '../entities/reminder_settings.dart';
import '../repositories/habit_repository.dart';
import '../../core/validation/habit_validator.dart';
import '../../core/exceptions/storage_exceptions.dart';

class UpdateHabitUseCase {
  final HabitRepository _repository;

  const UpdateHabitUseCase(this._repository);

  /// Update habit progress
  Future<Habit> updateProgress(String habitId, int newProgress) async {
    try {
      final habit = await _getHabitById(habitId);
      
      if (newProgress < 0 || newProgress > habit.target) {
        throw ValidationException('Progress must be between 0 and ${habit.target}');
      }

      final updatedHabit = habit.updateProgress(newProgress);
      
      // Validate the updated habit
      final validationResult = HabitValidator.validate(updatedHabit);
      if (!validationResult.isValid) {
        throw ValidationException('Invalid updated habit: ${validationResult.errors.join(', ')}');
      }

      await _repository.saveHabit(updatedHabit);
      return updatedHabit;
    } catch (e) {
      if (e is ValidationException || e is StorageException) rethrow;
      throw StorageException('Failed to update habit progress: $e');
    }
  }

  /// Increment habit progress
  Future<Habit> incrementProgress(String habitId, [int amount = 1]) async {
    try {
      final habit = await _getHabitById(habitId);
      final newProgress = (habit.progress + amount).clamp(0, habit.target);
      return await updateProgress(habitId, newProgress);
    } catch (e) {
      if (e is ValidationException || e is StorageException) rethrow;
      throw StorageException('Failed to increment habit progress: $e');
    }
  }

  /// Decrement habit progress
  Future<Habit> decrementProgress(String habitId, [int amount = 1]) async {
    try {
      final habit = await _getHabitById(habitId);
      final newProgress = (habit.progress - amount).clamp(0, habit.target);
      return await updateProgress(habitId, newProgress);
    } catch (e) {
      if (e is ValidationException || e is StorageException) rethrow;
      throw StorageException('Failed to decrement habit progress: $e');
    }
  }

  /// Update habit details
  Future<Habit> updateDetails(String habitId, UpdateHabitParams params) async {
    try {
      final habit = await _getHabitById(habitId);
      
      // Validate parameters
      _validateUpdateParams(params);
      
      // Check for duplicate name if name is being changed
      if (params.name != null && params.name != habit.name) {
        await _checkDuplicateName(params.name!, excludeId: habitId);
      }

      final updatedHabit = habit.updateDetails(
        name: params.name,
        target: params.target,
        units: params.units,
        color: params.color,
        category: params.category,
        resetFrequency: params.resetFrequency,
        reminder: params.reminder,
        icon: params.icon,
      );

      // Validate the updated habit
      final validationResult = HabitValidator.validate(updatedHabit);
      if (!validationResult.isValid) {
        throw ValidationException('Invalid updated habit: ${validationResult.errors.join(', ')}');
      }

      await _repository.saveHabit(updatedHabit);
      return updatedHabit;
    } catch (e) {
      if (e is ValidationException || e is StorageException) rethrow;
      throw StorageException('Failed to update habit details: $e');
    }
  }

  /// Reset habit progress
  Future<Habit> resetProgress(String habitId) async {
    try {
      final habit = await _getHabitById(habitId);
      final resetHabit = habit.resetProgress();
      
      await _repository.saveHabit(resetHabit);
      return resetHabit;
    } catch (e) {
      if (e is StorageException) rethrow;
      throw StorageException('Failed to reset habit progress: $e');
    }
  }

  /// Update habit history for a specific date
  Future<Habit> updateHistoryForDate(String habitId, DateTime date, int progress) async {
    try {
      final habit = await _getHabitById(habitId);
      
      if (progress < 0 || progress > habit.target) {
        throw ValidationException('Progress must be between 0 and ${habit.target}');
      }

      await _repository.saveHabitHistory(habitId, date, progress);
      
      // Return updated habit
      return await _getHabitById(habitId);
    } catch (e) {
      if (e is ValidationException || e is StorageException) rethrow;
      throw StorageException('Failed to update habit history: $e');
    }
  }

  /// Reset habits that need to be reset based on their frequency
  Future<List<Habit>> resetHabitsIfNeeded() async {
    try {
      final habitsNeedingReset = await _repository.getHabitsNeedingReset();
      final resetHabits = <Habit>[];

      for (final habit in habitsNeedingReset) {
        final resetHabit = habit.resetProgress();
        await _repository.saveHabit(resetHabit);
        resetHabits.add(resetHabit);
      }

      return resetHabits;
    } catch (e) {
      throw StorageException('Failed to reset habits: $e');
    }
  }

  /// Mark habit as completed for today
  Future<Habit> markCompleted(String habitId) async {
    try {
      final habit = await _getHabitById(habitId);
      return await updateProgress(habitId, habit.target);
    } catch (e) {
      if (e is ValidationException || e is StorageException) rethrow;
      throw StorageException('Failed to mark habit as completed: $e');
    }
  }

  Future<Habit> _getHabitById(String habitId) async {
    final habit = await _repository.getHabitById(habitId);
    if (habit == null) {
      throw StorageException('Habit with ID $habitId not found');
    }
    return habit;
  }

  void _validateUpdateParams(UpdateHabitParams params) {
    if (params.name != null) {
      if (params.name!.trim().isEmpty) {
        throw ValidationException('Habit name cannot be empty');
      }
      if (params.name!.trim().length > 50) {
        throw ValidationException('Habit name cannot exceed 50 characters');
      }
    }
    
    if (params.target != null) {
      if (params.target! <= 0) {
        throw ValidationException('Target must be greater than 0');
      }
      if (params.target! > 1000) {
        throw ValidationException('Target cannot exceed 1000');
      }
    }
  }

  Future<void> _checkDuplicateName(String name, {required String excludeId}) async {
    final existingHabits = await _repository.getHabits();
    final normalizedName = name.trim().toLowerCase();
    
    final duplicate = existingHabits.any((habit) => 
      habit.id != excludeId && habit.name.trim().toLowerCase() == normalizedName
    );
    
    if (duplicate) {
      throw ValidationException('A habit with the name "$name" already exists');
    }
  }
}

class UpdateHabitParams {
  final String? name;
  final int? target;
  final String? units;
  final HabitColor? color;
  final HabitCategory? category;
  final ResetFrequency? resetFrequency;
  final ReminderSettings? reminder;
  final String? icon;

  const UpdateHabitParams({
    this.name,
    this.target,
    this.units,
    this.color,
    this.category,
    this.resetFrequency,
    this.reminder,
    this.icon,
  });

  bool get hasChanges => 
    name != null || 
    target != null || 
    units != null ||
    color != null || 
    category != null || 
    resetFrequency != null || 
    reminder != null || 
    icon != null;
}