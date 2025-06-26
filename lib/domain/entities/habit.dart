import 'package:equatable/equatable.dart';
import 'habit_category.dart';
import 'habit_color.dart';
import 'reset_frequency.dart';
import 'streak_data.dart';
import 'reminder_settings.dart';
import 'habit_metadata.dart';

class Habit extends Equatable {
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

  factory Habit.create({
    required String name,
    required int target,
    required HabitColor color,
    required HabitCategory category,
    ResetFrequency resetFrequency = ResetFrequency.daily,
    ReminderSettings? reminder,
    String? icon,
  }) {
    final now = DateTime.now();
    final id = 'habit_${DateTime.now().millisecondsSinceEpoch}';
    
    return Habit(
      id: id,
      name: name,
      progress: 0,
      target: target,
      color: color,
      category: category,
      lastUpdatedDate: now,
      resetFrequency: resetFrequency,
      history: {},
      streak: StreakData.empty(),
      reminder: reminder,
      metadata: HabitMetadata.create(icon: icon),
    );
  }

  bool get isCompleted => progress >= target;
  
  double get progressPercentage => target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0;
  
  bool get hasReminder => reminder != null && reminder!.enabled;

  bool shouldReset(DateTime currentDate) {
    return resetFrequency.shouldReset(lastUpdatedDate, currentDate);
  }

  Habit updateProgress(int newProgress) {
    if (newProgress < 0 || newProgress > target) {
      throw ArgumentError('Progress must be between 0 and $target');
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Update history
    final newHistory = Map<DateTime, int>.from(history);
    newHistory[today] = newProgress;
    
    // Update streak based on completion
    final wasCompleted = isCompleted;
    final willBeCompleted = newProgress >= target;
    final newStreak = streak.updateStreak(
      date: today,
      completed: willBeCompleted,
    );

    return copyWith(
      progress: newProgress,
      lastUpdatedDate: now,
      history: newHistory,
      streak: newStreak,
      metadata: metadata.updateModifiedDate(),
    );
  }

  Habit incrementProgress([int amount = 1]) {
    return updateProgress((progress + amount).clamp(0, target));
  }

  Habit decrementProgress([int amount = 1]) {
    return updateProgress((progress - amount).clamp(0, target));
  }

  Habit resetProgress() {
    final now = DateTime.now();
    return copyWith(
      progress: 0,
      lastUpdatedDate: now,
      metadata: metadata.updateModifiedDate(),
    );
  }

  Habit updateDetails({
    String? name,
    int? target,
    HabitColor? color,
    HabitCategory? category,
    ResetFrequency? resetFrequency,
    ReminderSettings? reminder,
    String? icon,
  }) {
    return copyWith(
      name: name ?? this.name,
      target: target ?? this.target,
      color: color ?? this.color,
      category: category ?? this.category,
      resetFrequency: resetFrequency ?? this.resetFrequency,
      reminder: reminder ?? this.reminder,
      lastUpdatedDate: DateTime.now(),
      metadata: metadata.copyWith(
        icon: icon ?? metadata.icon,
        lastModifiedDate: DateTime.now(),
      ).incrementVersion(),
    );
  }

  int getProgressForDate(DateTime date) {
    final targetDate = DateTime(date.year, date.month, date.day);
    return history[targetDate] ?? 0;
  }

  bool wasCompletedOnDate(DateTime date) {
    return getProgressForDate(date) >= target;
  }

  List<DateTime> getCompletedDates() {
    return history.entries
        .where((entry) => entry.value >= target)
        .map((entry) => entry.key)
        .toList()
      ..sort();
  }

  Map<DateTime, int> getHistoryForMonth(int year, int month) {
    return Map.fromEntries(
      history.entries.where((entry) {
        final date = entry.key;
        return date.year == year && date.month == month;
      }),
    );
  }

  Habit copyWith({
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
    return Habit(
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

  Map<String, dynamic> toJson() {
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
    };
  }

  factory Habit.fromJson(Map<String, dynamic> json) {
    final historyMap = <DateTime, int>{};
    (json['history'] as Map<String, dynamic>).forEach((key, value) {
      historyMap[DateTime.parse(key)] = value as int;
    });

    return Habit(
      id: json['id'] as String,
      name: json['name'] as String,
      progress: json['progress'] as int,
      target: json['target'] as int,
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

  @override
  List<Object?> get props => [
        id,
        name,
        progress,
        target,
        color,
        category,
        lastUpdatedDate,
        resetFrequency,
        history,
        streak,
        reminder,
        metadata,
      ];

  @override
  String toString() => 'Habit(id: $id, name: $name, progress: $progress/$target)';
}