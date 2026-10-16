// Flutter's foundation library has its own Category class
import 'package:flutter/foundation.dart' hide Category;
import '../../domain/entities/habit.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/habit_color.dart';
import '../../domain/entities/reset_frequency.dart';
import '../../domain/usecases/get_habits_usecase.dart';
import '../../domain/usecases/create_habit_usecase.dart';
import '../../domain/usecases/update_habit_usecase.dart';
import '../../domain/usecases/delete_habit_usecase.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/streak_warning_service.dart';

enum HabitProviderState {
  initial,
  loading,
  loaded,
  error,
}

class HabitProvider extends ChangeNotifier {
  final GetHabitsUseCase _getHabitsUseCase;
  final CreateHabitUseCase _createHabitUseCase;
  final UpdateHabitUseCase _updateHabitUseCase;
  final DeleteHabitUseCase _deleteHabitUseCase;

  // When true, a "Drink Water" habit is added if storage is empty (dev convenience)
  final bool seedDefaultHabit;

  // Null disables streak warnings (e.g. in tests that don't exercise them)
  final StreakWarningService? _streakWarnings;

  HabitProvider({
    required GetHabitsUseCase getHabitsUseCase,
    required CreateHabitUseCase createHabitUseCase,
    required UpdateHabitUseCase updateHabitUseCase,
    required DeleteHabitUseCase deleteHabitUseCase,
    this.seedDefaultHabit = false,
    StreakWarningService? streakWarningService,
  })  : _streakWarnings = streakWarningService,
        _getHabitsUseCase = getHabitsUseCase,
        _createHabitUseCase = createHabitUseCase,
        _updateHabitUseCase = updateHabitUseCase,
        _deleteHabitUseCase = deleteHabitUseCase;

  // State
  HabitProviderState _state = HabitProviderState.initial;
  List<Habit> _habits = [];
  String? _error;
  bool _isPerformingOperation = false;

  // Getters
  HabitProviderState get state => _state;
  List<Habit> get habits => List.unmodifiable(_habits);
  String? get error => _error;
  bool get isLoading => _state == HabitProviderState.loading;
  bool get hasError => _state == HabitProviderState.error;
  bool get hasHabits => _habits.isNotEmpty;
  bool get isPerformingOperation => _isPerformingOperation;

  List<Habit> getCompletedHabits() {
    return _habits.where((habit) => habit.isCompleted).toList();
  }

  List<Habit> getIncompleteHabits() {
    return _habits.where((habit) => !habit.isCompleted).toList();
  }

  List<Habit> getHabitsWithActiveStreaks() {
    return _habits.where((habit) => habit.streak.current > 0).toList();
  }

  Habit? getHabitById(String id) {
    try {
      return _habits.firstWhere((habit) => habit.id == id);
    } catch (e) {
      return null;
    }
  }

  // Statistics
  int get totalHabits => _habits.length;
  int get completedHabitsCount => getCompletedHabits().length;
  double get completionPercentage => 
    totalHabits > 0 ? (completedHabitsCount / totalHabits) * 100 : 0.0;

  // Actions
  Future<void> loadHabits() async {
    try {
      _setState(HabitProviderState.loading);
      _error = null;

      // Zero out progress for habits whose day/week/month has rolled over
      try {
        await _updateHabitUseCase.resetHabitsIfNeeded();
      } catch (e) {
        print('DEBUG: Period reset failed, loading habits anyway: $e');
      }

      final habits = await _getHabitsUseCase();
      _habits = habits;
      
      // Seed example habits into empty storage (development convenience)
      if (seedDefaultHabit && _habits.isEmpty) {
        await addSampleHabits();
      }
      
      _setState(HabitProviderState.loaded);
      await _streakWarnings?.syncAll(_habits);
    } catch (e) {
      _error = e.toString();
      _setState(HabitProviderState.error);
    }
  }

  Future<void> refreshHabits() async {
    await loadHabits();
  }

