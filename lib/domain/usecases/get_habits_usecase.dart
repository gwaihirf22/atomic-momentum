import '../entities/habit.dart';
import '../entities/habit_category.dart';
import '../repositories/habit_repository.dart';
import '../../core/exceptions/storage_exceptions.dart';

class GetHabitsUseCase {
  final HabitRepository _repository;

  const GetHabitsUseCase(this._repository);

  /// Get all habits
  Future<List<Habit>> call() async {
    try {
      return await _repository.getHabits();
    } catch (e) {
      throw StorageException('Failed to get habits: $e');
    }
  }

  /// Get habits by category
  Future<List<Habit>> byCategory(HabitCategory category) async {
    try {
      return await _repository.getHabitsByCategory(category);
    } catch (e) {
      throw StorageException('Failed to get habits by category: $e');
    }
  }

  /// Get habits by multiple categories
  Future<List<Habit>> byCategories(List<HabitCategory> categories) async {
    try {
      final allHabits = await _repository.getHabits();
      return allHabits.where((habit) => categories.contains(habit.category)).toList();
    } catch (e) {
      throw StorageException('Failed to get habits by categories: $e');
    }
  }

  /// Get habits that need reset
  Future<List<Habit>> needingReset() async {
    try {
      return await _repository.getHabitsNeedingReset();
    } catch (e) {
      throw StorageException('Failed to get habits needing reset: $e');
    }
  }

  /// Get habits with reminders
  Future<List<Habit>> withReminders() async {
    try {
      return await _repository.getHabitsWithReminders();
    } catch (e) {
      throw StorageException('Failed to get habits with reminders: $e');
    }
  }

  /// Search habits by name or category
  Future<List<Habit>> search(String query) async {
    try {
      final allHabits = await _repository.getHabits();
      final lowercaseQuery = query.toLowerCase().trim();
      
      if (lowercaseQuery.isEmpty) return allHabits;
      
      return allHabits.where((habit) {
        return habit.name.toLowerCase().contains(lowercaseQuery) ||
               habit.category.displayName.toLowerCase().contains(lowercaseQuery);
      }).toList();
    } catch (e) {
      throw StorageException('Failed to search habits: $e');
    }
  }

  /// Get habits by completion status for a specific date
  Future<List<Habit>> byCompletionStatus(DateTime date, {required bool completed}) async {
    try {
      final allHabits = await _repository.getHabits();
      return allHabits.where((habit) => habit.wasCompletedOnDate(date) == completed).toList();
    } catch (e) {
      throw StorageException('Failed to get habits by completion status: $e');
    }
  }

  /// Get habits with active streaks
  Future<List<Habit>> withActiveStreaks() async {
    try {
      final allHabits = await _repository.getHabits();
      return allHabits.where((habit) => habit.streak.current > 0).toList();
    } catch (e) {
      throw StorageException('Failed to get habits with active streaks: $e');
    }
  }
}