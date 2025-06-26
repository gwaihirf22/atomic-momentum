import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_habit_datasource.dart';
import '../models/habit_model.dart';
import '../../core/exceptions/storage_exceptions.dart';

class SharedPreferencesDataSource implements LocalHabitDataSource {
  final SharedPreferences _prefs;
  
  static const String _habitsKey = 'atomic_momentum_habits_v2';
  static const String _metadataKey = 'atomic_momentum_metadata_v2';
  static const String _legacyHabitsKey = 'atomic_momentum_habits'; // For migration
  
  const SharedPreferencesDataSource(this._prefs);

  @override
  Future<List<HabitModel>> getHabits() async {
    try {
      final habitsJson = _prefs.getString(_habitsKey);
      
      if (habitsJson == null || habitsJson.isEmpty) {
        // Check for legacy data
        return await _migrateLegacyData();
      }

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
      
      await saveHabits(habits);
    } catch (e) {
      throw StorageException('Failed to save habit: $e');
    }
  }

  @override
  Future<void> saveHabits(List<HabitModel> habits) async {
    try {
      // Validate habits before saving
      final validHabits = habits.where((habit) => habit.isValid()).toList();
      
      if (validHabits.length != habits.length) {
        final invalidCount = habits.length - validHabits.length;
        print('Warning: Filtered out $invalidCount invalid habits during save');
      }

      final habitsJson = jsonEncode(
        validHabits.map((habit) => habit.toCompactJson()).toList(),
      );
      
      final success = await _prefs.setString(_habitsKey, habitsJson);
      if (!success) {
        throw StorageException('Failed to write habits to storage');
      }

      // Update metadata
      await _updateStorageMetadata(validHabits.length);
      
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
      
      await saveHabits(filteredHabits);
    } catch (e) {
      throw StorageException('Failed to delete habit: $e');
    }
  }

  @override
  Future<void> deleteHabits(List<String> ids) async {
    try {
      final habits = await getHabits();
      final filteredHabits = habits.where((habit) => !ids.contains(habit.id)).toList();
      
      await saveHabits(filteredHabits);
    } catch (e) {
      throw StorageException('Failed to delete habits: $e');
    }
  }

  @override
  Future<bool> habitExists(String id) async {
    try {
      final habits = await getHabits();
      return habits.any((habit) => habit.id == id);
    } catch (e) {
      throw StorageException('Failed to check habit existence: $e');
    }
  }

