import 'dart:convert';
import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_category.dart';
import '../../domain/entities/habit_color.dart';
import '../../domain/entities/reset_frequency.dart';
import '../../domain/entities/streak_data.dart';
import '../../domain/entities/reminder_settings.dart';
import '../../domain/entities/habit_metadata.dart';
import '../exceptions/storage_exceptions.dart';

class DataMigration {
  static const String currentVersion = '2.0.0';
  
  static final Map<String, MigrationFunction> _migrations = {
    '1.0.0': _migrateFromV1_0_0,
    '1.1.0': _migrateFromV1_1_0,
    '1.2.0': _migrateFromV1_2_0,
  };

  /// Migrate data from any legacy format to current format
  static List<Habit> migrateData(String jsonData, {String? sourceVersion}) {
    try {
      final data = jsonDecode(jsonData);
      
      // Detect format and version
      final detectedVersion = _detectDataVersion(data);
      final version = sourceVersion ?? detectedVersion;
      
      if (version == currentVersion) {
        // Already current version, just parse normally
        return _parseCurrentVersion(data);
      }
      
      // Apply migration
      final migrationFunction = _migrations[version];
      if (migrationFunction == null) {
        throw DataMigrationException('Unsupported migration from version $version');
      }
      
      return migrationFunction(data);
    } catch (e) {
      if (e is DataMigrationException) rethrow;
      throw DataMigrationException('Failed to migrate data: $e');
    }
  }

  /// Detect the version of the data format
  static String _detectDataVersion(dynamic data) {
    if (data is Map<String, dynamic>) {
      // Check for version field
      if (data.containsKey('version')) {
        return data['version'] as String;
      }
      
      // Check for v2.0 structure (with habits array)
      if (data.containsKey('habits') && data['habits'] is List) {
        return '2.0.0';
      }
      
      // Check for v1.2 structure (individual habit objects with enhanced fields)
      if (data.values.any((value) => value is Map && value.containsKey('metadata'))) {
        return '1.2.0';
      }
      
      // Check for v1.1 structure (individual habit objects with streak)
      if (data.values.any((value) => value is Map && value.containsKey('streak'))) {
        return '1.1.0';
      }
      
      // Assume v1.0 (original web app format)
      return '1.0.0';
    }
    
    throw DataMigrationException('Unrecognized data format');
  }

  /// Parse current version data
  static List<Habit> _parseCurrentVersion(Map<String, dynamic> data) {
    if (data.containsKey('habits')) {
      final habitsList = data['habits'] as List<dynamic>;
      return habitsList
          .map((habitJson) => Habit.fromJson(habitJson as Map<String, dynamic>))
          .toList();
    }
    
    throw DataMigrationException('Invalid current version data format');
  }

  /// Migration from v1.0.0 (original web app format)
  static List<Habit> _migrateFromV1_0_0(Map<String, dynamic> data) {
    final habits = <Habit>[];
    
    for (final entry in data.entries) {
      if (entry.value is! Map<String, dynamic>) continue;
      
      try {
        final habitData = entry.value as Map<String, dynamic>;
        final habit = _createHabitFromV1_0_0(entry.key, habitData);
        habits.add(habit);
      } catch (e) {
        print('Warning: Failed to migrate habit ${entry.key}: $e');
      }
    }
    
    return habits;
  }

  static Habit _createHabitFromV1_0_0(String id, Map<String, dynamic> data) {
    // Extract basic fields with defaults
    final name = data['name'] as String? ?? 'Unnamed Habit';
    final progress = (data['progress'] as num?)?.toInt() ?? 0;
    final target = (data['target'] as num?)?.toInt() ?? 1;
    
    // Handle color - could be hex string or color object
    HabitColor color;
    if (data['color'] is String) {
      color = HabitColor.fromHex(data['color'] as String);
    } else if (data['color'] is Map) {
      color = HabitColor.fromJson(data['color'] as Map<String, dynamic>);
    } else {
      color = HabitColor.blue; // Default
    }
    
    // Handle category
    final categoryString = data['category'] as String? ?? 'body';
    final category = HabitCategory.fromString(categoryString);
    
    // Handle dates
    final lastUpdatedString = data['lastUpdatedDate'] as String?;
    final lastUpdatedDate = lastUpdatedString != null 
        ? DateTime.tryParse(lastUpdatedString) ?? DateTime.now()
        : DateTime.now();
    
    // Handle reset frequency
    final resetFrequencyString = data['resetFrequency'] as String? ?? 'weekly';
    final resetFrequency = ResetFrequency.fromString(resetFrequencyString);
    
    // Convert history if present
    final history = <DateTime, int>{};
    if (data['history'] is Map) {
      final historyData = data['history'] as Map<String, dynamic>;
      historyData.forEach((key, value) {
        try {
          final date = DateTime.parse(key);
          final progressValue = (value as num).toInt();
          history[date] = progressValue;
        } catch (e) {
          // Skip invalid history entries
        }
      });
    }
    
    // Create basic streak data (v1.0 didn't have detailed streaks)
    final streakValue = (data['streak'] as num?)?.toInt() ?? 0;
    final streak = StreakData(
      current: streakValue,
      longest: streakValue,
      lastUpdateDate: lastUpdatedDate,
      history: [],
    );
    
    // Handle reminders
    ReminderSettings? reminder;
    if (data['reminderEnabled'] == true && data['reminderTime'] is String) {
      try {
        final timeString = data['reminderTime'] as String;
        final timeParts = timeString.split(':');
        if (timeParts.length == 2) {
          final hour = int.parse(timeParts[0]);
          final minute = int.parse(timeParts[1]);
          reminder = ReminderSettings.daily(
            time: TimeOfDay(hour: hour, minute: minute),
            customMessage: data['customMessage'] as String?,
          );
        }
      } catch (e) {
        // Skip invalid reminder data
      }
    }
    
    // Create metadata
    final metadata = HabitMetadata.create();
    
    return Habit(
      id: id,
      name: name,
      progress: progress,
      target: target,
      color: color,
      category: category,
      lastUpdatedDate: lastUpdatedDate,
      resetFrequency: resetFrequency,
      history: history,
      streak: streak,
      reminder: reminder,
      metadata: metadata,
    );
  }

