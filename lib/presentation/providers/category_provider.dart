import 'package:flutter/foundation.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_category.dart';

class CategoryProvider extends ChangeNotifier {
  HabitCategory? _selectedCategory;
  final Set<HabitCategory> _availableCategories = {};

  // Getters
  HabitCategory? get selectedCategory => _selectedCategory;
  List<HabitCategory> get availableCategories => _availableCategories.toList();
  bool get hasSelectedCategory => _selectedCategory != null;
  bool get isShowingAll => _selectedCategory == null;

  // Actions
  void setSelectedCategory(HabitCategory? category) {
    if (_selectedCategory != category) {
      _selectedCategory = category;
      notifyListeners();
    }
  }

  void clearSelectedCategory() {
    if (_selectedCategory != null) {
      _selectedCategory = null;
      notifyListeners();
    }
  }

  void toggleCategory(HabitCategory category) {
    if (_selectedCategory == category) {
      clearSelectedCategory();
    } else {
      setSelectedCategory(category);
    }
  }

  // Update available categories based on current habits
  void updateAvailableCategories(List<Habit> habits) {
    final newCategories = habits.map((habit) => habit.category).toSet();
    
    if (!setEquals(_availableCategories, newCategories)) {
      _availableCategories.clear();
      _availableCategories.addAll(newCategories);
      
      // Clear selected category if it's no longer available
      if (_selectedCategory != null && !_availableCategories.contains(_selectedCategory)) {
        _selectedCategory = null;
      }
      
      notifyListeners();
    }
  }

  // Filter habits by selected category
  List<Habit> filterHabits(List<Habit> habits) {
    updateAvailableCategories(habits);
    
    if (_selectedCategory == null) {
      return habits;
    }
    
    return habits.where((habit) => habit.category == _selectedCategory).toList();
  }

  // Get habit count for each category
  Map<HabitCategory, int> getHabitCountByCategory(List<Habit> habits) {
    final countMap = <HabitCategory, int>{};
    
    for (final category in HabitCategory.values) {
      countMap[category] = habits.where((habit) => habit.category == category).length;
    }
    
    return countMap;
  }

  // Get completion stats by category
  Map<HabitCategory, CategoryStats> getCategoryStats(List<Habit> habits) {
    final statsMap = <HabitCategory, CategoryStats>{};
    
    for (final category in HabitCategory.values) {
      final categoryHabits = habits.where((habit) => habit.category == category).toList();
      
      if (categoryHabits.isNotEmpty) {
        final completedCount = categoryHabits.where((habit) => habit.isCompleted).length;
        final totalProgress = categoryHabits.fold(0, (sum, habit) => sum + habit.progress);
        final totalTarget = categoryHabits.fold(0, (sum, habit) => sum + habit.target);
        final averageProgress = categoryHabits.isNotEmpty 
            ? categoryHabits.map((h) => h.progressPercentage).reduce((a, b) => a + b) / categoryHabits.length
            : 0.0;
        
        statsMap[category] = CategoryStats(
          totalHabits: categoryHabits.length,
          completedHabits: completedCount,
          totalProgress: totalProgress,
          totalTarget: totalTarget,
          averageProgress: averageProgress,
          completionPercentage: categoryHabits.isNotEmpty 
              ? (completedCount / categoryHabits.length) * 100 
              : 0.0,
        );
      }
    }
    
    return statsMap;
  }

  // Get categories sorted by habit count
  List<HabitCategory> getCategoriesSortedByCount(List<Habit> habits) {
    final countMap = getHabitCountByCategory(habits);
    final availableCategories = countMap.entries
        .where((entry) => entry.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // Sort by count descending
    
    return availableCategories.map((entry) => entry.key).toList();
  }

  // Reset to initial state
  void reset() {
    _selectedCategory = null;
    _availableCategories.clear();
    notifyListeners();
  }

  // Persistence helpers
  Map<String, dynamic> toJson() {
    return {
      'selectedCategory': _selectedCategory?.name,
      'availableCategories': _availableCategories.map((c) => c.name).toList(),
    };
  }

  void fromJson(Map<String, dynamic> json) {
    if (json['selectedCategory'] != null) {
      try {
        _selectedCategory = HabitCategory.fromString(json['selectedCategory'] as String);
      } catch (e) {
        _selectedCategory = null;
      }
    }
    
    if (json['availableCategories'] != null) {
      try {
        final categoryNames = (json['availableCategories'] as List<dynamic>).cast<String>();
        _availableCategories.clear();
        for (final name in categoryNames) {
          try {
            _availableCategories.add(HabitCategory.fromString(name));
          } catch (e) {
            // Skip invalid category names
          }
        }
      } catch (e) {
        _availableCategories.clear();
      }
    }
    
    notifyListeners();
  }

  @override
  String toString() => 'CategoryProvider(selected: $_selectedCategory, available: ${_availableCategories.length})';
}

class CategoryStats {
  final int totalHabits;
  final int completedHabits;
  final int totalProgress;
  final int totalTarget;
  final double averageProgress;
  final double completionPercentage;

  const CategoryStats({
    required this.totalHabits,
    required this.completedHabits,
    required this.totalProgress,
    required this.totalTarget,
    required this.averageProgress,
    required this.completionPercentage,
  });

  @override
  String toString() => 'CategoryStats(total: $totalHabits, completed: $completedHabits, percentage: ${completionPercentage.toStringAsFixed(1)}%)';
}