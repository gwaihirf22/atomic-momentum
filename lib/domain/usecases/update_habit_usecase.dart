import '../entities/habit.dart';
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
        categoryId: params.categoryId,
        resetFrequency: params.resetFrequency,
        reminder: params.reminder,
        icon: params.icon,
        resetAnchor: params.resetAnchor,
        resetInterval: params.resetInterval,
        scheduledWeekdays: params.scheduledWeekdays,
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

  /// Set what was logged on a past [date] (or today). Progress and streak
  /// are recomputed, so filling in a missed day restores the streak.
  Future<Habit> updateHistoryForDate(String habitId, DateTime date, int progress) async {
    try {
      final habit = await _getHabitById(habitId);
      final updatedHabit = habit.setProgressForDate(date, progress);

      await _repository.saveHabit(updatedHabit);
      return updatedHabit;
    } on ArgumentError catch (e) {
      throw ValidationException(e.message.toString());
    } catch (e) {
      if (e is ValidationException || e is StorageException) rethrow;
      throw StorageException('Failed to update habit history: $e');
    }
  }

  /// Brings every habit up to date and saves the ones that changed: those
  /// whose period rolled over (progress becomes the new period's total, an
  /// expired streak drops to 0), and any whose stored streak was worked out
  /// by an older rule. Returns the saved habits.
  Future<List<Habit>> resetHabitsIfNeeded([DateTime? now]) async {
    try {
      final at = now ?? DateTime.now();
      final habits = await _repository.getHabits();
      final resetHabits = <Habit>[];

      for (final habit in habits) {
        final refreshedHabit = habit.refresh(at);
        final changed = habit.shouldReset(at) ||
            refreshedHabit.progress != habit.progress ||
            refreshedHabit.streak != habit.streak;
        if (!changed) continue;
        await _repository.saveHabit(refreshedHabit);
        resetHabits.add(refreshedHabit);
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
  final String? categoryId;
  final ResetFrequency? resetFrequency;
  final ReminderSettings? reminder;
  final String? icon;
  final DateTime? resetAnchor;
  final int? resetInterval;
  /// Pass all seven days to go back to every day (null means unchanged).
  final List<int>? scheduledWeekdays;

  const UpdateHabitParams({
    this.name,
    this.target,
    this.units,
    this.color,
    this.categoryId,
    this.resetFrequency,
    this.reminder,
    this.icon,
    this.resetAnchor,
    this.resetInterval,
    this.scheduledWeekdays,
  });

  bool get hasChanges => 
    name != null || 
    target != null || 
    units != null ||
    color != null || 
    categoryId != null || 
    resetFrequency != null || 
    reminder != null || 
    icon != null ||
    resetAnchor != null ||
    resetInterval != null ||
    scheduledWeekdays != null;
}