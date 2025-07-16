import 'dart:convert';
import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_category.dart';
import '../../domain/entities/habit_color.dart';
import '../../domain/entities/reset_frequency.dart';
import '../../domain/entities/streak_data.dart';
import '../../domain/entities/reminder_settings.dart';
import '../../domain/entities/habit_metadata.dart';

class HabitModel extends Habit {
  const HabitModel({
    required super.id,
    required super.name,
    required super.progress,
    required super.target,
    required super.color,
    required super.category,
    required super.lastUpdatedDate,
    required super.resetFrequency,
    required super.history,
    required super.streak,
    super.reminder,
    required super.metadata,
  });

  /// Create HabitModel from domain Habit entity
  factory HabitModel.fromDomain(Habit habit) {
    try {
      print('DEBUG: HabitModel.fromDomain() - Converting habit: ${habit.name} (${habit.progress}/${habit.target}) isCompleted: ${habit.isCompleted}');
      
      return HabitModel(
        id: habit.id,
        name: habit.name,
        progress: habit.progress,
        target: habit.target,
        color: habit.color,
        category: habit.category,
        lastUpdatedDate: habit.lastUpdatedDate,
        resetFrequency: habit.resetFrequency,
        history: habit.history,
        streak: habit.streak,
        reminder: habit.reminder,
        metadata: habit.metadata,
      );
    } catch (e) {
      print('DEBUG: HabitModel.fromDomain() - ERROR: $e');
      rethrow;
    }
  }

