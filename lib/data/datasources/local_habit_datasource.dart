import '../models/habit_model.dart';

abstract class LocalHabitDataSource {
  /// Get all habits from local storage
  Future<List<HabitModel>> getHabits();

  /// Save a habit to local storage (create or update)
  Future<void> saveHabit(HabitModel habit);

  /// Save several habits in one write (create or update)
  Future<void> saveHabits(List<HabitModel> habits);

  /// Delete a habit from local storage
  Future<void> deleteHabit(String id);
}
