import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_category.dart';
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
      print('DEBUG: HabitRepository.getHabits() - Starting to fetch habits from data source');
      final habitModels = await _localDataSource.getHabits();
      print('DEBUG: HabitRepository.getHabits() - Got ${habitModels.length} habit models from data source');
      
      final habits = <Habit>[];
      for (int i = 0; i < habitModels.length; i++) {
        try {
          final habit = habitModels[i].toDomain();
          habits.add(habit);
          print('DEBUG: HabitRepository.getHabits() - Successfully converted habit ${i + 1}: ${habit.name} (${habit.progress}/${habit.target})');
        } catch (e) {
          print('DEBUG: HabitRepository.getHabits() - Failed to convert habit model ${i + 1}: $e');
          throw StorageException('Failed to convert habit model ${i + 1} to domain: $e');
        }
      }
      
      print('DEBUG: HabitRepository.getHabits() - Successfully returned ${habits.length} habits');
      return habits;
    } catch (e) {
      print('DEBUG: HabitRepository.getHabits() - ERROR: $e');
      throw StorageException('Failed to get habits: $e');
    }
  }

  @override
  Future<List<Habit>> getHabitsByCategory(HabitCategory category) async {
    try {
      final allHabits = await getHabits();
      return allHabits.where((habit) => habit.category == category).toList();
    } catch (e) {
      throw StorageException('Failed to get habits by category: $e');
    }
  }

  @override
  Future<Habit?> getHabitById(String id) async {
    try {
      print('DEBUG: HabitRepository.getHabitById() - Looking for habit with ID: $id');
      final habits = await getHabits();
      print('DEBUG: HabitRepository.getHabitById() - Got ${habits.length} habits, searching for ID: $id');
      
      final foundHabit = habits.cast<Habit?>().firstWhere(
        (habit) => habit?.id == id,
        orElse: () => null,
      );
      
      if (foundHabit != null) {
        print('DEBUG: HabitRepository.getHabitById() - Found habit: ${foundHabit.name} (${foundHabit.progress}/${foundHabit.target})');
      } else {
        print('DEBUG: HabitRepository.getHabitById() - Habit not found with ID: $id');
      }
      
      return foundHabit;
    } catch (e) {
      print('DEBUG: HabitRepository.getHabitById() - ERROR: $e');
      throw StorageException('Failed to get habit by ID: $e');
    }
  }

  @override
  Future<void> saveHabit(Habit habit) async {
    try {
      print('DEBUG: HabitRepository.saveHabit() - Saving habit: ${habit.name} (${habit.progress}/${habit.target}) isCompleted: ${habit.isCompleted}');
      
      // Validate habit before saving
      final validationResult = HabitValidator.validate(habit);
      if (!validationResult.isValid) {
        print('DEBUG: HabitRepository.saveHabit() - Validation failed: ${validationResult.errors}');
        throw ValidationException('Invalid habit data: ${validationResult.errors.join(', ')}');
      }
      print('DEBUG: HabitRepository.saveHabit() - Validation passed');

      print('DEBUG: HabitRepository.saveHabit() - Converting to HabitModel');
      final habitModel = HabitModel.fromDomain(habit);
      print('DEBUG: HabitRepository.saveHabit() - Converted to model, saving to data source');
      
      await _localDataSource.saveHabit(habitModel);
      print('DEBUG: HabitRepository.saveHabit() - Successfully saved habit to data source');
    } catch (e) {
      print('DEBUG: HabitRepository.saveHabit() - ERROR: $e');
      if (e is ValidationException) rethrow;
      throw StorageException('Failed to save habit: $e');
    }
  }

  @override
  Future<void> saveHabits(List<Habit> habits) async {
    try {
      // Validate all habits before saving
      final validationResult = HabitValidator.validateHabits(habits);
      if (!validationResult.isValid) {
        throw ValidationException('Invalid habits data: ${validationResult.errors.join(', ')}');
      }

      final habitModels = habits.map((habit) => HabitModel.fromDomain(habit)).toList();
      await _localDataSource.saveHabits(habitModels);
    } catch (e) {
      if (e is ValidationException) rethrow;
      throw StorageException('Failed to save habits: $e');
    }
  }

  @override
  Future<void> deleteHabit(String id) async {
    try {
      final exists = await habitExists(id);
      if (!exists) {
        throw StorageException('Habit with ID $id does not exist');
      }

      await _localDataSource.deleteHabit(id);
    } catch (e) {
      if (e is StorageException) rethrow;
      throw StorageException('Failed to delete habit: $e');
    }
  }

  @override
  Future<void> deleteHabits(List<String> ids) async {
    try {
      if (ids.isEmpty) return;

      // Verify all habits exist before deleting
      for (final id in ids) {
        final exists = await habitExists(id);
        if (!exists) {
          throw StorageException('Habit with ID $id does not exist');
        }
      }

      await _localDataSource.deleteHabits(ids);
    } catch (e) {
      if (e is StorageException) rethrow;
      throw StorageException('Failed to delete habits: $e');
    }
  }

  @override
  Future<void> updateHabitProgress(String id, int progress) async {
    try {
      final habit = await getHabitById(id);
      if (habit == null) {
        throw StorageException('Habit with ID $id not found');
      }

      final updatedHabit = habit.updateProgress(progress);
      await saveHabit(updatedHabit);
    } catch (e) {
      if (e is StorageException || e is ValidationException) rethrow;
      throw StorageException('Failed to update habit progress: $e');
    }
  }

  @override
  Future<Map<DateTime, int>> getHabitHistory(String id) async {
    try {
      final habit = await getHabitById(id);
      if (habit == null) {
        throw StorageException('Habit with ID $id not found');
      }

      return habit.history;
    } catch (e) {
      if (e is StorageException) rethrow;
      throw StorageException('Failed to get habit history: $e');
    }
  }

  @override
  Future<void> saveHabitHistory(String id, DateTime date, int progress) async {
    try {
      final habit = await getHabitById(id);
      if (habit == null) {
        throw StorageException('Habit with ID $id not found');
      }

      final updatedHistory = Map<DateTime, int>.from(habit.history);
      final targetDate = DateTime(date.year, date.month, date.day);
      updatedHistory[targetDate] = progress;

      final updatedHabit = habit.copyWith(
        history: updatedHistory,
        lastUpdatedDate: DateTime.now(),
        metadata: habit.metadata.updateModifiedDate(),
      );

      await saveHabit(updatedHabit);
    } catch (e) {
      if (e is StorageException || e is ValidationException) rethrow;
      throw StorageException('Failed to save habit history: $e');
    }
  }

  @override
  Future<void> clearAllHabits() async {
    try {
      await _localDataSource.clearAllHabits();
    } catch (e) {
      throw StorageException('Failed to clear all habits: $e');
    }
  }

  @override
  Future<int> getHabitCount() async {
    try {
      final habits = await getHabits();
      return habits.length;
    } catch (e) {
      throw StorageException('Failed to get habit count: $e');
    }
  }

  @override
  Future<bool> habitExists(String id) async {
    try {
      return await _localDataSource.habitExists(id);
    } catch (e) {
      throw StorageException('Failed to check habit existence: $e');
    }
  }

  @override
  Future<List<Habit>> getHabitsNeedingReset() async {
    try {
      final habits = await getHabits();
      final now = DateTime.now();
      
      return habits.where((habit) => habit.shouldReset(now)).toList();
    } catch (e) {
      throw StorageException('Failed to get habits needing reset: $e');
    }
  }

  @override
  Future<List<Habit>> getHabitsWithReminders() async {
    try {
      final habits = await getHabits();
      return habits.where((habit) => habit.hasReminder).toList();
    } catch (e) {
      throw StorageException('Failed to get habits with reminders: $e');
    }
  }

  @override
  Future<String> backupHabits() async {
    try {
      return await _localDataSource.backupData();
    } catch (e) {
      throw StorageException('Failed to backup habits: $e');
    }
  }

  @override
  Future<void> restoreHabits(String jsonData) async {
    try {
      await _localDataSource.restoreData(jsonData);
    } catch (e) {
      throw StorageException('Failed to restore habits: $e');
    }
  }

  // Additional utility methods for enhanced functionality

  Future<List<Habit>> getHabitsByCategories(List<HabitCategory> categories) async {
    try {
      final allHabits = await getHabits();
      return allHabits.where((habit) => categories.contains(habit.category)).toList();
    } catch (e) {
      throw StorageException('Failed to get habits by categories: $e');
    }
  }

  Future<List<Habit>> getCompletedHabitsForDate(DateTime date) async {
    try {
      final habits = await getHabits();
      return habits.where((habit) => habit.wasCompletedOnDate(date)).toList();
    } catch (e) {
      throw StorageException('Failed to get completed habits for date: $e');
    }
  }

  Future<List<Habit>> getActiveStreakHabits() async {
    try {
      final habits = await getHabits();
      return habits.where((habit) => habit.streak.current > 0).toList();
    } catch (e) {
      throw StorageException('Failed to get active streak habits: $e');
    }
  }

  Future<Map<HabitCategory, int>> getHabitCountByCategory() async {
    try {
      final habits = await getHabits();
      final countMap = <HabitCategory, int>{};
      
      for (final category in HabitCategory.values) {
        countMap[category] = habits.where((habit) => habit.category == category).length;
      }
      
      return countMap;
    } catch (e) {
      throw StorageException('Failed to get habit count by category: $e');
    }
  }

  Future<List<Habit>> searchHabits(String query) async {
    try {
      final habits = await getHabits();
      final lowercaseQuery = query.toLowerCase();
      
      return habits.where((habit) {
        return habit.name.toLowerCase().contains(lowercaseQuery) ||
               habit.category.displayName.toLowerCase().contains(lowercaseQuery);
      }).toList();
    } catch (e) {
      throw StorageException('Failed to search habits: $e');
    }
  }

  Future<void> resetHabitsIfNeeded() async {
    try {
      final habitsNeedingReset = await getHabitsNeedingReset();
      
      for (final habit in habitsNeedingReset) {
        final resetHabit = habit.resetProgress();
        await saveHabit(resetHabit);
      }
    } catch (e) {
      throw StorageException('Failed to reset habits: $e');
    }
  }

  Future<Map<String, dynamic>> getRepositoryStats() async {
    try {
      final habits = await getHabits();
      final habitsWithReminders = await getHabitsWithReminders();
      final activeStreaks = await getActiveStreakHabits();
      final categoryCount = await getHabitCountByCategory();
      
      return {
        'totalHabits': habits.length,
        'habitsWithReminders': habitsWithReminders.length,
        'activeStreaks': activeStreaks.length,
        'categoryCounts': categoryCount.map((key, value) => MapEntry(key.name, value)),
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw StorageException('Failed to get repository stats: $e');
    }
  }
}