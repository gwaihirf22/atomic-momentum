import '../models/habit_model.dart';

abstract class LocalHabitDataSource {
  /// Get all habits from local storage
  Future<List<HabitModel>> getHabits();
  
  /// Save a habit to local storage
  Future<void> saveHabit(HabitModel habit);
  
  /// Save multiple habits to local storage
  Future<void> saveHabits(List<HabitModel> habits);
  
  /// Delete a habit from local storage
  Future<void> deleteHabit(String id);
  
  /// Delete multiple habits from local storage
  Future<void> deleteHabits(List<String> ids);
  
  /// Check if a habit exists in local storage
  Future<bool> habitExists(String id);
  
  /// Clear all habits from local storage
  Future<void> clearAllHabits();
  
  /// Get storage metadata (version, last sync, etc.)
  Future<Map<String, dynamic>> getStorageMetadata();
  
  /// Save storage metadata
  Future<void> saveStorageMetadata(Map<String, dynamic> metadata);
  
  /// Get storage size information
  Future<int> getStorageSize();
  
  /// Backup all data as JSON string
  Future<String> backupData();
  
  /// Restore data from JSON string
  Future<void> restoreData(String jsonData);
}