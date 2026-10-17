import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_color.dart';
import '../../domain/entities/habit_goal.dart';
import '../../domain/entities/habit_notify.dart';
import '../../domain/entities/reset_frequency.dart';
import '../../domain/entities/streak_data.dart';
import '../../domain/entities/reminder_settings.dart';
import '../../domain/entities/habit_metadata.dart';
import '../../domain/entities/two_minute_version.dart';
import '../../core/logging/log.dart';
import 'package:clock/clock.dart';

class HabitModel extends Habit {
  HabitModel({
    required super.id,
    required super.name,
    required super.progress,
    required super.target,
    super.units,
    required super.color,
    required super.categoryId,
    required super.lastUpdatedDate,
    required super.resetFrequency,
    required super.history,
    required super.streak,
    super.reminder,
    required super.metadata,
    super.resetAnchorDate,
    super.resetInterval,
    super.scheduledWeekdays,
    super.twoMinute,
    super.twoMinuteDays,
    super.why,
    super.dayNotes,
    super.goal,
    super.notify,
  });

  /// Create HabitModel from domain Habit entity
  factory HabitModel.fromDomain(Habit habit) {
    try {
      
      return HabitModel(
        id: habit.id,
        name: habit.name,
        progress: habit.progress,
        target: habit.target,
        units: habit.units,
        color: habit.color,
        categoryId: habit.categoryId,
        lastUpdatedDate: habit.lastUpdatedDate,
        resetFrequency: habit.resetFrequency,
        history: habit.history,
        streak: habit.streak,
        reminder: habit.reminder,
        metadata: habit.metadata,
        resetAnchorDate: habit.resetAnchorDate,
        resetInterval: habit.resetInterval,
        scheduledWeekdays: habit.scheduledWeekdays,
        twoMinute: habit.twoMinute,
        twoMinuteDays: habit.twoMinuteDays,
        why: habit.why,
        dayNotes: habit.dayNotes,
        goal: habit.goal,
        notify: habit.notify,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Convert to domain Habit entity
  Habit toDomain() {
    try {
      
      final habitDomain = Habit(
        id: id,
        name: name,
        progress: progress,
        target: target,
        units: units,
        color: color,
        categoryId: categoryId,
        lastUpdatedDate: lastUpdatedDate,
        resetFrequency: resetFrequency,
        history: history,
        streak: streak,
        reminder: reminder,
        metadata: metadata,
        resetAnchorDate: resetAnchorDate,
        resetInterval: resetInterval,
        scheduledWeekdays: scheduledWeekdays,
        twoMinute: twoMinute,
        twoMinuteDays: twoMinuteDays,
        why: why,
        dayNotes: dayNotes,
        goal: goal,
        notify: notify,
      );
      
      return habitDomain;
    } catch (e) {
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
        logWarning('Warning: Skipping invalid history entry: $key -> $value');
      }
    });

    return HabitModel(
      id: json['id'] as String,
      name: json['name'] as String,
      progress: (json['progress'] as num).toInt(),
      target: (json['target'] as num).toInt(),
      units: json['units'] as String? ?? '',
      color: HabitColor.fromJson(json['color'] as Map<String, dynamic>),
      // Missing or unknown ids are kept/blank and show as Uncategorized
      categoryId: json['category'] is String ? json['category'] as String : '',
      lastUpdatedDate: DateTime.parse(json['lastUpdatedDate'] as String),
      resetFrequency: ResetFrequency.fromString(json['resetFrequency'] as String),
      history: historyMap,
      streak: StreakData.fromJson(json['streak'] as Map<String, dynamic>),
      reminder: json['reminder'] != null
          ? ReminderSettings.fromJson(json['reminder'] as Map<String, dynamic>)
          : null,
      metadata: HabitMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
      resetAnchorDate: json['resetAnchor'] != null
          ? DateTime.parse(json['resetAnchor'] as String)
          : null,
      resetInterval: (json['resetInterval'] as num?)?.toInt() ?? 1,
      scheduledWeekdays: (json['scheduledWeekdays'] as List<dynamic>?)?.cast<int>(),
      twoMinute: json['twoMinute'] is Map<String, dynamic>
          ? TwoMinuteVersion.fromJson(json['twoMinute'] as Map<String, dynamic>)
          : null,
      twoMinuteDays: Habit.twoMinuteDaysFromJson(json['twoMinuteDays']),
      why: json['why'] is String ? json['why'] as String : '',
      dayNotes: Habit.dayNotesFromJson(json['dayNotes']),
      goal: HabitGoal.fromJson(json['goal']),
      notify: HabitNotify.fromJson(json['notify']),
    );
  }

  static void _validateRequiredFields(Map<String, dynamic> json) {
    final requiredFields = [
      'id', 'name', 'progress', 'target', 'color',
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
        'units': units,
        'color': color.toJson(),
        'category': categoryId,
        'lastUpdatedDate': lastUpdatedDate.toIso8601String(),
        'resetFrequency': resetFrequency.name,
        'history': history.map((key, value) => MapEntry(key.toIso8601String(), value)),
        'streak': streak.toJson(),
        'reminder': reminder?.toJson(),
        'metadata': metadata.toJson(),
        'resetAnchor': resetAnchorDate?.toIso8601String(),
        'resetInterval': resetInterval,
        'scheduledWeekdays': scheduledWeekdays,
        'twoMinute': twoMinute?.toJson(),
        if (twoMinuteDays.isNotEmpty) 'twoMinuteDays': Habit.twoMinuteDaysToJson(twoMinuteDays),
        if (why.isNotEmpty) 'why': why,
        if (dayNotes.isNotEmpty) 'dayNotes': Habit.dayNotesToJson(dayNotes),
        if (goal != HabitGoal.build) 'goal': goal.name,
        if (!notify.isStandard) 'notify': notify.toJson(),
        '_version': '2.0.0', // Add version for future migrations
        '_serializedAt': clock.now().toIso8601String(),
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
    
    // Keep the full history: streaks are derived from it, so trimming old
    // days would silently shorten long streaks
    if (history.isEmpty) {
      json.remove('history');
    }
    
    return json;
  }

  /// Validate model integrity
  bool isValid() {
    try {
      if (id.isEmpty || name.trim().isEmpty) return false;
      // A habit to quit allows nothing (0); every other habit needs a target
      if (target < 0 || (target == 0 && goal != HabitGoal.quit) || progress < 0) return false;
      if (lastUpdatedDate.isAfter(clock.now().add(const Duration(hours: 1)))) return false;
      
      return true;
    } catch (e) {
      return false;
    }
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
