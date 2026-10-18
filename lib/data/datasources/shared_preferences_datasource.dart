import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_habit_datasource.dart';
import '../models/habit_model.dart';
import '../../core/exceptions/storage_exceptions.dart';
import '../../core/logging/log.dart';

class SharedPreferencesDataSource implements LocalHabitDataSource {
  final SharedPreferences _prefs;
  
  static const String _habitsKey = 'atomic_momentum_habits_v2';

  /// Where habits are kept (for the developer tools that back them up).
  static const habitsKey = _habitsKey;
  
  const SharedPreferencesDataSource(this._prefs);

  @override
  Future<List<HabitModel>> getHabits() async {
    try {
      final habitsJson = _prefs.getString(_habitsKey);
      
      if (habitsJson == null || habitsJson.isEmpty) return [];

      final List<dynamic> habitsList = jsonDecode(habitsJson);
      return habitsList
          .map((habitJson) => HabitModel.fromJson(habitJson as Map<String, dynamic>))
          .where((habit) => habit.isValid()) // Filter out invalid habits
          .toList();
    } catch (e) {
      throw StorageException('Failed to load habits: $e');
    }
  }

  @override
  Future<void> saveHabit(HabitModel habit) async {
    try {
      final habits = await getHabits();
      
      // Update existing habit or add new one
      final existingIndex = habits.indexWhere((h) => h.id == habit.id);
      if (existingIndex >= 0) {
        habits[existingIndex] = habit;
      } else {
        habits.add(habit);
      }
      
      await _saveAll(habits);
    } catch (e) {
      throw StorageException('Failed to save habit: $e');
    }
  }

  /// Writes the whole list, dropping (and logging) any invalid habit.
  Future<void> _saveAll(List<HabitModel> habits) async {
    try {
      final validHabits = habits.where((habit) => habit.isValid()).toList();

      if (validHabits.length != habits.length) {
        final invalidCount = habits.length - validHabits.length;
        logWarning('Warning: Filtered out $invalidCount invalid habits during save');
      }

      final habitsJson = jsonEncode(
        validHabits.map((habit) => habit.toCompactJson()).toList(),
      );

      final success = await _prefs.setString(_habitsKey, habitsJson);
      if (!success) {
        throw StorageException('Failed to write habits to storage');
      }
    } catch (e) {
      throw StorageException('Failed to save habits: $e');
    }
  }

  @override
  Future<void> deleteHabit(String id) async {
    try {
      final habits = await getHabits();
      final filteredHabits = habits.where((habit) => habit.id != id).toList();
      
      if (filteredHabits.length == habits.length) {
        throw StorageException('Habit with ID $id not found');
      }
      
      await _saveAll(filteredHabits);
    } catch (e) {
      throw StorageException('Failed to delete habit: $e');
    }
  }
}
