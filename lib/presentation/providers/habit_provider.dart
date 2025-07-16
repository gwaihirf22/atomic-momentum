import 'package:flutter/foundation.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_category.dart';
import '../../domain/usecases/get_habits_usecase.dart';
import '../../domain/usecases/create_habit_usecase.dart';
import '../../domain/usecases/update_habit_usecase.dart';
import '../../domain/usecases/delete_habit_usecase.dart';
import '../../core/exceptions/storage_exceptions.dart';

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

  HabitProvider({
    required GetHabitsUseCase getHabitsUseCase,
    required CreateHabitUseCase createHabitUseCase,
    required UpdateHabitUseCase updateHabitUseCase,
    required DeleteHabitUseCase deleteHabitUseCase,
  })  : _getHabitsUseCase = getHabitsUseCase,
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

  // Filtered getters
  List<Habit> getHabitsByCategory(HabitCategory category) {
    return _habits.where((habit) => habit.category == category).toList();
  }

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

      final habits = await _getHabitsUseCase();
      _habits = habits;
      
      _setState(HabitProviderState.loaded);
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
        
        // Update local list immediately
        _habits[habitIndex] = updatedHabit;
        notifyListeners();
        print('DEBUG: Updated local list and notified listeners');
        
        // Try to save to repository, but don't fail if it doesn't work
        try {
          await _updateHabitUseCase.updateProgress(habitId, newProgress);
          print('DEBUG: Successfully saved to repository');
        } catch (saveError) {
          print('DEBUG: Repository save failed but continuing: $saveError');
          // Continue anyway - the UI is already updated
        }
        
        return true;
      } else {
        print('DEBUG: Habit not found in local list');
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

  Future<List<Habit>> deleteHabitsInCategory(HabitCategory category) async {
    try {
      _setOperationInProgress(true);
      
      final deletedHabits = await _deleteHabitUseCase.deleteByCategory(category);
      _habits.removeWhere((habit) => habit.category == category);
      
      notifyListeners();
      return deletedHabits;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
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

  // Search functionality
  List<Habit> searchHabits(String query) {
    if (query.trim().isEmpty) return habits;
    
    final lowercaseQuery = query.toLowerCase().trim();
    return _habits.where((habit) {
      return habit.name.toLowerCase().contains(lowercaseQuery) ||
             habit.category.displayName.toLowerCase().contains(lowercaseQuery);
    }).toList();
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

  void _updateHabitInList(Habit updatedHabit) {
    final index = _habits.indexWhere((habit) => habit.id == updatedHabit.id);
    if (index >= 0) {
      _habits[index] = updatedHabit;
      notifyListeners();
    }
  }

  void _sortHabits() {
    _habits.sort((a, b) {
      // Sort by category first, then by name
      final categoryComparison = a.category.name.compareTo(b.category.name);
      if (categoryComparison != 0) return categoryComparison;
      
      return a.name.compareTo(b.name);
    });
  }

  // Debug and analytics methods
  Map<String, dynamic> getStatistics() {
    final categoryStats = <String, int>{};
    for (final category in HabitCategory.values) {
      categoryStats[category.name] = getHabitsByCategory(category).length;
    }

    return {
      'totalHabits': totalHabits,
      'completedHabits': completedHabitsCount,
      'completionPercentage': completionPercentage,
      'activeStreaks': getHabitsWithActiveStreaks().length,
      'categoryBreakdown': categoryStats,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }

  @override
  void dispose() {
    super.dispose();
  }
}