  Future<bool> createHabit(CreateHabitParams params) async {
    try {
      print('DEBUG: HabitProvider.createHabit called with: ${params.name}');
      _setOperationInProgress(true);
      
      final habit = await _createHabitUseCase(params);
      print('DEBUG: Habit created successfully: ${habit.id}');
      _habits.add(habit);
      await _streakWarnings?.sync(habit);
      
      // Schedule notification if habit has reminder settings
      if (habit.hasReminder) {
        print('DEBUG: Scheduling notifications for habit: ${habit.name}');
        final notificationScheduled = await NotificationService.scheduleHabitReminder(habit);
        print('DEBUG: Notification scheduled: $notificationScheduled');
      }
      
      _sortHabits();
      notifyListeners();
      
      print('DEBUG: HabitProvider returning true');
      return true;
    } catch (e) {
      print('DEBUG: HabitProvider error: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setOperationInProgress(false);
    }
  }

  Future<bool> updateHabitProgress(String habitId, int newProgress) async {
    try {
      print('DEBUG: HabitProvider.updateHabitProgress called: habitId=$habitId, newProgress=$newProgress');
      _setOperationInProgress(true);
      
      // TEMPORARY FIX: Try to update progress directly in the local list first
      final habitIndex = _habits.indexWhere((habit) => habit.id == habitId);
      if (habitIndex >= 0) {
        final currentHabit = _habits[habitIndex];
        print('DEBUG: Found habit in local list: ${currentHabit.name} (${currentHabit.progress}/${currentHabit.target})');
        
        // Create updated habit directly
        final updatedHabit = currentHabit.updateProgress(newProgress);
        print('DEBUG: Created updated habit: ${updatedHabit.name} (${updatedHabit.progress}/${updatedHabit.target}) isCompleted: ${updatedHabit.isCompleted}');
        
        // Show the change immediately so taps feel instant
        _habits[habitIndex] = updatedHabit;
        notifyListeners();

        try {
          final savedHabit = await _updateHabitUseCase.updateProgress(habitId, newProgress);
          _replaceHabit(savedHabit);
          await _streakWarnings?.sync(savedHabit);
        } catch (saveError) {
          // Roll back: never show progress that isn't actually stored
          _replaceHabit(currentHabit);
          _error = 'Could not save progress: $saveError';
          notifyListeners();
          return false;
        }

        return true;
      } else {
        print('DEBUG: Habit not found in local list');
        _error = 'Habit not found: $habitId';
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('DEBUG: HabitProvider.updateHabitProgress failed: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setOperationInProgress(false);
    }
  }

  Future<bool> incrementHabitProgress(String habitId, [int amount = 1]) async {
    try {
      _setOperationInProgress(true);
      
      final updatedHabit = await _updateHabitUseCase.incrementProgress(habitId, amount);
      _updateHabitInList(updatedHabit);
      
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setOperationInProgress(false);
    }
  }

  Future<bool> decrementHabitProgress(String habitId, [int amount = 1]) async {
    try {
      _setOperationInProgress(true);
      
      final updatedHabit = await _updateHabitUseCase.decrementProgress(habitId, amount);
      _updateHabitInList(updatedHabit);
      
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setOperationInProgress(false);
    }
  }

  Future<bool> updateHabitDetails(String habitId, UpdateHabitParams params) async {
    try {
      _setOperationInProgress(true);
      
      final updatedHabit = await _updateHabitUseCase.updateDetails(habitId, params);
      _updateHabitInList(updatedHabit);
      
      // Update notification schedule for the updated habit
      print('DEBUG: Updating notifications for habit: ${updatedHabit.name}');
      final notificationUpdated = await NotificationService.updateHabitReminder(updatedHabit);
      print('DEBUG: Notification updated: $notificationUpdated');
      
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setOperationInProgress(false);
    }
  }

  Future<bool> resetHabitProgress(String habitId) async {
    try {
      _setOperationInProgress(true);
      
      final updatedHabit = await _updateHabitUseCase.resetProgress(habitId);
      _updateHabitInList(updatedHabit);
      
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setOperationInProgress(false);
    }
  }

  Future<bool> markHabitCompleted(String habitId) async {
    try {
      _setOperationInProgress(true);
      
      final updatedHabit = await _updateHabitUseCase.markCompleted(habitId);
      _updateHabitInList(updatedHabit);
      
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setOperationInProgress(false);
    }
  }

  Future<bool> deleteHabit(String habitId) async {
    try {
      _setOperationInProgress(true);
      
      // Cancel notifications for this habit before deleting
      print('DEBUG: Cancelling notifications for habit: $habitId');
      await NotificationService.cancelHabitReminder(habitId);
      await _streakWarnings?.cancel(habitId);
      
      await _deleteHabitUseCase(habitId);
      _habits.removeWhere((habit) => habit.id == habitId);
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setOperationInProgress(false);
    }
  }

  Future<void> resetHabitsIfNeeded() async {
    try {
      _setOperationInProgress(true);
      
      final resetHabits = await _updateHabitUseCase.resetHabitsIfNeeded();
      
      // Update the affected habits in our list
      for (final resetHabit in resetHabits) {
        _updateHabitInList(resetHabit);
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _setOperationInProgress(false);
    }
  }

  /// Retroactively set what was logged on [date]; recomputes the streak.
  Future<bool> updateProgressForDate(String habitId, DateTime date, int amount) async {
    try {
      _setOperationInProgress(true);

      final updatedHabit = await _updateHabitUseCase.updateHistoryForDate(habitId, date, amount);
      _updateHabitInList(updatedHabit);

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setOperationInProgress(false);
    }
  }

  /// Re-plan every streak warning, e.g. after the warning settings change.
  Future<void> resyncStreakWarnings() async {
    await _streakWarnings?.syncAll(_habits);
  }

  // Utility methods
  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setState(HabitProviderState newState) {
    _state = newState;
    notifyListeners();
  }

  void _setOperationInProgress(bool inProgress) {
    _isPerformingOperation = inProgress;
    notifyListeners();
  }

  void _replaceHabit(Habit habit) {
    final index = _habits.indexWhere((h) => h.id == habit.id);
    if (index >= 0) {
      _habits[index] = habit;
      notifyListeners();
    }
  }

  void _updateHabitInList(Habit updatedHabit) {
    final index = _habits.indexWhere((habit) => habit.id == updatedHabit.id);
    if (index >= 0) {
      _habits[index] = updatedHabit;
      notifyListeners();
    }
    _streakWarnings?.sync(updatedHabit);
  }

  void _sortHabits() {
    _habits.sort((a, b) {
      // Sort by category first, then by name
      final categoryComparison = a.categoryId.compareTo(b.categoryId);
      if (categoryComparison != 0) return categoryComparison;
      
      return a.name.compareTo(b.name);
    });
  }

  // One example per category, mixing frequencies, for development and testing
  static const _sampleHabits = [
    CreateHabitParams(name: 'Drink Water', target: 8, units: 'glasses',
        color: HabitColor.blue, categoryId: BuiltInCategoryIds.body, resetFrequency: ResetFrequency.daily),
    CreateHabitParams(name: 'Meditate', target: 1, units: 'session',
        color: HabitColor.purple, categoryId: BuiltInCategoryIds.spirit, resetFrequency: ResetFrequency.daily),
    CreateHabitParams(name: 'Read', target: 2, units: 'chapters',
        color: HabitColor.teal, categoryId: BuiltInCategoryIds.mind, resetFrequency: ResetFrequency.daily),
    CreateHabitParams(name: 'Call a friend', target: 2, units: 'calls',
        color: HabitColor.green, categoryId: BuiltInCategoryIds.social, resetFrequency: ResetFrequency.weekly),
    CreateHabitParams(name: 'Deep work', target: 3, units: 'sessions',
        color: HabitColor.orange, categoryId: BuiltInCategoryIds.career, resetFrequency: ResetFrequency.weekly),
    CreateHabitParams(name: 'Sketch', target: 4, units: 'sketches',
        color: HabitColor.pink, categoryId: BuiltInCategoryIds.creative, resetFrequency: ResetFrequency.monthly),
  ];

  /// Development helper: adds one example habit per category, skipping any
  /// whose name already exists. Daily samples get completed days 5, 4, 2 and
  /// 1 days ago (a gap 3 days ago) so streaks and calendar editing can be
  /// tried straight away. Returns how many habits were added.
  Future<int> addSampleHabits() async {
    final existingNames = _habits.map((h) => h.name.trim().toLowerCase()).toSet();
    final now = DateTime.now();
    var added = 0;

    for (final params in _sampleHabits) {
      if (existingNames.contains(params.name.toLowerCase())) continue;
      if (!await createHabit(params)) continue;
      added++;

      if (params.resetFrequency == ResetFrequency.daily) {
        final habit = _habits.firstWhere((h) => h.name == params.name);
        for (final daysAgo in const [5, 4, 2, 1]) {
          final day = DateTime(now.year, now.month, now.day - daysAgo);
          await updateProgressForDate(habit.id, day, params.target);
        }
      }
    }
    return added;
  }

  @override
  void dispose() {
    super.dispose();
  }
}