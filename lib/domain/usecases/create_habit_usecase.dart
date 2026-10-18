import '../entities/habit.dart';
import '../entities/habit_color.dart';
import '../entities/habit_goal.dart';
import '../entities/habit_notify.dart';
import '../entities/health_link.dart';
import '../entities/reset_frequency.dart';
import '../entities/reminder_settings.dart';
import '../entities/two_minute_version.dart';
import '../repositories/habit_repository.dart';
import '../../core/validation/habit_validator.dart';
import '../../core/exceptions/storage_exceptions.dart';

class CreateHabitUseCase {
  final HabitRepository _repository;

  const CreateHabitUseCase(this._repository);

  /// Create a new habit
  Future<Habit> call(CreateHabitParams params) async {
    try {
      // Validate input parameters
      _validateParams(params);

      // Check for duplicate names
      await _checkDuplicateName(params.name);

      // Create the habit
      var habit = Habit.create(
        name: params.name.trim(),
        target: params.target,
        units: params.units,
        color: params.color,
        categoryId: params.categoryId,
        resetFrequency: params.resetFrequency ?? ResetFrequency.daily,
        reminder: params.reminder,
        icon: params.icon,
        resetAnchor: params.resetAnchor,
        resetInterval: params.resetInterval,
        scheduledWeekdays: params.scheduledWeekdays,
        twoMinute: params.twoMinute,
        goal: params.goal,
        notify: params.notify,
      );
      // Linked after creating, so Habit.create stays as it is
      if (params.health != null) habit = habit.copyWith(health: params.health);

      // Validate the created habit
      final validationResult = HabitValidator.validate(habit);
      if (!validationResult.isValid) {
        throw ValidationException('Invalid habit: ${validationResult.errors.join(', ')}');
      }

      // Save to repository
      await _repository.saveHabit(habit);

      return habit;
    } catch (e) {
      if (e is ValidationException || e is StorageException) rethrow;
      throw StorageException('Failed to create habit: $e');
    }
  }

  void _validateParams(CreateHabitParams params) {
    if (params.name.trim().isEmpty) {
      throw ValidationException('Habit name cannot be empty');
    }
    if (params.name.trim().length > 50) {
      throw ValidationException('Habit name cannot exceed 50 characters');
    }
    // Quitting allows nothing; every other habit needs a target
    if (params.goal == HabitGoal.quit ? params.target != 0 : params.target <= 0) {
      throw ValidationException('Target must be greater than 0');
    }
    final most = Habit.maxTargetFor(params.health);
    if (params.target > most) {
      throw ValidationException('Target cannot exceed $most');
    }
  }

  Future<void> _checkDuplicateName(String name) async {
    final existingHabits = await _repository.getHabits();
    final normalizedName = name.trim().toLowerCase();
    
    final duplicate = existingHabits.any((habit) => 
      habit.name.trim().toLowerCase() == normalizedName
    );
    
    if (duplicate) {
      throw ValidationException('A habit with the name "$name" already exists');
    }
  }
}

class CreateHabitParams {
  final String name;
  final int target;
  final String units;
  final HabitColor color;
  final String categoryId;
  final ResetFrequency? resetFrequency;
  final ReminderSettings? reminder;
  final String? icon;
  /// Weekday/day-of-month that weekly/monthly habits reset on. Defaults to today.
  final DateTime? resetAnchor;
  /// Every N days/weeks/months.
  final int resetInterval;
  /// Weekdays a daily habit is due; null (or all seven) means every day.
  final List<int>? scheduledWeekdays;
  /// The tiny version for hard days, if any.
  final TwoMinuteVersion? twoMinute;

  /// Building it up, or breaking it; for a break habit [target] is the limit.
  final HabitGoal goal;
  final HabitNotify notify;

  /// Filled in from Health, or null.
  final HealthLink? health;

  const CreateHabitParams({
    required this.name,
    required this.target,
    this.units = '',
    required this.color,
    required this.categoryId,
    this.resetFrequency,
    this.reminder,
    this.icon,
    this.resetAnchor,
    this.resetInterval = 1,
    this.scheduledWeekdays,
    this.twoMinute,
    this.goal = HabitGoal.build,
    this.notify = HabitNotify.standard,
    this.health,
  });

  CreateHabitParams copyWith({
    String? name,
    int? target,
    String? units,
    HabitColor? color,
    String? categoryId,
    ResetFrequency? resetFrequency,
    ReminderSettings? reminder,
    String? icon,
  }) {
    return CreateHabitParams(
      name: name ?? this.name,
      target: target ?? this.target,
      units: units ?? this.units,
      color: color ?? this.color,
      categoryId: categoryId ?? this.categoryId,
      resetFrequency: resetFrequency ?? this.resetFrequency,
      reminder: reminder ?? this.reminder,
      icon: icon ?? this.icon,
    );
  }
}