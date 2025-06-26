# Unified Data Model Specification

## Overview
Define a comprehensive, cross-platform data model that supports both web and Flutter implementations while optimizing for iOS excellence.

## Current Data Model Analysis

### Web Application Data Structure
```javascript
// Current web habit structure
{
  id: "habit_water_default",
  name: "Drink Water",
  progress: 5,
  target: 8,
  color: "#2196F3",
  category: "Body",
  lastUpdatedDate: "2024-01-15T10:30:00.000Z",
  resetFrequency: "weekly",
  history: {
    "2024-01-15": 5,
    "2024-01-14": 8,
    "2024-01-13": 3
  },
  streak: 12,
  lastStreakDate: "2024-01-15",
  reminderTime: "08:00",
  reminderEnabled: true
}
```

### Flutter Application Current Structure
```dart
// Current Flutter habit structure (limited)
class Habit {
  final String id;
  final String name;
  final int progress;
  final int target;
  final Color color;
  // Missing: category, history, streak, reminders, etc.
}
```

## Proposed Unified Data Model

### Core Habit Entity
```dart
// Unified habit data structure
class Habit {
  final String id;
  final String name;
  final int progress;
  final int target;
  final HabitColor color;
  final HabitCategory category;
  final DateTime lastUpdatedDate;
  final ResetFrequency resetFrequency;
  final Map<DateTime, int> history;
  final StreakData streak;
  final ReminderSettings? reminder;
  final HabitMetadata metadata;
  
  const Habit({
    required this.id,
    required this.name,
    required this.progress,
    required this.target,
    required this.color,
    required this.category,
    required this.lastUpdatedDate,
    required this.resetFrequency,
    required this.history,
    required this.streak,
    this.reminder,
    required this.metadata,
  });
}
```

### Supporting Data Structures

#### HabitColor
```dart
class HabitColor {
  final int value;
  final String hex;
  final String name;
  
  const HabitColor({
    required this.value,
    required this.hex,
    required this.name,
  });
  
  // Predefined colors for consistency
  static const blue = HabitColor(value: 0xFF2196F3, hex: "#2196F3", name: "Blue");
  static const green = HabitColor(value: 0xFF4CAF50, hex: "#4CAF50", name: "Green");
  // ... other predefined colors
}
```

#### HabitCategory
```dart
enum HabitCategory {
  body("Body", "💪", 0xFF2196F3),
  spirit("Spirit", "🙏", 0xFF9C27B0),
  mind("Mind", "🧠", 0xFF00BCD4),
  social("Social", "👥", 0xFF4CAF50),
  career("Career", "💼", 0xFFFF9800),
  creative("Creative", "🎨", 0xFFE91E63);
  
  const HabitCategory(this.displayName, this.emoji, this.defaultColor);
  
  final String displayName;
  final String emoji;
  final int defaultColor;
}
```

#### StreakData
```dart
class StreakData {
  final int current;
  final int longest;
  final DateTime? lastUpdateDate;
  final List<StreakPeriod> history;
  
  const StreakData({
    required this.current,
    required this.longest,
    this.lastUpdateDate,
    required this.history,
  });
}

class StreakPeriod {
  final DateTime startDate;
  final DateTime? endDate;
  final int length;
  
  const StreakPeriod({
    required this.startDate,
    this.endDate,
    required this.length,
  });
}
```

#### ReminderSettings
```dart
class ReminderSettings {
  final TimeOfDay time;
  final bool enabled;
  final List<int> daysOfWeek; // 1-7, Monday-Sunday
  final String? customMessage;
  
  const ReminderSettings({
    required this.time,
    required this.enabled,
    required this.daysOfWeek,
    this.customMessage,
  });
}
```

#### ResetFrequency
```dart
enum ResetFrequency {
  daily("Daily", Duration(days: 1)),
  weekly("Weekly", Duration(days: 7)),
  monthly("Monthly", Duration(days: 30)),
  never("Never", null);
  
  const ResetFrequency(this.displayName, this.duration);
  
  final String displayName;
  final Duration? duration;
}
```

#### HabitMetadata
```dart
class HabitMetadata {
  final DateTime createdDate;
  final DateTime lastModifiedDate;
  final int version;
  final String? icon;
  final Map<String, dynamic> customFields;
  
  const HabitMetadata({
    required this.createdDate,
    required this.lastModifiedDate,
    required this.version,
    this.icon,
    required this.customFields,
  });
}
```

## JSON Serialization Schema

### Habit JSON Structure
```json
{
  "id": "habit_water_2024_001",
  "name": "Drink Water",
  "progress": 5,
  "target": 8,
  "color": {
    "value": 4283215587,
    "hex": "#2196F3",
    "name": "Blue"
  },
  "category": "body",
  "lastUpdatedDate": "2024-01-15T10:30:00.000Z",
  "resetFrequency": "weekly",
  "history": {
    "2024-01-15": 5,
    "2024-01-14": 8,
    "2024-01-13": 3
  },
  "streak": {
    "current": 12,
    "longest": 25,
    "lastUpdateDate": "2024-01-15T10:30:00.000Z",
    "history": [
      {
        "startDate": "2024-01-01T00:00:00.000Z",
        "endDate": null,
        "length": 12
      }
    ]
  },
  "reminder": {
    "time": "08:00",
    "enabled": true,
    "daysOfWeek": [1, 2, 3, 4, 5],
    "customMessage": "Time to hydrate!"
  },
  "metadata": {
    "createdDate": "2024-01-01T00:00:00.000Z",
    "lastModifiedDate": "2024-01-15T10:30:00.000Z",
    "version": 2,
    "icon": "droplet",
    "customFields": {}
  }
}
```