  /// Convert to domain Habit entity
  Habit toDomain() {
    try {
      print('DEBUG: HabitModel.toDomain() - Converting model: $name ($progress/$target)');
      
      final habitDomain = Habit(
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
      
      print('DEBUG: HabitModel.toDomain() - Successfully converted: ${habitDomain.name} isCompleted: ${habitDomain.isCompleted}');
      return habitDomain;
    } catch (e) {
      print('DEBUG: HabitModel.toDomain() - ERROR: $e');
      rethrow;
    }
  }

  /// Create from JSON with enhanced error handling
  factory HabitModel.fromJson(Map<String, dynamic> json) {
    try {
      return HabitModel._fromJsonInternal(json);
    } catch (e) {
      throw HabitModelException('Failed to parse habit from JSON: $e');
    }
  }

  static HabitModel _fromJsonInternal(Map<String, dynamic> json) {
    // Validate required fields
    _validateRequiredFields(json);

    // Parse history with error handling
    final historyMap = <DateTime, int>{};
    final historyJson = json['history'] as Map<String, dynamic>? ?? {};
    
    historyJson.forEach((key, value) {
      try {
        final date = DateTime.parse(key);
        final progress = (value as num).toInt();
        historyMap[date] = progress;
      } catch (e) {
        // Skip invalid history entries rather than failing completely
        print('Warning: Skipping invalid history entry: $key -> $value');
      }
    });

    return HabitModel(
      id: json['id'] as String,
      name: json['name'] as String,
      progress: (json['progress'] as num).toInt(),
      target: (json['target'] as num).toInt(),
      color: HabitColor.fromJson(json['color'] as Map<String, dynamic>),
      category: HabitCategory.fromString(json['category'] as String),
      lastUpdatedDate: DateTime.parse(json['lastUpdatedDate'] as String),
      resetFrequency: ResetFrequency.fromString(json['resetFrequency'] as String),
      history: historyMap,
      streak: StreakData.fromJson(json['streak'] as Map<String, dynamic>),
      reminder: json['reminder'] != null
          ? ReminderSettings.fromJson(json['reminder'] as Map<String, dynamic>)
          : null,
      metadata: HabitMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
    );
  }

  static void _validateRequiredFields(Map<String, dynamic> json) {
    final requiredFields = [
      'id', 'name', 'progress', 'target', 'color', 'category',
      'lastUpdatedDate', 'resetFrequency', 'streak', 'metadata'
    ];

    for (final field in requiredFields) {
      if (!json.containsKey(field) || json[field] == null) {
        throw HabitModelException('Missing required field: $field');
      }
    }
  }

  /// Enhanced JSON serialization
  @override
  Map<String, dynamic> toJson() {
    try {
      return {
        'id': id,
        'name': name,
        'progress': progress,
        'target': target,
        'color': color.toJson(),
        'category': category.name,
        'lastUpdatedDate': lastUpdatedDate.toIso8601String(),
        'resetFrequency': resetFrequency.name,
        'history': history.map((key, value) => MapEntry(key.toIso8601String(), value)),
        'streak': streak.toJson(),
        'reminder': reminder?.toJson(),
        'metadata': metadata.toJson(),
        '_version': '2.0.0', // Add version for future migrations
        '_serializedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw HabitModelException('Failed to serialize habit to JSON: $e');
    }
  }

  /// Create compact JSON for storage efficiency
  Map<String, dynamic> toCompactJson() {
    final json = toJson();
    
    // Remove optional null fields
    json.removeWhere((key, value) => value == null);
    
    // Compress history for storage efficiency
    if (history.isNotEmpty) {
      json['history'] = _compressHistory(history);
    } else {
      json.remove('history');
    }
    
    return json;
  }

  Map<String, dynamic> _compressHistory(Map<DateTime, int> history) {
    // Only keep last 90 days of history for storage efficiency
    final cutoffDate = DateTime.now().subtract(const Duration(days: 90));
    
    return Map.fromEntries(
      history.entries
          .where((entry) => entry.key.isAfter(cutoffDate))
          .map((entry) => MapEntry(entry.key.toIso8601String(), entry.value)),
    );
  }

  /// Create from legacy JSON format (for migration)
  factory HabitModel.fromLegacyJson(Map<String, dynamic> json) {
    // Handle old web app format
    if (json.containsKey('lastUpdatedDate') && json['lastUpdatedDate'] is! String) {
      // Convert legacy date format if needed
      json['lastUpdatedDate'] = DateTime.now().toIso8601String();
    }

    // Add missing fields with defaults
    json.putIfAbsent('resetFrequency', () => 'daily');
    json.putIfAbsent('history', () => <String, dynamic>{});
    json.putIfAbsent('streak', () => StreakData.empty().toJson());
    json.putIfAbsent('metadata', () => HabitMetadata.create().toJson());

    // Convert color if it's just a hex string
    if (json['color'] is String) {
      json['color'] = HabitColor.fromHex(json['color'] as String).toJson();
    }

    return HabitModel.fromJson(json);
  }

  /// Validate model integrity
  bool isValid() {
    try {
      if (id.isEmpty || name.trim().isEmpty) return false;
      if (target <= 0 || progress < 0) return false;
      if (lastUpdatedDate.isAfter(DateTime.now().add(const Duration(hours: 1)))) return false;
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Create a copy with updated fields
  HabitModel copyWithModel({
    String? id,
    String? name,
    int? progress,
    int? target,
    HabitColor? color,
    HabitCategory? category,
    DateTime? lastUpdatedDate,
    ResetFrequency? resetFrequency,
    Map<DateTime, int>? history,
    StreakData? streak,
    ReminderSettings? reminder,
    HabitMetadata? metadata,
  }) {
    return HabitModel(
      id: id ?? this.id,
      name: name ?? this.name,
      progress: progress ?? this.progress,
      target: target ?? this.target,
      color: color ?? this.color,
      category: category ?? this.category,
      lastUpdatedDate: lastUpdatedDate ?? this.lastUpdatedDate,
      resetFrequency: resetFrequency ?? this.resetFrequency,
      history: history ?? this.history,
      streak: streak ?? this.streak,
      reminder: reminder ?? this.reminder,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() => 'HabitModel(id: $id, name: $name, progress: $progress/$target)';
}

class HabitModelException implements Exception {
  final String message;
  const HabitModelException(this.message);
  
  @override
  String toString() => 'HabitModelException: $message';
}

/// Utility class for batch operations on HabitModels
class HabitModelUtils {
  /// Convert list of domain habits to models
  static List<HabitModel> fromDomainList(List<Habit> habits) {
    return habits.map((habit) => HabitModel.fromDomain(habit)).toList();
  }

  /// Convert list of models to domain habits
  static List<Habit> toDomainList(List<HabitModel> models) {
    return models.map((model) => model.toDomain()).toList();
  }

  /// Validate a list of habit models
  static List<HabitModel> validateList(List<HabitModel> models) {
    return models.where((model) => model.isValid()).toList();
  }

  /// Serialize list to JSON string
  static String serializeList(List<HabitModel> models) {
    final data = {
      'habits': models.map((model) => model.toJson()).toList(),
      'version': '2.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'count': models.length,
    };
    
    return jsonEncode(data);
  }

  /// Deserialize list from JSON string
  static List<HabitModel> deserializeList(String jsonString) {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final habitsList = data['habits'] as List<dynamic>;
      
      return habitsList
          .map((habitJson) => HabitModel.fromJson(habitJson as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw HabitModelException('Failed to deserialize habits list: $e');
    }
  }
}