import 'package:equatable/equatable.dart';
import 'habit_category.dart';
import 'habit_color.dart';
import 'reset_frequency.dart';
import 'streak_data.dart';
import 'reminder_settings.dart';
import 'habit_metadata.dart';
import '../services/streak_calculator.dart';

class Habit extends Equatable {
  final String id;
  final String name;
  final int progress;
  final int target;
  final String units; // Units for the target (e.g., "glasses", "minutes", "reps")
  final HabitColor color;
  final HabitCategory category;
  final DateTime lastUpdatedDate;
  final ResetFrequency resetFrequency;
  final Map<DateTime, int> history;
  final StreakData streak;
  final ReminderSettings? reminder;
  final HabitMetadata metadata;

  /// Day the weekly/monthly cycle is pinned to (its weekday or day of month).
  /// Null for habits saved before this existed; they fall back to creation date.
  final DateTime? resetAnchorDate;

  const Habit({
    required this.id,
    required this.name,
    required this.progress,
    required this.target,
    this.units = '', // Default to empty string for backward compatibility
    required this.color,
    required this.category,
    required this.lastUpdatedDate,
    required this.resetFrequency,
    required this.history,
    required this.streak,
    this.reminder,
    required this.metadata,
    this.resetAnchorDate,
  });

  factory Habit.create({
    required String name,
    required int target,
    String units = '', // Add units parameter with default empty string
    required HabitColor color,
    required HabitCategory category,
    ResetFrequency resetFrequency = ResetFrequency.daily,
    ReminderSettings? reminder,
    String? icon,
    DateTime? resetAnchor,
  }) {
    final now = DateTime.now();
    final id = 'habit_${DateTime.now().millisecondsSinceEpoch}';
    
    return Habit(
      id: id,
      name: name,
      progress: 0,
      target: target,
      units: units,
      color: color,
      category: category,
      lastUpdatedDate: now,
      resetFrequency: resetFrequency,
      history: {},
      streak: StreakData.empty(),
      reminder: reminder,
      metadata: HabitMetadata.create(icon: icon),
      resetAnchorDate: _dateOnly(resetAnchor ?? now),
    );
  }

  bool get isCompleted => progress >= target;
  
  double get progressPercentage => target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0;
  
  bool get hasReminder => reminder != null && reminder!.enabled;

  DateTime get resetAnchor => resetAnchorDate ?? metadata.createdDate;

  bool shouldReset(DateTime currentDate) {
    return resetFrequency.shouldReset(lastUpdatedDate, currentDate, anchor: resetAnchor);
  }

  /// Total logged in the day/week/month containing [date].
  /// A `never` habit has one endless period, so this is its all-time total.
  int progressForPeriodContaining(DateTime date) {
    if (!resetFrequency.isPeriodic) {
      return history.values.fold(0, (sum, amount) => sum + amount);
    }

    final start = resetFrequency.periodStart(date, anchor: resetAnchor);
    final end = resetFrequency.nextPeriodStart(date, anchor: resetAnchor);
    return history.entries
        .where((entry) => !entry.key.isBefore(start) && entry.key.isBefore(end))
        .fold(0, (sum, entry) => sum + entry.value);
  }

  /// Sets the period progress for today. History stores what was logged on
  /// each day, so today's entry becomes whatever the earlier days of this
  /// period don't already account for.
  Habit updateProgress(int newProgress) {
    if (newProgress < 0 || newProgress > target) {
      throw ArgumentError('Progress must be between 0 and $target');
    }

    final now = DateTime.now();
    final today = _dateOnly(now);
    final loggedEarlierThisPeriod = progressForPeriodContaining(now) - (history[today] ?? 0);
    final todayAmount = newProgress - loggedEarlierThisPeriod;

    final newHistory = Map<DateTime, int>.from(history);
    newHistory[today] = todayAmount < 0 ? 0 : todayAmount;

    return copyWith(history: newHistory)._recalculated(now).copyWith(
          lastUpdatedDate: now,
          metadata: metadata.updateModifiedDate(),
        );
  }

  Habit incrementProgress([int amount = 1]) {
    return updateProgress((progress + amount).clamp(0, target));
  }

  Habit decrementProgress([int amount = 1]) {
    return updateProgress((progress - amount).clamp(0, target));
  }

  /// Records what was logged on a past (or today's) [date] and recomputes
  /// progress and streak. Used to fix history retroactively.
  Habit setProgressForDate(DateTime date, int amount) {
    final now = DateTime.now();
    final day = _dateOnly(date);
    if (day.isAfter(_dateOnly(now))) {
      throw ArgumentError('Cannot log progress for a future date');
    }
    if (amount < 0) {
      throw ArgumentError('Progress cannot be negative');
    }

    final newHistory = Map<DateTime, int>.from(history);
    if (amount == 0) {
      newHistory.remove(day);
    } else {
      newHistory[day] = amount;
    }

    final updated = copyWith(history: newHistory);
    if (updated.progressForPeriodContaining(day) > target) {
      throw ArgumentError('Total for this period would exceed the target of $target');
    }

    return updated._recalculated(now).copyWith(metadata: metadata.updateModifiedDate());
  }