## Data Validation Rules

### Required Fields Validation
```dart
class HabitValidator {
  static ValidationResult validate(Habit habit) {
    final errors = <String>[];
    
    // Name validation
    if (habit.name.trim().isEmpty) {
      errors.add("Habit name cannot be empty");
    }
    if (habit.name.length > 50) {
      errors.add("Habit name cannot exceed 50 characters");
    }
    
    // Progress/Target validation
    if (habit.target <= 0) {
      errors.add("Target must be greater than 0");
    }
    if (habit.progress < 0 || habit.progress > habit.target) {
      errors.add("Progress must be between 0 and target");
    }
    
    // Date validation
    if (habit.lastUpdatedDate.isAfter(DateTime.now())) {
      errors.add("Last updated date cannot be in the future");
    }
    
    return ValidationResult(isValid: errors.isEmpty, errors: errors);
  }
}
```

### Business Logic Validation
```dart
class HabitBusinessRules {
  // Streak calculation rules
  static StreakData calculateStreak(Map<DateTime, int> history, int target) {
    // Implementation for consistent streak calculation
  }
  
  // Progress reset rules
  static bool shouldResetProgress(Habit habit, DateTime currentDate) {
    // Implementation for reset frequency logic
  }
  
  // Completion status rules
  static bool isCompleted(int progress, int target) {
    return progress >= target;
  }
}
```

## Storage Format Optimization

### Web localStorage Format
```javascript
// Optimized for web localStorage limitations
const webStorageFormat = {
  habits: {
    "habit_id_1": { /* compressed habit data */ },
    "habit_id_2": { /* compressed habit data */ }
  },
  metadata: {
    version: "2.0.0",
    lastSync: "2024-01-15T10:30:00.000Z",
    totalHabits: 2
  }
};
```

### Flutter SharedPreferences Format
```dart
// Optimized for Flutter SharedPreferences
class HabitStorageFormat {
  static const String habitsKey = 'atomic_momentum_habits';
  static const String metadataKey = 'atomic_momentum_metadata';
  
  // Store as compressed JSON string
  static Future<void> saveHabits(List<Habit> habits) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(habits.map((h) => h.toJson()).toList());
    await prefs.setString(habitsKey, json);
  }
}
```

## Version Management

### Schema Versioning
```dart
class SchemaVersion {
  static const current = "2.0.0";
  
  // Version migration mappings
  static final migrations = {
    "1.0.0": _migrateFrom1_0_0,
    "1.1.0": _migrateFrom1_1_0,
  };
  
  static Habit _migrateFrom1_0_0(Map<String, dynamic> oldData) {
    // Migration logic from version 1.0.0
  }
}
```

### Backward Compatibility
```dart
class DataMigration {
  // Ensure older data formats can be read
  static Habit fromLegacyJson(Map<String, dynamic> json) {
    // Handle legacy data structures
    final version = json['version'] ?? "1.0.0";
    
    switch (version) {
      case "1.0.0":
        return _fromV1_0_0(json);
      case "1.1.0":
        return _fromV1_1_0(json);
      default:
        return Habit.fromJson(json);
    }
  }
}
```

## Cross-Platform Compatibility

### Type Mapping
```dart
// Ensure consistent types across platforms
class CrossPlatformTypes {
  // DateTime handling
  static DateTime fromISOString(String iso) => DateTime.parse(iso);
  static String toISOString(DateTime date) => date.toIso8601String();
  
  // Color handling
  static int colorToInt(Color color) => color.value;
  static Color colorFromInt(int value) => Color(value);
  
  // Duration handling for TimeOfDay
  static String timeOfDayToString(TimeOfDay time) => 
    "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  static TimeOfDay timeOfDayFromString(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
}
```

## Performance Optimizations

### Data Loading Strategy
```dart
class HabitDataLoader {
  // Lazy loading for large datasets
  static Future<List<Habit>> loadHabitsAsync({
    int? limit,
    DateTime? since,
    HabitCategory? category,
  }) async {
    // Implement efficient loading with filtering
  }
  
  // Cached access for frequently used data
  static final Map<String, Habit> _cache = {};
  
  static Habit? getCachedHabit(String id) => _cache[id];
  static void cacheHabit(Habit habit) => _cache[habit.id] = habit;
}
```

### Memory Management
```dart
class HabitMemoryManager {
  // Clean up old history data
  static Map<DateTime, int> pruneHistory(
    Map<DateTime, int> history, {
    int maxDays = 365,
  }) {
    final cutoffDate = DateTime.now().subtract(Duration(days: maxDays));
    return Map.fromEntries(
      history.entries.where((entry) => entry.key.isAfter(cutoffDate)),
    );
  }
}
```

## Implementation Timeline

### Phase 1: Core Model (1 week)
- Define unified Habit class
- Implement supporting data structures
- Create validation system

### Phase 2: Serialization (1 week)
- JSON serialization/deserialization
- Cross-platform type mapping
- Version management system

### Phase 3: Storage Integration (1 week)
- Web localStorage adapter
- Flutter SharedPreferences adapter
- Performance optimization

### Phase 4: Migration System (1 week)
- Legacy data migration
- Version upgrade handling
- Data validation and cleanup

**Total Estimated Time: 4 weeks**