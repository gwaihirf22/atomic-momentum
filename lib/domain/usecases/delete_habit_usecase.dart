import '../entities/habit.dart';
import '../entities/habit_category.dart';
import '../repositories/habit_repository.dart';
import '../../core/exceptions/storage_exceptions.dart';

class DeleteHabitUseCase {
  final HabitRepository _repository;

  const DeleteHabitUseCase(this._repository);

  /// Delete a single habit
  Future<void> call(String habitId) async {
    try {
      // Verify habit exists before deleting
      final habit = await _repository.getHabitById(habitId);
      if (habit == null) {
        throw StorageException('Habit with ID $habitId not found');
      }

      await _repository.deleteHabit(habitId);
    } catch (e) {
      if (e is StorageException) rethrow;
      throw StorageException('Failed to delete habit: $e');
    }
  }

  /// Delete multiple habits
  Future<void> deleteMultiple(List<String> habitIds) async {
    try {
      if (habitIds.isEmpty) return;

      // Verify all habits exist before deleting any
      final nonExistentIds = <String>[];
      for (final id in habitIds) {
        final habit = await _repository.getHabitById(id);
        if (habit == null) {
          nonExistentIds.add(id);
        }
      }

      if (nonExistentIds.isNotEmpty) {
        throw StorageException(
          'Habits not found: ${nonExistentIds.join(', ')}'
        );
      }

      await _repository.deleteHabits(habitIds);
    } catch (e) {
      if (e is StorageException) rethrow;
      throw StorageException('Failed to delete habits: $e');
    }
  }

  /// Delete habit with confirmation (returns habit data for potential restore)
  Future<Habit> deleteWithConfirmation(String habitId) async {
    try {
      final habit = await _repository.getHabitById(habitId);
      if (habit == null) {
        throw StorageException('Habit with ID $habitId not found');
      }

      await _repository.deleteHabit(habitId);
      return habit; // Return for potential restoration
    } catch (e) {
      if (e is StorageException) rethrow;
      throw StorageException('Failed to delete habit: $e');
    }
  }

  /// Delete all habits in a category
  Future<List<Habit>> deleteByCategory(HabitCategory category) async {
    try {
      final categoryHabits = await _repository.getHabitsByCategory(category);
      if (categoryHabits.isEmpty) return [];

      final habitIds = categoryHabits.map((habit) => habit.id).toList();
      await _repository.deleteHabits(habitIds);
      
      return categoryHabits; // Return for potential restoration
    } catch (e) {
      throw StorageException('Failed to delete habits by category: $e');
    }
  }

  /// Delete completed habits older than specified days
  Future<List<Habit>> deleteOldCompletedHabits({int olderThanDays = 365}) async {
    try {
      final allHabits = await _repository.getHabits();
      final cutoffDate = DateTime.now().subtract(Duration(days: olderThanDays));
      
      final oldHabits = allHabits.where((habit) {
        // Check if habit was last updated before cutoff and is completed
        return habit.lastUpdatedDate.isBefore(cutoffDate) && 
               habit.isCompleted;
      }).toList();

      if (oldHabits.isEmpty) return [];

      final habitIds = oldHabits.map((habit) => habit.id).toList();
      await _repository.deleteHabits(habitIds);
      
      return oldHabits; // Return for potential restoration
    } catch (e) {
      throw StorageException('Failed to delete old completed habits: $e');
    }
  }

  /// Clear all habits (dangerous operation)
  Future<void> clearAllHabits() async {
    try {
      await _repository.clearAllHabits();
    } catch (e) {
      throw StorageException('Failed to clear all habits: $e');
    }
  }

  /// Get habits that would be deleted by cleanup operations
  Future<List<Habit>> getHabitsForCleanup({int olderThanDays = 365}) async {
    try {
      final allHabits = await _repository.getHabits();
      final cutoffDate = DateTime.now().subtract(Duration(days: olderThanDays));
      
      return allHabits.where((habit) {
        return habit.lastUpdatedDate.isBefore(cutoffDate) && 
               habit.isCompleted;
      }).toList();
    } catch (e) {
      throw StorageException('Failed to get habits for cleanup: $e');
    }
  }
}