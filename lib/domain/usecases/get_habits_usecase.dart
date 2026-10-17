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
}
