import '../entities/habit.dart';
import '../entities/habit_category.dart';
import '../entities/habit_color.dart';
import '../entities/reset_frequency.dart';
import '../entities/reminder_settings.dart';
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
      final habit = Habit.create(
        name: params.name.trim(),
        target: params.target,
        color: params.color,
        category: params.category,
        resetFrequency: params.resetFrequency ?? ResetFrequency.daily,
        reminder: params.reminder,
        icon: params.icon,
      );

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

  /// Create multiple habits at once
  Future<List<Habit>> createMultiple(List<CreateHabitParams> paramsList) async {
    try {
      final habits = <Habit>[];

      // Validate all parameters first
      for (int i = 0; i < paramsList.length; i++) {
        _validateParams(paramsList[i]);
      }

      // Check for duplicate names within the list
      final names = paramsList.map((params) => params.name.toLowerCase().trim()).toList();
      final duplicates = names.where((name) => names.where((n) => n == name).length > 1).toSet();
      if (duplicates.isNotEmpty) {
        throw ValidationException('Duplicate habit names found: ${duplicates.join(', ')}');
      }

      // Create habits
      for (final params in paramsList) {
        final habit = Habit.create(
          name: params.name.trim(),
          target: params.target,
          color: params.color,
          category: params.category,
          resetFrequency: params.resetFrequency ?? ResetFrequency.daily,
          reminder: params.reminder,
          icon: params.icon,
        );
        habits.add(habit);
      }

      // Validate all habits
      final validationResult = HabitValidator.validateHabits(habits);
      if (!validationResult.isValid) {
        throw ValidationException('Invalid habits: ${validationResult.errors.join(', ')}');
      }

      // Save all habits
      await _repository.saveHabits(habits);

      return habits;
    } catch (e) {
      if (e is ValidationException || e is StorageException) rethrow;
      throw StorageException('Failed to create habits: $e');
    }
  }

  /// Create habit with default settings based on category
  Future<Habit> createWithDefaults(String name, HabitCategory category) async {
    final defaultParams = CreateHabitParams.forCategory(name, category);
    return await call(defaultParams);
  }

  void _validateParams(CreateHabitParams params) {
    if (params.name.trim().isEmpty) {
      throw ValidationException('Habit name cannot be empty');
    }
    if (params.name.trim().length > 50) {
      throw ValidationException('Habit name cannot exceed 50 characters');
    }
    if (params.target <= 0) {
      throw ValidationException('Target must be greater than 0');
    }
    if (params.target > 1000) {
      throw ValidationException('Target cannot exceed 1000');
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
  final HabitColor color;
  final HabitCategory category;
  final ResetFrequency? resetFrequency;
  final ReminderSettings? reminder;
  final String? icon;

  const CreateHabitParams({
    required this.name,
    required this.target,
    required this.color,
    required this.category,
    this.resetFrequency,
    this.reminder,
    this.icon,
  });

  /// Create parameters with category-specific defaults
  factory CreateHabitParams.forCategory(String name, HabitCategory category) {
    HabitColor color;
    int defaultTarget;
    String? defaultIcon;
    
    switch (category) {
      case HabitCategory.body:
        color = HabitColor.orange;
        defaultTarget = 1; // Usually daily activities
        defaultIcon = 'fitness';
        break;
      case HabitCategory.spirit:
        color = HabitColor.purple;
        defaultTarget = 1;
        defaultIcon = 'meditation';
        break;
      case HabitCategory.mind:
        color = HabitColor.blue;
        defaultTarget = 30; // 30 minutes of reading/learning
        defaultIcon = 'book';
        break;
      case HabitCategory.social:
        color = HabitColor.green;
        defaultTarget = 1;
        defaultIcon = 'people';
        break;
      case HabitCategory.career:
        color = HabitColor.indigo;
        defaultTarget = 1;
        defaultIcon = 'work';
        break;
      case HabitCategory.creative:
        color = HabitColor.pink;
        defaultTarget = 30; // 30 minutes of creative work
        defaultIcon = 'palette';
        break;
    }

    return CreateHabitParams(
      name: name,
      target: defaultTarget,
      color: color,
      category: category,
      resetFrequency: ResetFrequency.daily,
      icon: defaultIcon,
    );
  }

  CreateHabitParams copyWith({
    String? name,
    int? target,
    HabitColor? color,
    HabitCategory? category,
    ResetFrequency? resetFrequency,
    ReminderSettings? reminder,
    String? icon,
  }) {
    return CreateHabitParams(
      name: name ?? this.name,
      target: target ?? this.target,
      color: color ?? this.color,
      category: category ?? this.category,
      resetFrequency: resetFrequency ?? this.resetFrequency,
      reminder: reminder ?? this.reminder,
      icon: icon ?? this.icon,
    );
  }
}