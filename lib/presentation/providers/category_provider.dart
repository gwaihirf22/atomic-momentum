// Flutter's foundation library has its own Category class
import 'package:flutter/foundation.dart' show ChangeNotifier;
import '../../domain/entities/category.dart';
import '../../domain/entities/habit.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/usecases/manage_categories_usecase.dart';
import '../../core/exceptions/storage_exceptions.dart';

/// The user's categories and the Habits screen's category filter.
///
/// A habit whose category id isn't an active category (deleted, or unknown)
/// resolves to [Category.uncategorized]; habits are never rewritten for it.
class CategoryProvider extends ChangeNotifier {
  final CategoryRepository _repository;
  final ManageCategoriesUseCase _manage;

  CategoryProvider(this._repository, this._manage);

  List<Category> _all = const [];
  String? _selectedCategoryId;
  String? _error;

  /// Why the last edit failed, in words to show the user.
  String? get error => _error;

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

  // Editing (the Categories page). Each returns false and sets [error] when
  // a rule blocks it.

  Future<bool> add({required String name, required String iconKey, required int colorValue}) =>
      _run(() => _manage.add(name: name, iconKey: iconKey, colorValue: colorValue));

  Future<bool> update(Category category) => _run(() => _manage.update(category));

  /// Moves the active category at [oldIndex] to [newIndex] (ReorderableListView
  /// indices). Shown immediately; reloaded from storage if saving fails.
  Future<bool> reorder(int oldIndex, int newIndex) async {
    final ordered = List.of(categories);
    if (newIndex > oldIndex) newIndex -= 1;
    ordered.insert(newIndex, ordered.removeAt(oldIndex));

    final order = {for (var i = 0; i < ordered.length; i++) ordered[i].id: i};
    _all = [for (final c in _all) order.containsKey(c.id) ? c.copyWith(sortOrder: order[c.id]) : c]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    notifyListeners();

    return _run(() => _manage.reorder(ordered.map((c) => c.id).toList()));
  }

  /// Moves a category to Recently Deleted; a filter on it is cleared.
  Future<bool> delete(String id) async {
    final ok = await _run(() => _manage.softDelete(id));
    if (ok && _selectedCategoryId == id) clearSelectedCategory();
    return ok;
  }

  /// Returns the category as restored (its name may have changed to avoid a
  /// clash), or null if it couldn't be restored.
  Future<Category?> restore(String id) async {
    Category? restored;
    final ok = await _run(() async {
      restored = await _manage.restore(id);
      return _repository.getAll();
    });
    if (ok && _selectedCategoryId == Category.uncategorizedId) clearSelectedCategory();
    return ok ? restored : null;
  }

  Future<bool> deletePermanently(String id) => _run(() => _manage.deletePermanently(id));

  /// Puts all habits of [fromId] into [toId]; returns how many moved, or null
  /// on failure. Callers reload habits afterwards.
  Future<int?> moveHabits(String fromId, String toId) async {
    int? moved;
    final ok = await _run(() async {
      moved = await _manage.moveHabits(fromId, toId);
      return _repository.getAll();
    });
    return ok ? moved : null;
  }

  Future<bool> _run(Future<List<Category>> Function() operation) async {
    try {
      _all = await operation();
      _error = null;
      notifyListeners();
      return true;
    } on ValidationException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Could not save your categories. Please try again.';
    }
    // Show what's actually stored after a failure
    _all = await _repository.getAll();
    notifyListeners();
    return false;
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
