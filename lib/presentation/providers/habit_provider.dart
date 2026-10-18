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
import '../../core/services/health_sync_service.dart';
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

  // Null disables filling habits in from Apple Health / Health Connect
  final HealthSyncService? _health;

  HabitProvider({
    required GetHabitsUseCase getHabitsUseCase,
    required CreateHabitUseCase createHabitUseCase,
    required UpdateHabitUseCase updateHabitUseCase,
    required DeleteHabitUseCase deleteHabitUseCase,
    this.seedDefaultHabit = false,
    StreakWarningService? streakWarningService,
    ReminderService? reminderService,
    CategoryRepository? categoryRepository,
    HealthSyncService? healthSync,
  })  : _streakWarnings = streakWarningService,
        _health = healthSync,
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
  /// Average momentum across habits that reset and have been tracked: built
  /// habits once something is logged, habits being broken once a period has
  /// passed (a clean run logs nothing). Null when there's nothing to average.
  Momentum? get overallMomentum {
    final now = clock.now();
    final scores = _habits.where((h) => h.countsTowardMomentumAt(now)).map((h) => h.momentum).toList();
    if (scores.isEmpty) return null;
    double average(double Function(Momentum m) of) => scores.map(of).reduce((a, b) => a + b) / scores.length;
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
      // Not awaited: Health can be slow, and the list is already showing
      syncHealth();
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

  /// Sets what was logged on several days at once: clearing a period, or
  /// putting one back (undo). Shows immediately and saves in the background
  /// like progress.
  Future<bool> setDays(String habitId, Map<DateTime, int> amounts) {
    return _applyNow(
      habitId,
      (habit) => habit.setDays(amounts),
      (pending) {
        // Setting today replaces a waiting progress change (which sets today)
        final now = clock.now();
        if (amounts.keys.any((d) => d.year == now.year && d.month == now.month && d.day == now.day)) {
          pending.progress = null;
        }
        pending.days.addAll(amounts);
      },
    );
  }

  bool _healthSyncing = false;

  /// A change being applied came from Health (so isn't logged back).
  bool _fromHealth = false;

  /// Fills in habits linked to Health from it (the higher number wins for
  /// each day), through the same save queue as taps. Skipped while one is
  /// running, and within a minute of the last unless [force].
  Future<void> syncHealth({bool force = false}) async {
    final health = _health;
    if (health == null || _healthSyncing || !_habits.any((h) => h.health != null)) return;
    if (!health.isDue(force: force)) return;
    _healthSyncing = true;
    try {
      final changes = await health.changes(_habits);
      for (final entry in changes.entries) {
        // Numbers from Health aren't logged back to it
        _fromHealth = true;
        final saved = setDays(entry.key, entry.value);
        _fromHealth = false;
        await saved;
      }
    } catch (e) {
      logWarning('Health sync failed: $e');
    } finally {
      _healthSyncing = false;
      notifyListeners();
    }
  }

  /// Why a change couldn't go to Health, once (see [takeHealthNotice]).
  String? _healthNotice;

  /// The last Health message, cleared as it's read (for a SnackBar).
  String? takeHealthNotice() {
    final notice = _healthNotice;
    _healthNotice = null;
    return notice;
  }

  /// Logs a change to a habit that logs to Health, behind the tap. When
  /// Health holds more than the app wrote, its number comes back.
  void _mirrorToHealth(Habit before, Habit after) {
    final health = _health;
    if (health == null || _fromHealth || !(after.health?.logsToHealth ?? false)) return;
    health.logChange(before, after).then((notice) {
      if (notice == null) return;
      _healthNotice = notice;
      notifyListeners();
      syncHealth(force: true);
    });
  }

  /// When this phone last read Health, or null.
  DateTime? get lastHealthSync => _health?.lastSync;

  /// Why the person keeps the habit; shows at once and saves behind.
  Future<bool> setWhy(String habitId, String text) =>
      _applyNow(habitId, (habit) => habit.setWhy(text), (pending) => pending.why = text);

  /// Counts the habit from an earlier [date] (see [Habit.startFrom]). Shows
  /// at once and saves behind.
  Future<bool> startFrom(String habitId, DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return _applyNow(
      habitId,
      (habit) => habit.startFrom(day),
      (pending) => pending
        ..countFrom = null
        ..startFrom = day,
    );
  }

  /// Counts the habit from [date], earlier or later (see [Habit.countFrom]),
  /// first clearing what was logged before it if [clearEarlier]. Shows at
  /// once and saves behind.
  Future<bool> countFrom(String habitId, DateTime date, {bool clearEarlier = false}) {
    final day = DateTime(date.year, date.month, date.day);
    return _applyNow(
      habitId,
      (habit) => (clearEarlier ? habit.clearBefore(day) : habit).countFrom(day),
      (pending) => pending
        ..startFrom = null
        ..countFrom = day
        ..clearEarlier = clearEarlier,
    );
  }

  /// Keeps a quote with the habit; shows at once and saves behind.
  Future<bool> addQuote(String habitId, String quoteId) => _applyNow(
        habitId,
        (habit) => habit.addQuote(quoteId),
        (pending) => pending.quoteIds = _quoteIdsOf(habitId),
      );

  /// Takes a quote off the habit; shows at once and saves behind.
  Future<bool> removeQuote(String habitId, String quoteId) => _applyNow(
        habitId,
        (habit) => habit.removeQuote(quoteId),
        (pending) => pending.quoteIds = _quoteIdsOf(habitId),
      );

  List<String> _quoteIdsOf(String habitId) => _habits.firstWhere((habit) => habit.id == habitId).quoteIds;

  /// The note on [date]; empty removes it. Shows at once and saves behind.
  Future<bool> setDayNote(String habitId, DateTime date, String text) {
    final day = DateTime(date.year, date.month, date.day);
    return _applyNow(habitId, (habit) => habit.setDayNote(day, text), (pending) => pending.notes[day] = text);
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
    _mirrorToHealth(current, _habits[index]);

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
          if (pending.startFrom != null) saved = await _updateHabitUseCase.startFrom(habitId, pending.startFrom!);
          if (pending.countFrom != null) {
            saved = await _updateHabitUseCase.countFrom(habitId, pending.countFrom!, clearEarlier: pending.clearEarlier);
          }
          if (pending.days.isNotEmpty) {
            saved = await _updateHabitUseCase.setDays(habitId, pending.days);
          }
          if (pending.progress != null) {
            saved = await _updateHabitUseCase.updateProgress(habitId, pending.progress!);
          }
          for (final entry in pending.twoMinute.entries) {
            saved = await _updateHabitUseCase.setTwoMinuteForDate(habitId, entry.key, entry.value);
          }
          if (pending.why != null) saved = await _updateHabitUseCase.setWhy(habitId, pending.why!);
          if (pending.quoteIds != null) saved = await _updateHabitUseCase.setQuotes(habitId, pending.quoteIds!);
          for (final entry in pending.notes.entries) {
            saved = await _updateHabitUseCase.setDayNote(habitId, entry.key, entry.value);
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
  /// Days set directly (clearing or restoring a period), applied first.
  final Map<DateTime, int> days = {};
  int? progress;

  /// Day -> done, in the order they were tapped.
  final Map<DateTime, bool> twoMinute = {};

  String? why;

  /// The habit's quotes as they now stand.
  List<String>? quoteIds;

  /// The earlier day the habit now counts from.
  DateTime? startFrom;

  /// The day the habit counts from (earlier or later), clearing what's logged
  /// before it first if [clearEarlier].
  DateTime? countFrom;
  bool clearEarlier = false;

  /// Day -> note text ('' removes it).
  final Map<DateTime, String> notes = {};
}