  @override
  Future<void> clearAllHabits() async {
    try {
      await _prefs.remove(_habitsKey);
      await _prefs.remove(_metadataKey);
      await _prefs.remove(_legacyHabitsKey); // Clean up legacy data too
    } catch (e) {
      throw StorageException('Failed to clear all habits: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getStorageMetadata() async {
    try {
      final metadataJson = _prefs.getString(_metadataKey);
      
      if (metadataJson == null || metadataJson.isEmpty) {
        return _getDefaultMetadata();
      }

      return jsonDecode(metadataJson) as Map<String, dynamic>;
    } catch (e) {
      return _getDefaultMetadata();
    }
  }

  @override
  Future<void> saveStorageMetadata(Map<String, dynamic> metadata) async {
    try {
      final metadataJson = jsonEncode(metadata);
      await _prefs.setString(_metadataKey, metadataJson);
    } catch (e) {
      throw StorageException('Failed to save storage metadata: $e');
    }
  }

  @override
  Future<int> getStorageSize() async {
    try {
      final habitsData = _prefs.getString(_habitsKey) ?? '';
      final metadataData = _prefs.getString(_metadataKey) ?? '';
      
      return habitsData.length + metadataData.length;
    } catch (e) {
      return 0;
    }
  }

  @override
  Future<String> backupData() async {
    try {
      final habits = await getHabits();
      final metadata = await getStorageMetadata();
      
      final backupData = {
        'version': '2.0.0',
        'createdAt': DateTime.now().toIso8601String(),
        'metadata': metadata,
        'habits': habits.map((habit) => habit.toJson()).toList(),
        'habitCount': habits.length,
      };
      
      return jsonEncode(backupData);
    } catch (e) {
      throw StorageException('Failed to create backup: $e');
    }
  }

  @override
  Future<void> restoreData(String jsonData) async {
    try {
      final data = jsonDecode(jsonData) as Map<String, dynamic>;
      
      // Validate backup format
      if (!data.containsKey('habits') || !data.containsKey('version')) {
        throw StorageException('Invalid backup data format');
      }

      final habitsList = data['habits'] as List<dynamic>;
      final habits = habitsList
          .map((habitJson) => HabitModel.fromJson(habitJson as Map<String, dynamic>))
          .toList();

      // Clear existing data and restore
      await clearAllHabits();
      await saveHabits(habits);
      
      // Restore metadata if available
      if (data.containsKey('metadata')) {
        await saveStorageMetadata(data['metadata'] as Map<String, dynamic>);
      }
      
    } catch (e) {
      throw StorageException('Failed to restore data: $e');
    }
  }

  // Private helper methods

  Future<List<HabitModel>> _migrateLegacyData() async {
    try {
      final legacyData = _prefs.getString(_legacyHabitsKey);
      
      if (legacyData == null || legacyData.isEmpty) {
        return [];
      }

      // Try to parse legacy data
      final Map<String, dynamic> legacyHabits = jsonDecode(legacyData);
      final List<HabitModel> migratedHabits = [];

      for (final entry in legacyHabits.entries) {
        try {
          final habitData = entry.value as Map<String, dynamic>;
          habitData['id'] = entry.key; // Use the key as ID
          
          final habit = HabitModel.fromLegacyJson(habitData);
          migratedHabits.add(habit);
        } catch (e) {
          print('Warning: Failed to migrate habit ${entry.key}: $e');
        }
      }

      // Save migrated data in new format
      if (migratedHabits.isNotEmpty) {
        await saveHabits(migratedHabits);
        
        // Keep legacy data for safety (don't delete immediately)
        print('Migrated ${migratedHabits.length} habits from legacy format');
      }

      return migratedHabits;
    } catch (e) {
      print('Warning: Failed to migrate legacy data: $e');
      return [];
    }
  }

  Map<String, dynamic> _getDefaultMetadata() {
    return {
      'version': '2.0.0',
      'createdAt': DateTime.now().toIso8601String(),
      'lastUpdated': DateTime.now().toIso8601String(),
      'habitCount': 0,
      'totalOperations': 0,
    };
  }

  Future<void> _updateStorageMetadata(int habitCount) async {
    try {
      final metadata = await getStorageMetadata();
      
      metadata['lastUpdated'] = DateTime.now().toIso8601String();
      metadata['habitCount'] = habitCount;
      metadata['totalOperations'] = (metadata['totalOperations'] as int? ?? 0) + 1;
      
      await saveStorageMetadata(metadata);
    } catch (e) {
      // Non-critical operation, don't throw
      print('Warning: Failed to update storage metadata: $e');
    }
  }

  // Additional utility methods for debugging and maintenance

  Future<void> cleanupStorage() async {
    try {
      final habits = await getHabits();
      final validHabits = habits.where((habit) => habit.isValid()).toList();
      
      if (validHabits.length != habits.length) {
        await saveHabits(validHabits);
        print('Cleaned up storage: removed ${habits.length - validHabits.length} invalid habits');
      }
    } catch (e) {
      print('Warning: Failed to cleanup storage: $e');
    }
  }

  Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final habits = await getHabits();
      final metadata = await getStorageMetadata();
      final storageSize = await getStorageSize();
      
      return {
        'habitCount': habits.length,
        'storageSize': storageSize,
        'lastUpdated': metadata['lastUpdated'],
        'version': metadata['version'],
        'totalOperations': metadata['totalOperations'],
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}