  /// Clears what was logged in the current period.
  Habit resetProgress() {
    final now = DateTime.now();
    final start = resetFrequency.isPeriodic
        ? resetFrequency.periodStart(now, anchor: resetAnchor)
        : null;
    final newHistory = Map<DateTime, int>.from(history)
      ..removeWhere((date, _) => start == null || !date.isBefore(start));

    return copyWith(history: newHistory)._recalculated(now).copyWith(
          lastUpdatedDate: now,
          metadata: metadata.updateModifiedDate(),
        );
  }

  /// Brings progress and streak up to date for [now], e.g. after a period
  /// rolled over: progress drops to this period's total and an expired
  /// streak quietly becomes 0.
  Habit refresh([DateTime? now]) {
    final at = now ?? DateTime.now();
    return _recalculated(at).copyWith(lastUpdatedDate: at);
  }

  Habit _recalculated(DateTime now) {
    final periodProgress = progressForPeriodContaining(now);
    return copyWith(
      progress: periodProgress > target ? target : periodProgress,
      streak: StreakCalculator.calculate(
        history: history,
        target: target,
        frequency: resetFrequency,
        anchor: resetAnchor,
        now: now,
      ),
    );
  }

  /// When the current streak is lost if the habit isn't completed, or null if
  /// there is no streak at stake.
  DateTime? streakDeadline([DateTime? now]) {
    return StreakCalculator.streakDeadline(
      history: history,
      target: target,
      frequency: resetFrequency,
      anchor: resetAnchor,
      now: now ?? DateTime.now(),
    );
  }

  Habit updateDetails({
    String? name,
    int? target,
    String? units,
    HabitColor? color,
    HabitCategory? category,
    ResetFrequency? resetFrequency,
    ReminderSettings? reminder,
    String? icon,
    DateTime? resetAnchor,
  }) {
    final updated = copyWith(
      name: name ?? this.name,
      target: target ?? this.target,
      units: units ?? this.units,
      color: color ?? this.color,
      category: category ?? this.category,
      resetFrequency: resetFrequency ?? this.resetFrequency,
      reminder: reminder ?? this.reminder,
      lastUpdatedDate: DateTime.now(),
      metadata: metadata.copyWith(
        icon: icon ?? metadata.icon,
        lastModifiedDate: DateTime.now(),
      ).incrementVersion(),
      resetAnchorDate: resetAnchor != null ? _dateOnly(resetAnchor) : null,
    );

    // A new target, frequency or reset day changes how history adds up
    return updated._recalculated(updated.lastUpdatedDate);
  }

  int getProgressForDate(DateTime date) {
    final targetDate = DateTime(date.year, date.month, date.day);
    return history[targetDate] ?? 0;
  }

  /// Whether the day/week/month containing [date] reached the target.
  /// For a `never` habit: whether the target had been reached by [date].
  bool wasCompletedOnDate(DateTime date) {
    if (!resetFrequency.isPeriodic) {
      final day = _dateOnly(date);
      final totalByDate = history.entries
          .where((entry) => !entry.key.isAfter(day))
          .fold(0, (sum, entry) => sum + entry.value);
      return totalByDate >= target;
    }
    return progressForPeriodContaining(date) >= target;
  }

  /// Days with logged progress that belong to a completed period.
  List<DateTime> getCompletedDates() {
    return history.entries
        .where((entry) => entry.value > 0 && wasCompletedOnDate(entry.key))
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
    String? units,
    HabitColor? color,
    HabitCategory? category,
    DateTime? lastUpdatedDate,
    ResetFrequency? resetFrequency,
    Map<DateTime, int>? history,
    StreakData? streak,
    ReminderSettings? reminder,
    HabitMetadata? metadata,
    DateTime? resetAnchorDate,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      progress: progress ?? this.progress,
      target: target ?? this.target,
      units: units ?? this.units,
      color: color ?? this.color,
      category: category ?? this.category,
      lastUpdatedDate: lastUpdatedDate ?? this.lastUpdatedDate,
      resetFrequency: resetFrequency ?? this.resetFrequency,
      history: history ?? this.history,
      streak: streak ?? this.streak,
      reminder: reminder ?? this.reminder,
      metadata: metadata ?? this.metadata,
      resetAnchorDate: resetAnchorDate ?? this.resetAnchorDate,
    );
  }

  static DateTime _dateOnly(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'progress': progress,
      'target': target,
      'units': units,
      'color': color.toJson(),
      'category': category.name,
      'lastUpdatedDate': lastUpdatedDate.toIso8601String(),
      'resetFrequency': resetFrequency.name,
      'history': history.map((key, value) => MapEntry(key.toIso8601String(), value)),
      'streak': streak.toJson(),
      'reminder': reminder?.toJson(),
      'metadata': metadata.toJson(),
      'resetAnchor': resetAnchorDate?.toIso8601String(),
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
      units: json['units'] as String? ?? '', // Default to empty string for backward compatibility
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
      resetAnchorDate: json['resetAnchor'] != null
          ? DateTime.parse(json['resetAnchor'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        progress,
        target,
        units,
        color,
        category,
        lastUpdatedDate,
        resetFrequency,
        history,
        streak,
        reminder,
        metadata,
        resetAnchorDate,
      ];

  @override
  String toString() => 'Habit(id: $id, name: $name, progress: $progress/$target)';
}