import '../../domain/entities/category.dart';

class CategoryValidator {
  const CategoryValidator._();

  /// The message to show for an unusable category name, or null if it's fine.
  /// Names are compared trimmed and ignoring case against [active]
  /// categories only, so a deleted category's name can be reused.
  static String? validateName(String raw, Iterable<Category> active, {String? excludeId}) {
    final name = raw.trim();
    if (name.isEmpty) return 'Enter a name';
    if (name.length > Category.maxNameLength) {
      return 'Names can be up to ${Category.maxNameLength} characters';
    }

    final lower = name.toLowerCase();
    if (lower == Category.uncategorized.name.toLowerCase()) return 'That name is reserved';
    for (final category in active) {
      if (category.id != excludeId && category.name.trim().toLowerCase() == lower) {
        return 'You already have a category called ${category.name}';
      }
    }
    return null;
  }
}
