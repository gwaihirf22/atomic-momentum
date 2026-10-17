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
import '../../core/services/streak_warning_service.dart';
import '../../domain/repositories/category_repository.dart';
import '../../core/logging/log.dart';
import '../../domain/entities/momentum.dart';
import '../../core/services/reminder_service.dart';
import '../../domain/entities/reminder_settings.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:clock/clock.dart';

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

  // Null disables habit reminders (e.g. in tests that don't exercise them)
  final ReminderService? _reminders;

  // Used to skip sample habits whose category the user has deleted
  final CategoryRepository? _categoryRepository;

  HabitProvider({
    required GetHabitsUseCase getHabitsUseCase,
    required CreateHabitUseCase createHabitUseCase,
    required UpdateHabitUseCase updateHabitUseCase,
    required DeleteHabitUseCase deleteHabitUseCase,
    this.seedDefaultHabit = false,
    StreakWarningService? streakWarningService,
    ReminderService? reminderService,
    CategoryRepository? categoryRepository,
  })  : _streakWarnings = streakWarningService,
        _reminders = reminderService,
        _categoryRepository = categoryRepository,
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
  /// Average momentum across habits that reset and have something logged,
  /// or null when there's nothing to average yet.
  Momentum? get overallMomentum {
    final tracked = _habits
        .where((h) => h.schedule.isPeriodic && h.history.values.any((amount) => amount > 0))
        .map((h) => h.momentum)
        .toList();
    if (tracked.isEmpty) return null;
    double average(double Function(Momentum m) of) => tracked.map(of).reduce((a, b) => a + b) / tracked.length;
    return Momentum(score: average((m) => m.score), trend: average((m) => m.trend));
  }

  bool get isLoading => _state == HabitProviderState.loading;
  bool get hasError => _state == HabitProviderState.error;
  bool get isPerformingOperation => _isPerformingOperation;

  Habit? getHabitById(String id) {
    try {
      return _habits.firstWhere((habit) => habit.id == id);
    } catch (e) {
      return null;
    }
  }

  // Actions
  Future<void> loadHabits() async {
    try {
      _setState(HabitProviderState.loading);
      _error = null;

      // Zero out progress for habits whose day/week/month has rolled over
      try {
        await _updateHabitUseCase.resetHabitsIfNeeded();
      } catch (e) {
        logWarning('Period reset failed, loading habits anyway: $e');
      }

      final habits = await _getHabitsUseCase();
      _habits = habits;
      
      // Seed example habits into empty storage (development convenience)
      if (seedDefaultHabit && _habits.isEmpty) {
        await addSampleHabits();
      }
      
      _setState(HabitProviderState.loaded);
      await _streakWarnings?.syncAll(_habits);
      await _reminders?.syncAll(_habits);
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
      _setOperationInProgress(true);
      
      final habit = await _createHabitUseCase(params);
      _habits.add(habit);
      await _streakWarnings?.sync(habit);
      await _reminders?.syncAll(_habits);

      _sortHabits();
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

  // Progress and two-minute changes are shown at once and saved in the
  // background, one save at a time: taps never wait on storage or
  // notifications, quick repeated taps collapse into one save of the latest
  // value, and two kinds of change to one habit never overwrite each other.
  final Map<String, _PendingChange> _unsaved = {};
  final Map<String, Habit> _lastSaved = {};
  bool _saving = false;

  /// Sets today's progress. The change shows immediately; returns false if
  /// saving fails (the habit then goes back to what's stored).
  Future<bool> updateHabitProgress(String habitId, int newProgress) {
    return _applyNow(
      habitId,
      (habit) => habit.updateProgress(newProgress),
      (pending) => pending.progress = newProgress,
    );
  }

  /// Marks (or unmarks) the two-minute version as done today, or in the
  /// period containing [date]. Shows immediately and saves in the background
  /// like progress; returns false if saving fails.
  Future<bool> setTwoMinute(String habitId, bool done, {DateTime? date}) {
    final now = clock.now();
    final day = DateTime((date ?? now).year, (date ?? now).month, (date ?? now).day);
    return _applyNow(
      habitId,
      (habit) => habit.setTwoMinuteForDate(day, done),
      (pending) => pending.twoMinute[day] = done,
    );
  }

  Future<bool> _applyNow(
    String habitId,
    Habit Function(Habit) change,
    void Function(_PendingChange) record,
  ) async {
    final index = _habits.indexWhere((habit) => habit.id == habitId);
    if (index < 0) {
      _error = 'Habit not found: $habitId';
      notifyListeners();
      return false;
    }

    final current = _habits[index];
    try {
      _habits[index] = change(current);
    } on ArgumentError catch (e) {
      _error = e.message.toString();
      notifyListeners();
      return false;
    }
    _lastSaved.putIfAbsent(habitId, () => current);
    notifyListeners();

    record(_unsaved.putIfAbsent(habitId, _PendingChange.new));
    // A save already running picks this up when it finishes
    if (_saving) return true;
    return _saveChanges();
  }

  Future<bool> _saveChanges() async {
    _saving = true;
    var allSaved = true;
    try {
      while (_unsaved.isNotEmpty) {
        final habitId = _unsaved.keys.first;
        final pending = _unsaved.remove(habitId)!;
        try {
          Habit? saved;
          if (pending.progress != null) {
            saved = await _updateHabitUseCase.updateProgress(habitId, pending.progress!);
          }
          for (final entry in pending.twoMinute.entries) {
            saved = await _updateHabitUseCase.setTwoMinuteForDate(habitId, entry.key, entry.value);
          }
          if (saved == null) continue;
          // A newer tap is waiting: keep showing it rather than this save
          if (!_unsaved.containsKey(habitId)) {
            _lastSaved.remove(habitId);
            _replaceHabit(saved);
          }
          _streakWarnings?.sync(saved);
        } catch (saveError) {
          // Roll back: never show a change that isn't actually stored
          _unsaved.remove(habitId);
          final stored = _lastSaved.remove(habitId);
          if (stored != null) _replaceHabit(stored);
          _error = 'Could not save progress: $saveError';
          notifyListeners();
          allSaved = false;
        }
      }
    } finally {
      _saving = false;
    }
    // Finishing a habit drops its remaining reminders; not awaited, so taps
    // never wait on notifications
    _reminders?.syncAll(_habits);
    return allSaved;
  }


  Future<bool> updateHabitDetails(String habitId, UpdateHabitParams params) async {
    try {
      _setOperationInProgress(true);
      
      final updatedHabit = await _updateHabitUseCase.updateDetails(habitId, params);
      _updateHabitInList(updatedHabit);
      await _reminders?.syncAll(_habits);

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
      
      // Its streak warnings go now; its reminders go with the resync below
      await _streakWarnings?.cancel(habitId);
      
      await _deleteHabitUseCase(habitId);
      _habits.removeWhere((habit) => habit.id == habitId);
      await _reminders?.syncAll(_habits);

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
      // A new day: the reminder window moves on even if nothing changed
      await _reminders?.syncAll(_habits);
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
    // Warnings may now need more (or less) of iOS's 64, which reminders share
    await _reminders?.syncAll(_habits);
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
    // Finishing a habit drops its remaining reminders for the period
    _reminders?.syncAll(_habits);
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
    final categoryRepository = _categoryRepository;
    final activeCategoryIds = categoryRepository == null
        ? null
        : {for (final c in await categoryRepository.getAll()) if (!c.isDeleted) c.id};
    final now = clock.now();
    var added = 0;

    for (final params in _sampleHabits) {
      if (existingNames.contains(params.name.toLowerCase())) continue;
      if (activeCategoryIds != null && !activeCategoryIds.contains(params.categoryId)) continue;
      // Like any new habit, samples start with smart reminders
      if (!await createHabit(params.copyWith(
          reminder: ReminderSettings.smart(time: const TimeOfDay(hour: 9, minute: 0))))) {
        continue;
      }
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

}

/// Changes to one habit waiting to be saved.
class _PendingChange {
  int? progress;

  /// Day -> done, in the order they were tapped.
  final Map<DateTime, bool> twoMinute = {};
}
