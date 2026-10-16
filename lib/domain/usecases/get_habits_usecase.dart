import '../entities/habit.dart';
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