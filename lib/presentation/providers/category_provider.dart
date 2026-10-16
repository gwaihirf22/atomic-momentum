import 'package:flutter/foundation.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_category.dart';

class CategoryProvider extends ChangeNotifier {
  HabitCategory? _selectedCategory;
  final Set<HabitCategory> _availableCategories = {};

  // Getters
  HabitCategory? get selectedCategory => _selectedCategory;

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

  // Filter habits by selected category (without triggering updates during build)
  List<Habit> filterHabits(List<Habit> habits) {
    // Don't update available categories during filtering to avoid setState during build
    // This will be handled separately by the calling widget
    
    if (_selectedCategory == null) {
      return habits;
    }
    
    return habits.where((habit) => habit.category == _selectedCategory).toList();
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