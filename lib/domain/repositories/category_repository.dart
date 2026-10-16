import '../entities/category.dart';

abstract class CategoryRepository {
  /// All categories, deleted ones included, sorted by sort order. Seeds the
  /// built-in defaults on first use. Never throws: unreadable data falls back
  /// to the defaults.
  Future<List<Category>> getAll();

  /// Replace the stored categories.
  Future<void> saveAll(List<Category> categories);
}
