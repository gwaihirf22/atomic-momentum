// Flutter's foundation library has its own Category class
import 'package:flutter/foundation.dart' show ChangeNotifier;
import '../../domain/entities/category.dart';
import '../../domain/entities/habit.dart';
import '../../domain/repositories/category_repository.dart';

/// The user's categories and the Habits screen's category filter.
///
/// A habit whose category id isn't an active category (deleted, or unknown)
/// resolves to [Category.uncategorized]; habits are never rewritten for it.
class CategoryProvider extends ChangeNotifier {
  final CategoryRepository _repository;

  CategoryProvider(this._repository);

  List<Category> _all = const [];
  String? _selectedCategoryId;

  Future<void> load() async {
    _all = await _repository.getAll();
    notifyListeners();
  }

  /// Active categories in the user's order.
  List<Category> get categories => [for (final c in _all) if (!c.isDeleted) c];

  /// Recently Deleted, newest first.
  List<Category> get deletedCategories =>
      [for (final c in _all) if (c.isDeleted) c]..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));

  bool isActive(String id) => _all.any((c) => c.id == id && !c.isDeleted);

  Category resolve(String id) {
    for (final c in _all) {
      if (c.id == id && !c.isDeleted) return c;
    }
    return Category.uncategorized;
  }

  /// Categories to offer as filters: the active ones, plus Uncategorized
  /// while some habit is in a deleted or unknown category.
  List<Category> filterOptions(List<Habit> habits) => [
        ...categories,
        if (habits.any((h) => !isActive(h.categoryId))) Category.uncategorized,
      ];

  // Selection

  String? get selectedCategoryId => _selectedCategoryId;

  /// The selected category, or null for "all habits" (including when the
  /// selected one has since been deleted).
  Category? get selectedCategory {
    final id = _selectedCategoryId;
    if (id == null) return null;
    if (id == Category.uncategorizedId) return Category.uncategorized;
    return isActive(id) ? resolve(id) : null;
  }

  void setSelectedCategoryId(String? id) {
    if (_selectedCategoryId != id) {
      _selectedCategoryId = id;
      notifyListeners();
    }
  }

  void clearSelectedCategory() => setSelectedCategoryId(null);

  void toggleCategory(String id) =>
      setSelectedCategoryId(_selectedCategoryId == id ? null : id);

  /// Drops a selection that no longer matches anything, e.g. Uncategorized
  /// once no habit is uncategorized.
  void updateAvailableCategories(List<Habit> habits) {
    final id = _selectedCategoryId;
    if (id == null) return;
    final stillValid = id == Category.uncategorizedId
        ? habits.any((h) => !isActive(h.categoryId))
        : isActive(id);
    if (!stillValid) clearSelectedCategory();
  }

  bool matches(Habit habit, String categoryId) => categoryId == Category.uncategorizedId
      ? !isActive(habit.categoryId)
      : habit.categoryId == categoryId;

  List<Habit> filterHabits(List<Habit> habits) {
    final selected = selectedCategory;
    if (selected == null) return habits;
    return habits.where((habit) => matches(habit, selected.id)).toList();
  }

  /// Completion stats per category id (only categories with habits).
  Map<String, CategoryStats> getCategoryStats(List<Habit> habits) {
    final statsMap = <String, CategoryStats>{};

    for (final category in filterOptions(habits)) {
      final categoryHabits = habits.where((habit) => matches(habit, category.id)).toList();

      if (categoryHabits.isNotEmpty) {
        final completedCount = categoryHabits.where((habit) => habit.isCompleted).length;
        final totalProgress = categoryHabits.fold(0, (sum, habit) => sum + habit.progress);
        final totalTarget = categoryHabits.fold(0, (sum, habit) => sum + habit.target);
        final averageProgress =
            categoryHabits.map((h) => h.progressPercentage).reduce((a, b) => a + b) / categoryHabits.length;

        statsMap[category.id] = CategoryStats(
          totalHabits: categoryHabits.length,
          completedHabits: completedCount,
          totalProgress: totalProgress,
          totalTarget: totalTarget,
          averageProgress: averageProgress,
          completionPercentage: (completedCount / categoryHabits.length) * 100,
        );
      }
    }

    return statsMap;
  }

  @override
  String toString() => 'CategoryProvider(selected: $_selectedCategoryId, categories: ${categories.length})';
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
