import '../../domain/entities/habit.dart';
import '../../domain/repositories/habit_repository.dart';
import '../datasources/local_habit_datasource.dart';
import '../models/habit_model.dart';
import '../../core/exceptions/storage_exceptions.dart';
import '../../core/validation/habit_validator.dart';

class HabitRepositoryImpl implements HabitRepository {
  final LocalHabitDataSource _localDataSource;

  const HabitRepositoryImpl(this._localDataSource);

  @override
  Future<List<Habit>> getHabits() async {
    try {
      final habitModels = await _localDataSource.getHabits();
      
      final habits = <Habit>[];
      for (int i = 0; i < habitModels.length; i++) {
        try {
          final habit = habitModels[i].toDomain();
          habits.add(habit);
        } catch (e) {
          throw StorageException('Failed to convert habit model ${i + 1} to domain: $e');
        }
      }
      
      return habits;
    } catch (e) {
      throw StorageException('Failed to get habits: $e');
    }
  }

  @override
  Future<Habit?> getHabitById(String id) async {
    try {
      final habits = await getHabits();
      
      final foundHabit = habits.cast<Habit?>().firstWhere(
        (habit) => habit?.id == id,
        orElse: () => null,
      );
      
      return foundHabit;
    } catch (e) {
      throw StorageException('Failed to get habit by ID: $e');
    }
  }

  @override
  Future<void> saveHabit(Habit habit) async {
    try {
      
      // Validate habit before saving
      final validationResult = HabitValidator.validate(habit);
      if (!validationResult.isValid) {
        throw ValidationException('Invalid habit data: ${validationResult.errors.join(', ')}');
      }

      final habitModel = HabitModel.fromDomain(habit);
      
      await _localDataSource.saveHabit(habitModel);
    } catch (e) {
      if (e is ValidationException) rethrow;
      throw StorageException('Failed to save habit: $e');
    }
  }

  @override
  Future<void> saveHabits(List<Habit> habits) async {
    try {
      for (final habit in habits) {
        final validationResult = HabitValidator.validate(habit);
        if (!validationResult.isValid) {
          throw ValidationException('Invalid habit data: ${validationResult.errors.join(', ')}');
        }
      }
      await _localDataSource.saveHabits([for (final habit in habits) HabitModel.fromDomain(habit)]);
    } catch (e) {
      if (e is ValidationException) rethrow;
      throw StorageException('Failed to save habits: $e');
    }
  }

  @override
  Future<void> deleteHabit(String id) async {
    try {
      await _localDataSource.deleteHabit(id);
    } catch (e) {
      if (e is StorageException) rethrow;
      throw StorageException('Failed to delete habit: $e');
    }
  }
}