  /// Migration from v1.1.0 (added streak tracking)
  static List<Habit> _migrateFromV1_1_0(Map<String, dynamic> data) {
    final habits = <Habit>[];
    
    for (final entry in data.entries) {
      if (entry.value is! Map<String, dynamic>) continue;
      
      try {
        final habitData = entry.value as Map<String, dynamic>;
        
        // Start with v1.0 migration and enhance
        final baseHabit = _createHabitFromV1_0_0(entry.key, habitData);
        
        // Enhanced streak data
        StreakData streak = baseHabit.streak;
        if (habitData['streak'] is Map) {
          try {
            streak = StreakData.fromJson(habitData['streak'] as Map<String, dynamic>);
          } catch (e) {
            // Keep base streak if parsing fails
          }
        }
        
        final enhancedHabit = baseHabit.copyWith(streak: streak);
        habits.add(enhancedHabit);
      } catch (e) {
        print('Warning: Failed to migrate habit ${entry.key}: $e');
      }
    }
    
    return habits;
  }

  /// Migration from v1.2.0 (added metadata)
  static List<Habit> _migrateFromV1_2_0(Map<String, dynamic> data) {
    final habits = <Habit>[];
    
    for (final entry in data.entries) {
      if (entry.value is! Map<String, dynamic>) continue;
      
      try {
        final habitData = entry.value as Map<String, dynamic>;
        
        // Start with v1.1 migration
        final baseHabits = _migrateFromV1_1_0({entry.key: habitData});
        if (baseHabits.isEmpty) continue;
        
        final baseHabit = baseHabits.first;
        
        // Enhanced metadata
        HabitMetadata metadata = baseHabit.metadata;
        if (habitData['metadata'] is Map) {
          try {
            metadata = HabitMetadata.fromJson(habitData['metadata'] as Map<String, dynamic>);
          } catch (e) {
            // Keep base metadata if parsing fails
          }
        }
        
        final enhancedHabit = baseHabit.copyWith(metadata: metadata);
        habits.add(enhancedHabit);
      } catch (e) {
        print('Warning: Failed to migrate habit ${entry.key}: $e');
      }
    }
    
    return habits;
  }

  /// Validate migrated data
  static List<Habit> validateMigratedData(List<Habit> habits) {
    final validHabits = <Habit>[];
    
    for (final habit in habits) {
      try {
        // Basic validation
        if (habit.id.isEmpty || habit.name.trim().isEmpty) {
          print('Warning: Skipping habit with invalid ID or name');
          continue;
        }
        
        if (habit.target <= 0) {
          print('Warning: Fixing invalid target for habit ${habit.name}');
          final fixedHabit = habit.copyWith(target: 1);
          validHabits.add(fixedHabit);
          continue;
        }
        
        if (habit.progress < 0) {
          print('Warning: Fixing negative progress for habit ${habit.name}');
          final fixedHabit = habit.copyWith(progress: 0);
          validHabits.add(fixedHabit);
          continue;
        }
        
        validHabits.add(habit);
      } catch (e) {
        print('Warning: Skipping invalid habit: $e');
      }
    }
    
    return validHabits;
  }

  /// Create migration summary
  static Map<String, dynamic> createMigrationSummary(
    String sourceVersion,
    List<Habit> originalData,
    List<Habit> migratedData,
  ) {
    final skippedCount = originalData.length - migratedData.length;
    
    return {
      'sourceVersion': sourceVersion,
      'targetVersion': currentVersion,
      'originalCount': originalData.length,
      'migratedCount': migratedData.length,
      'skippedCount': skippedCount,
      'success': skippedCount < originalData.length * 0.1, // Allow 10% failure rate
      'migratedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Check if migration is needed
  static bool isMigrationNeeded(String jsonData) {
    try {
      final data = jsonDecode(jsonData);
      final version = _detectDataVersion(data);
      return version != currentVersion;
    } catch (e) {
      return true; // Assume migration needed if we can't parse
    }
  }

  /// Get supported migration versions
  static List<String> getSupportedVersions() {
    return [currentVersion, ..._migrations.keys];
  }
}

typedef MigrationFunction = List<Habit> Function(Map<String, dynamic> data);

/// Helper class for time-of-day handling during migration
class TimeOfDay {
  final int hour;
  final int minute;
  
  const TimeOfDay({required this.hour, required this.minute});
  
  @override
  String toString() => '$hour:${minute.toString().padLeft(2, '0')}';
}