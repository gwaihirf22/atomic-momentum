import '../entities/habit.dart';
import '../entities/habit_category.dart';

abstract class HabitRepository {
  /// Get all habits
  Future<List<Habit>> getHabits();
  
  /// Get habits by category
  Future<List<Habit>> getHabitsByCategory(HabitCategory category);
  
  /// Get a specific habit by ID
  Future<Habit?> getHabitById(String id);
  
  /// Save a habit (create or update)
  Future<void> saveHabit(Habit habit);
  
  /// Save multiple habits
  Future<void> saveHabits(List<Habit> habits);
  
  /// Delete a habit by ID
  Future<void> deleteHabit(String id);
  
  /// Delete multiple habits by IDs
  Future<void> deleteHabits(List<String> ids);
  
  /// Update habit progress
  Future<void> updateHabitProgress(String id, int progress);
  
  /// Get habit history for a specific habit
  Future<Map<DateTime, int>> getHabitHistory(String id);
  
  /// Save habit history for a specific date
  Future<void> saveHabitHistory(String id, DateTime date, int progress);
  
  /// Clear all habits (use with caution)
  Future<void> clearAllHabits();
  
  /// Get total number of habits
  Future<int> getHabitCount();
  
  /// Check if a habit exists
  Future<bool> habitExists(String id);
  
  /// Get habits that need reset based on their reset frequency
  Future<List<Habit>> getHabitsNeedingReset();
  
  /// Get habits with reminders enabled
  Future<List<Habit>> getHabitsWithReminders();
  
  /// Backup all habits to a JSON string
  Future<String> backupHabits();
  
  /// Restore habits from a JSON string
  Future<void> restoreHabits(String jsonData);
}