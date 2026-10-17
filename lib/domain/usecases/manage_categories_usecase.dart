import '../entities/category.dart';
import '../repositories/category_repository.dart';
import '../repositories/habit_repository.dart';
import '../../core/exceptions/storage_exceptions.dart';
import '../../core/validation/category_validator.dart';
import 'package:clock/clock.dart';

/// Rules for adding, editing, ordering and deleting categories. Each
/// operation loads the stored categories, applies its rule, saves, and
/// returns the full updated list (deleted categories included).
class ManageCategoriesUseCase {
  final CategoryRepository _categories;
  final HabitRepository _habits;

  ManageCategoriesUseCase(this._categories, this._habits);

  static int _idCounter = 0;

  Future<List<Category>> add({
    required String name,
    required String iconKey,
    required int colorValue,
  }) async {
    final all = await _categories.getAll();
    final active = _active(all);
    if (active.length >= Category.maxCount) {
      throw ValidationException('You can have up to ${Category.maxCount} categories');
    }
    _checkName(name, active);

    final category = Category(
      id: _newId(all),
      name: name.trim(),
      iconKey: iconKey,
      colorValue: colorValue,
      sortOrder: _nextSortOrder(active),
    );
    return _save([...all, category]);
  }

  /// Saves a new name, icon and color. Id, order and deletion state can't be
  /// changed this way.
  Future<List<Category>> update(Category changed) async {
    final all = await _categories.getAll();
    final existing = _find(all, changed.id);
    if (existing.isDeleted) throw ValidationException('Restore this category before editing it');
    _checkName(changed.name, _active(all), excludeId: changed.id);

    final updated = existing.copyWith(
      name: changed.name.trim(),
      iconKey: changed.iconKey,
      colorValue: changed.colorValue,
    );
    return _save([for (final c in all) c.id == updated.id ? updated : c]);
  }

  /// [activeIdsInOrder] must list exactly the active categories.
  Future<List<Category>> reorder(List<String> activeIdsInOrder) async {
    final all = await _categories.getAll();
    final activeIds = _active(all).map((c) => c.id).toSet();
    if (activeIdsInOrder.length != activeIds.length || !activeIds.containsAll(activeIdsInOrder)) {
      throw ValidationException('The new order must include every category exactly once');
    }

    final order = {for (var i = 0; i < activeIdsInOrder.length; i++) activeIdsInOrder[i]: i};
    return _save([
      for (final c in all) order.containsKey(c.id) ? c.copyWith(sortOrder: order[c.id]) : c,
    ]);
  }

  /// Moves the category to Recently Deleted. Its habits keep their category
  /// id (shown as Uncategorized) until it is restored or they are moved.
  Future<List<Category>> softDelete(String id, {DateTime? now}) async {
    final all = await _categories.getAll();
    final category = _find(all, id);
    if (category.isDeleted) return all;
    if (_active(all).length <= 1) throw ValidationException('Keep at least one category');

    final deleted = category.markDeleted(now ?? clock.now());
    return _save([for (final c in all) c.id == id ? deleted : c]);
  }

  /// Brings a deleted category back at the end of the list. If another
  /// category now has its name, it is renamed "Name 2" (or 3, …); the
  /// returned category shows the name it came back with.
  Future<Category> restore(String id) async {
    final all = await _categories.getAll();
    final category = _find(all, id);
    if (!category.isDeleted) return category;

    final active = _active(all);
    if (active.length >= Category.maxCount) {
      throw ValidationException(
          'You already have ${Category.maxCount} categories. Delete one first.');
    }

    final restored = category.restored(
      sortOrder: _nextSortOrder(active),
      name: _availableName(category.name, active),
    );
    await _save([for (final c in all) c.id == id ? restored : c]);
    return restored;
  }

  /// Removes a deleted category for good. Only allowed once no habit uses
  /// it, so habits and their history can never be lost this way.
  Future<List<Category>> deletePermanently(String id) async {
    final all = await _categories.getAll();
    final category = _find(all, id);
    if (!category.isDeleted) {
      throw ValidationException('Delete the category before removing it permanently');
    }
    final habits = await _habits.getHabits();
    if (habits.any((h) => h.categoryId == id)) {
      throw ValidationException('Move or delete its habits first');
    }
    return _save([for (final c in all) if (c.id != id) c]);
  }

  /// Puts every habit in [fromId] into [toId]. Returns how many moved.
  Future<int> moveHabits(String fromId, String toId) async {
    final all = await _categories.getAll();
    final target = _find(all, toId);
    if (target.isDeleted) throw ValidationException('Choose a category that isn\'t deleted');

    final habits = (await _habits.getHabits()).where((h) => h.categoryId == fromId).toList();
    for (final habit in habits) {
      await _habits.saveHabit(habit.copyWith(categoryId: toId));
    }
    return habits.length;
  }

  List<Category> _active(List<Category> all) => [for (final c in all) if (!c.isDeleted) c];

  Category _find(List<Category> all, String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    throw ValidationException('Category not found');
  }

  void _checkName(String name, List<Category> active, {String? excludeId}) {
    final error = CategoryValidator.validateName(name, active, excludeId: excludeId);
    if (error != null) throw ValidationException(error);
  }

  int _nextSortOrder(List<Category> active) =>
      active.isEmpty ? 0 : active.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b) + 1;

  String _newId(List<Category> all) {
    final taken = all.map((c) => c.id).toSet();
    String id;
    do {
      id = 'cat_${clock.now().microsecondsSinceEpoch}_${_idCounter++}';
    } while (taken.contains(id));
    return id;
  }

  // "Mind" -> "Mind 2", "Mind 3", ... trimmed to fit the length limit
  String _availableName(String name, List<Category> active) {
    if (CategoryValidator.validateName(name, active) == null) return name;
    for (var n = 2;; n++) {
      final suffix = ' $n';
      final base = name.length + suffix.length > Category.maxNameLength
          ? name.substring(0, Category.maxNameLength - suffix.length).trimRight()
          : name;
      final candidate = '$base$suffix';
      if (CategoryValidator.validateName(candidate, active) == null) return candidate;
    }
  }

  Future<List<Category>> _save(List<Category> categories) async {
    final sorted = List.of(categories)
      ..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
      });
    await _categories.saveAll(sorted);
    return sorted;
  }
}
