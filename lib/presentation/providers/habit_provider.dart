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
import '../../core/services/freeze_bank.dart';
import '../../core/services/health_sync_service.dart';
import '../../core/services/streak_warning_service.dart';
import '../../domain/repositories/category_repository.dart';
import '../../core/logging/log.dart';
import '../../domain/entities/momentum.dart';
import '../../core/services/reminder_service.dart';
import '../../core/services/vacation_notice_service.dart';
import '../../core/services/weekly_review_service.dart';
import '../../domain/services/vacation_notice_planner.dart';
import '../../domain/entities/reminder_settings.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:clock/clock.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:flutter/foundation.dart' show mapEquals;
import '../../core/services/habit_order.dart';
import '../../domain/services/habit_arrangement.dart';
import '../../domain/sync/habit_change_listener.dart';
import 'category_provider.dart';

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

  // Null: vacation mode sends no check-ins or welcome back
  final VacationNoticeService? _vacationNotices;

  // Null: the week in review isn't announced (it still shows on Insights)
  final WeeklyReviewService? _weeklyReview;

  // Used to skip sample habits whose category the user has deleted
  final CategoryRepository? _categoryRepository;

  // Null disables filling habits in from Apple Health / Health Connect
  final HealthSyncService? _health;

  // Null: freezes cost nothing (tests that don't exercise the bank)
  final FreezeBank? _freezes;

  /// Told about every change made here, for sync (null while sync is off).
  /// Numbers from Health aren't passed on, and nor is what came from other
  /// devices ([applySynced] doesn't go through here).
  HabitChangeListener? syncListener;

  void _tellSync(Habit? before, Habit? after) {
    if (_fromHealth) return;
    syncListener?.habitChanged(before, after);
  }

  HabitProvider({
    required GetHabitsUseCase getHabitsUseCase,
    required CreateHabitUseCase createHabitUseCase,
    required UpdateHabitUseCase updateHabitUseCase,
    required DeleteHabitUseCase deleteHabitUseCase,
    this.seedDefaultHabit = false,
    StreakWarningService? streakWarningService,
    ReminderService? reminderService,
    VacationNoticeService? vacationNotices,
    WeeklyReviewService? weeklyReview,
    CategoryRepository? categoryRepository,
    HealthSyncService? healthSync,
    FreezeBank? freezeBank,
    HabitOrder? habitOrder,
    CategoryProvider? categories,
  })  : _order = habitOrder,
        _categories = categories,
        _streakWarnings = streakWarningService,
        _freezes = freezeBank,
        _health = healthSync,
        _reminders = reminderService,
        _vacationNotices = vacationNotices,
        _weeklyReview = weeklyReview,
        _categoryRepository = categoryRepository,
        _getHabitsUseCase = getHabitsUseCase,
        _createHabitUseCase = createHabitUseCase,
        _updateHabitUseCase = updateHabitUseCase,
        _deleteHabitUseCase = deleteHabitUseCase {
    _categories?.addListener(_categoriesChanged);
    _ranks = _ranksOf(_categories);
  }

  /// The person's order for their habits (Arrange); none in some tests.
  final HabitOrder? _order;

  /// The categories, whose order habits follow when grouped.
  final CategoryProvider? _categories;
  Map<String, int> _ranks = const {};

  static Map<String, int> _ranksOf(CategoryProvider? categories) =>
      {for (final c in categories?.categories ?? const <Category>[]) c.id: c.sortOrder};

  /// Categories reordered, added or deleted: habits follow, when grouped.
  void _categoriesChanged() {
    final ranks = _ranksOf(_categories);
    if (mapEquals(ranks, _ranks)) return;
    _ranks = ranks;
    _arrange();
    notifyListeners();
  }

  /// Puts [_habits] in the person's order (see [HabitArrangement]).
  void _arrange() {
    _habits = HabitArrangement.arrange(
      _habits,
      order: _order?.ids ?? const [],
      categoryRanks: _ranks,
      grouped: groupByCategory,
    );
  }

  /// The order changed underneath (sync brought it): habits follow.
  void refreshOrder() {
    _arrange();
    notifyListeners();
  }

  /// Habits follow their category's order (Arrange's switch).
  bool get groupByCategory => _order?.groupByCategory ?? true;

  /// Arrange's switch. Turning it off keeps the order as shown, so nothing
  /// moves until the person moves it.
  Future<void> setGroupByCategory(bool grouped) async {
    final order = _order;
    if (order == null || grouped == groupByCategory) return;
    if (!grouped) await order.setIds([for (final h in _habits) h.id]);
    await order.setGroupByCategory(grouped);
    _arrange();
    notifyListeners();
  }

  /// Moves a habit to [index] of the list as shown (Arrange). Only the order
  /// is saved; the habits themselves don't change.
  Future<void> moveHabit(String habitId, int index) async {
    final order = _order;
    if (order == null) return;
    await order.setIds(HabitArrangement.move(_habits, habitId, index));
    _arrange();
    notifyListeners();
  }

  @override
  void dispose() {
    _categories?.removeListener(_categoriesChanged);
    super.dispose();
  }

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
  /// passed (a clean run logs nothing). Each counts as much as it has formed
  /// ([Momentum.overall]), so starting a habit doesn't drag it down. Null
  /// when there's nothing to average.
  Momentum? get overallMomentum {
    final now = clock.now();
    return Momentum.overall([for (final h in _habits) if (h.countsTowardMomentumAt(now)) h.momentum]);
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
      // (saved in one write), and show those habits as they now are
      List<Habit>? refreshed;
      try {
        refreshed = (await _updateHabitUseCase.refreshAll()).all;
      } catch (e) {
        logWarning('Period reset failed, loading habits anyway: $e');
      }

      final habits = refreshed ?? await _getHabitsUseCase();
      _habits = habits;
      _arrange();
      
      // Seed example habits into empty storage (development convenience)
      if (seedDefaultHabit && _habits.isEmpty) {
        await addSampleHabits();
      }
      
      _setState(HabitProviderState.loaded);
      // A full reload schedules everything afresh
      await _streakWarnings?.syncAll(_habits, replace: true);
      await _reminders?.syncAll(_habits, replace: true);
      await _vacationNotices?.sync(vacationForNotices, replace: true);
      await _weeklyReview?.sync(weeklyReviewInput, replace: true);
      // Habits being broken that ended a frozen day clean, while closed
      await _returnUnneededFreezes();
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
      _tellSync(null, habit);
      await _streakWarnings?.sync(habit);
      await _reminders?.syncAll(_habits);
      await _weeklyReview?.sync(weeklyReviewInput);

      _arrange();
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
    Habit? shown;
    return _applyNow(
      habitId,
      (habit) {
        final floor = _floorFor(habit);
        final updated = habit.updateProgress(newProgress, floor: floor);
        if (updated.progress > newProgress && newProgress < habit.progress) {
          _sayFloor(updated, updated.progress, clock.now(), period: true);
        }
        return shown = updated;
      },
      (pending) {
        if (shown?.health == null) {
          pending.progress = newProgress;
        } else {
          // Linked to Health: saved day by day, as shown (no day below Health's number)
          pending.progress = null;
          pending.days.addAll(shown!.periodDays(clock.now()));
        }
      },
    );
  }

  /// The least each day of [habit] may hold (what Health says), or null
  /// when it isn't linked.
  int Function(DateTime day)? _floorFor(Habit habit) {
    final health = _health;
    if (health == null || habit.health == null || habit.isBreak) return null;
    return (day) => health.floorOn(habit, day);
  }

  /// Says that [habit] can't go below Health's number [amount] (for [day],
  /// or its period so far).
  void _sayFloor(Habit habit, int amount, DateTime day, {bool period = false}) {
    final name = _health?.source.name ?? 'Health';
    final units = habit.units.trim().isEmpty ? '' : ' ${habit.units.trim()}';
    final now = clock.now();
    final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
    final String when;
    if (!period || habit.schedule.isEveryDay || habit.schedule.hasRestDays) {
      when = isToday ? 'today' : 'on ${DateFormat.MMMd().format(day)}';
    } else {
      when = switch (habit.resetFrequency) {
        ResetFrequency.weekly when habit.resetInterval == 1 => 'this week',
        ResetFrequency.monthly when habit.resetInterval == 1 => 'this month',
        _ => 'so far',
      };
    }
    _healthNotice = '$name shows ${NumberFormat.decimalPattern().format(amount)}$units $when. Change it in $name.';
  }

  /// Sets what was logged on several days at once: clearing a period, or
  /// putting one back (undo). Shows immediately and saves in the background
  /// like progress.
  Future<bool> setDays(String habitId, Map<DateTime, int> amounts) {
    var days = amounts;
    return _applyNow(
      habitId,
      (habit) {
        // Never below what Health says (unless this is Health's own number)
        final floor = _fromHealth ? null : _floorFor(habit);
        if (floor == null) return habit.setDays(days);
        days = Map.of(amounts);
        DateTime? held;
        for (final entry in amounts.entries) {
          final least = floor(entry.key);
          if (entry.value < least) {
            days[entry.key] = least;
            held ??= entry.key;
          }
        }
        final updated = habit.setDays(days);
        if (held != null) _sayFloor(updated, days[held]!, held);
        return updated;
      },
      (pending) {
        // Setting today replaces a waiting progress change (which sets today)
        final now = clock.now();
        if (days.keys.any((d) => d.year == now.year && d.month == now.month && d.day == now.day)) {
          pending.progress = null;
        }
        pending.days.addAll(days);
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
        // Against the habit as it is now: a tap made while Health was being
        // read stays if it's higher
        final current = getHabitById(entry.key);
        if (current == null) continue;
        final days = {
          for (final day in entry.value.entries)
            if (day.value > (current.history[day.key] ?? 0)) day.key: day.value,
        };
        if (days.isEmpty) continue;
        // Numbers from Health aren't logged back to it
        _fromHealth = true;
        final saved = setDays(entry.key, days);
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

  /// Changes waiting to be logged to Health, and whether they're being
  /// logged: one at a time, in order, so quick taps never race.
  final List<(Habit, Habit)> _toMirror = [];
  bool _mirroring = false;

  /// Logs a change to a habit that logs to Health, behind the tap. When
  /// Health holds more than the app wrote, its number comes back.
  void _mirrorToHealth(Habit before, Habit after) {
    final health = _health;
    if (health == null || _fromHealth || !(after.health?.logsToHealth ?? false)) return;
    _toMirror.add((before, after));
    if (!_mirroring) _mirrorNext(health);
  }

  Future<void> _mirrorNext(HealthSyncService health) async {
    _mirroring = true;
    try {
      while (_toMirror.isNotEmpty) {
        final (before, after) = _toMirror.removeAt(0);
        final notice = await health.logChange(before, after);
        if (notice == null) continue;
        _healthNotice = notice;
        notifyListeners();
        syncHealth(force: true);
      }
    } finally {
      _mirroring = false;
    }
  }

  /// Health won't let the app read (Android says so; null until known).
  bool get healthAccessMissing => _health?.accessAllowed == false;

  /// Health had nothing for [habit] all week (likely not allowed, on iPhone).
  bool healthReadsNothing(Habit habit) => _health?.readsNothing(habit) ?? false;

  /// Asks for Health access again, then syncs.
  Future<void> askHealthAccessAgain() async {
    final health = _health;
    if (health == null) return;
    await health.askAgain(_habits);
    notifyListeners();
    await syncHealth(force: true);
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

  // Freezes and vacation mode

  /// The bank freezes come from, if there is one.
  FreezeBank? get freezes => _freezes;

  /// Spends a freeze on [habitId]'s period containing [date]: it's neither
  /// kept nor missed. False (with [error] saying why) if it can't go there or
  /// the bank is empty.
  Future<bool> freeze(String habitId, DateTime date) async {
    final habit = getHabitById(habitId);
    if (habit == null) return false;
    final now = clock.now();
    final day = DateTime(date.year, date.month, date.day);
    final why = habit.whyNoFreeze(day, now);
    if (why != null) {
      _error = why;
      notifyListeners();
      return false;
    }
    final bank = _freezes;
    if (bank != null && !await bank.spend(now)) {
      _error = 'No freezes left';
      notifyListeners();
      return false;
    }
    final saved = await _applyNow(habitId, (h) => h.freeze(day), (pending) => pending.frozen[day] = true);
    if (!saved) await bank?.refund(now);
    return saved;
  }

  /// Takes the freeze off [habitId]'s period containing [date]; it goes back
  /// to the bank.
  Future<bool> unfreeze(String habitId, DateTime date) async {
    final habit = getHabitById(habitId);
    if (habit == null || !habit.isFrozenOn(date)) return false;
    final day = DateTime(date.year, date.month, date.day);
    final saved = await _applyNow(habitId, (h) => h.unfreeze(day), (pending) => pending.frozen[day] = false);
    if (saved) await _freezes?.refund(clock.now());
    return saved;
  }

  /// "Your freeze came back", once, for the Habits screen to show.
  String? _freezeNotice;
  String? takeFreezeNotice() {
    final notice = _freezeNotice;
    _freezeNotice = null;
    return notice;
  }

  bool _returningFreezes = false;

  /// Gives back freezes that turned out not to be needed: the frozen period
  /// was kept anyway (or, breaking a habit, ended clean).
  Future<void> _returnUnneededFreezes() async {
    if (_returningFreezes) return;
    _returningFreezes = true;
    try {
      final now = clock.now();
      for (final habit in List.of(_habits)) {
        final days = habit.unneededFreezes(now);
        if (days.isEmpty) continue;
        final saved = await _applyNow(
          habit.id,
          (h) => days.fold(h, (updated, day) => updated.unfreeze(day)),
          (pending) {
            for (final day in days) {
              pending.frozen[day] = false;
            }
          },
        );
        if (!saved) continue;
        await _freezes?.refund(now, days.length);
        _freezeNotice = habit.isBreak
            ? 'No slips while ${habit.name} was frozen, so the freeze came back.'
            : 'You kept ${habit.name} anyway, so its freeze came back.';
      }
    } finally {
      _returningFreezes = false;
    }
  }

  /// Vacation mode is on (a habit has a pause not ended and not yet back).
  bool get onVacation => _habits.any((h) => h.isOnVacation);

  /// Vacation mode as notifications see it (when it started, and the return
  /// day), or null while it's off.
  VacationPlan? get vacation {
    for (final habit in _habits) {
      if (habit.isOnVacation) return VacationPlan(since: habit.pauses.last.from, back: habit.vacationBack);
    }
    return null;
  }

  /// The day vacation mode ends by itself, if it's on with one.
  DateTime? get vacationBack => vacation?.back;

  /// What vacation notices are planned from: vacation mode while it's on,
  /// and on the return day itself (it has ended by then), so that
  /// morning's welcome back still comes after the app is opened early.
  VacationPlan? get vacationForNotices {
    final on = vacation;
    if (on != null) return on;
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final habit in _habits) {
      final last = habit.pauses.isEmpty ? null : habit.pauses.last;
      if (last != null && last.back == today) return VacationPlan(since: last.from, back: today);
    }
    return null;
  }

  /// Pauses every habit from today: nothing is due, no reminders or
  /// warnings, streaks and momentum hold. Costs no freezes. With [back], it
  /// ends by itself that morning: habits and their reminders pick up then.
  Future<bool> startVacation({DateTime? back}) => _setVacation(true, back: back);

  /// Ends vacation mode; today stays paused.
  Future<bool> endVacation() => _setVacation(false);

  /// Moves the return day while vacation mode is on (null: until it's
  /// turned off).
  Future<bool> setVacationReturn(DateTime? back) async {
    final day = back == null ? null : DateTime(back.year, back.month, back.day);
    var allSaved = true;
    for (final habit in List.of(_habits)) {
      if (!habit.isOnVacation) continue;
      final saved = await _applyNow(
        habit.id,
        (h) => h.planReturn(day),
        (pending) => pending
          ..returnChanged = true
          ..returnDay = day,
      );
      allSaved &= saved;
    }
    return allSaved;
  }

  Future<bool> _setVacation(bool on, {DateTime? back}) async {
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final returnDay = back == null ? null : DateTime(back.year, back.month, back.day);
    var allSaved = true;
    for (final habit in List.of(_habits)) {
      if (!habit.schedule.isPeriodic || habit.isOnVacation == on) continue;
      final saved = await _applyNow(
        habit.id,
        (h) => on ? h.startPause(today, back: returnDay) : h.endPause(today),
        (pending) => pending
          ..vacation = on
          ..vacationDay = today
          ..vacationBack = returnDay,
      );
      allSaved &= saved;
    }
    return allSaved;
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
    _tellSync(current, _habits[index]);

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
          if (pending.delete) {
            await _deleteHabitUseCase(habitId);
            _lastSaved.remove(habitId);
            continue;
          }
          if (pending.replace != null) saved = await _updateHabitUseCase.putSynced(pending.replace!);
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
          for (final entry in pending.frozen.entries) {
            saved = await _updateHabitUseCase.setFrozenForDate(habitId, entry.key, entry.value);
          }
          if (pending.vacation != null) {
            saved = await _updateHabitUseCase.setOnVacation(habitId, pending.vacationDay!, pending.vacation!,
                back: pending.vacationBack);
          }
          if (pending.returnChanged) saved = await _updateHabitUseCase.setVacationReturn(habitId, pending.returnDay);
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
          if (stored != null) {
            _tellSync(getHabitById(habitId), stored);
            _replaceHabit(stored);
          }
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
    _vacationNotices?.sync(vacationForNotices);
    _weeklyReview?.sync(weeklyReviewInput);
    // A frozen period kept anyway gives its freeze back
    await _returnUnneededFreezes();
    return allSaved;
  }


  /// Once what was started here has finished, or after [most]: saves,
  /// Health, and planning notifications again. Work in the background
  /// (sync, Health) ends only after it, so iOS doesn't stop it halfway.
  Future<void> whenSettled({Duration most = const Duration(seconds: 10)}) async {
    bool busy() =>
        _saving ||
        _healthSyncing ||
        _mirroring ||
        (_reminders?.isBusy ?? false) ||
        (_vacationNotices?.isBusy ?? false) ||
        (_weeklyReview?.isBusy ?? false);
    final waited = Stopwatch()..start();
    while (busy() && waited.elapsed < most) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  /// Brings in what other devices changed (sync). [changes] is handed this
  /// device's habits and returns the ones that differ once merged, by id
  /// (null: deleted there). It runs at once, so a tap made a moment ago is
  /// already in what it returns. The changes show straight away and are
  /// saved through the queue taps use, before anything tapped after this.
  Future<void> applySynced(Map<String, Habit?> Function(Map<String, Habit> local) changes) async {
    final result = changes({for (final habit in _habits) habit.id: habit});
    if (result.isEmpty) return;
    for (final entry in result.entries) {
      final index = _habits.indexWhere((habit) => habit.id == entry.key);
      final merged = entry.value;
      if (merged == null) {
        if (index < 0) continue;
        _habits.removeAt(index);
        _unsaved[entry.key] = _PendingChange()..delete = true;
        _streakWarnings?.cancel(entry.key);
        continue;
      }
      if (index < 0) {
        _habits.add(merged);
      } else {
        _lastSaved.putIfAbsent(entry.key, () => _habits[index]);
        _habits[index] = merged;
      }
      // What was waiting to be saved is already part of the merged habit
      _unsaved[entry.key] = _PendingChange()..replace = merged;
      _streakWarnings?.sync(merged);
    }
    final order = _order;
    final gone = {for (final e in result.entries) if (e.value == null) e.key};
    if (order != null && gone.any(order.ids.contains)) {
      await order.setIds([for (final id in order.ids) if (!gone.contains(id)) id]);
    }
    _arrange();
    notifyListeners();
    if (!_saving) await _saveChanges();
    // Days filled in from this device's Health stay above what came in
    syncHealth();
  }

  Future<bool> updateHabitDetails(String habitId, UpdateHabitParams params) async {
    try {
      _setOperationInProgress(true);
      
      final before = getHabitById(habitId);
      final updatedHabit = await _updateHabitUseCase.updateDetails(habitId, params);
      _tellSync(before, updatedHabit);
      _updateHabitInList(updatedHabit);
      // A new category: to the end of that category's habits
      if (before != null && before.categoryId != updatedHabit.categoryId && _order != null) {
        await _order.setIds([for (final h in _habits) if (h.id != habitId) h.id, habitId]);
        _arrange();
        notifyListeners();
      }
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
      
      final before = getHabitById(habitId);
      await _deleteHabitUseCase(habitId);
      _habits.removeWhere((habit) => habit.id == habitId);
      if (before != null) _tellSync(before, null);
      final order = _order;
      if (order != null && order.ids.contains(habitId)) await order.setIds([...order.ids]..remove(habitId));
      await _reminders?.syncAll(_habits);
      await _weeklyReview?.sync(weeklyReviewInput);

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
      await _vacationNotices?.sync(vacationForNotices);
      await _weeklyReview?.sync(weeklyReviewInput);
      await _returnUnneededFreezes();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _setOperationInProgress(false);
    }
  }

  /// Retroactively set what was logged on [date] (Calendar); recomputes
  /// the streak. Goes the way taps do, so today's change reaches Health and
  /// no day goes below Health's number.
  Future<bool> updateProgressForDate(String habitId, DateTime date, int amount) =>
      setDays(habitId, {DateTime(date.year, date.month, date.day): amount});

  /// Re-plan every streak warning, e.g. after the warning settings change.
  Future<void> resyncStreakWarnings() async {
    await _streakWarnings?.syncAll(_habits);
    // Warnings may now need more (or less) of iOS's 64, which reminders share
    await _reminders?.syncAll(_habits);
    // Quiet hours move vacation notices and the week in review too
    await _vacationNotices?.sync(vacationForNotices);
    await _weeklyReview?.sync(weeklyReviewInput);
  }

  /// Re-plan the week-in-review notification, e.g. after its switch, its
  /// time or the week start changes.
  Future<void> resyncWeeklyReview() async => _weeklyReview?.sync(weeklyReviewInput);

  /// What the week in review is planned from: when the first habit began
  /// being tracked, and vacation mode.
  WeeklyReviewInput get weeklyReviewInput {
    DateTime? since;
    for (final habit in _habits) {
      if (!habit.schedule.isPeriodic) continue;
      final from = habit.trackedFrom;
      if (since == null || from.isBefore(since)) since = from;
    }
    return (trackedSince: since, vacation: vacationForNotices);
  }

  /// Re-plan vacation mode's notifications, e.g. after their switch or the
  /// default reminder time changes.
  Future<void> resyncVacationNotices() async => _vacationNotices?.sync(vacationForNotices);

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
  /// The whole habit as merged from another device's changes (sync), saved
  /// before anything tapped since; or the habit deleted there.
  Habit? replace;
  bool delete = false;

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

  /// Day -> frozen (a freeze spent) or not (taken back).
  final Map<DateTime, bool> frozen = {};

  /// Vacation mode started (true, until [vacationBack] if set) or ended
  /// (false) on [vacationDay].
  bool? vacation;
  DateTime? vacationDay;
  DateTime? vacationBack;

  /// The return day moved to [returnDay] (null: none).
  bool returnChanged = false;
  DateTime? returnDay;
}
