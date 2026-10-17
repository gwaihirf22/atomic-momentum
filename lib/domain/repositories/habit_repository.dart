import '../entities/habit.dart';

abstract class HabitRepository {
  /// Get all habits
  Future<List<Habit>> getHabits();

  /// Get a specific habit by ID
  Future<Habit?> getHabitById(String id);

  /// Save a habit (create or update)
  Future<void> saveHabit(Habit habit);

  /// Delete a habit by ID
  Future<void> deleteHabit(String id);
}
