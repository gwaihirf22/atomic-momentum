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
}
