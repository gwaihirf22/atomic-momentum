import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/exceptions/storage_exceptions.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';
import '../../core/logging/log.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  static const storageKey = 'categories_v1';

  /// Where unreadable category data is kept instead of being thrown away.
  static const corruptBackupKey = 'categories_v1_corrupt';

  final SharedPreferences _prefs;

  const CategoryRepositoryImpl(this._prefs);

  @override
  Future<List<Category>> getAll() async {
    final raw = _prefs.getString(storageKey);
    if (raw == null) {
      return _seedDefaults();
    }

    final categories = _parse(raw);
    if (categories == null) {
      logWarning('Warning: Unreadable categories, restoring defaults (raw data kept in $corruptBackupKey)');
      await _prefs.setString(corruptBackupKey, raw);
      return _seedDefaults();
    }
    return categories;
  }

  @override
  Future<void> saveAll(List<Category> categories) async {
    final success = await _prefs.setString(
      storageKey,
      jsonEncode(categories.map((c) => c.toJson()).toList()),
    );
    if (!success) {
      throw StorageException('Failed to write categories to storage');
    }
  }

  Future<List<Category>> _seedDefaults() async {
    const defaults = Category.defaults;
    try {
      await saveAll(defaults);
    } catch (e) {
      // Still usable this session; seeding is retried next launch
      logWarning('Warning: Could not save default categories: $e');
    }
    return List.of(defaults);
  }

  /// Null when the data is unusable as a whole. Individual bad entries are
  /// skipped, and for duplicate ids the first one wins.
  List<Category>? _parse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;

      final seen = <String>{};
      final categories = <Category>[];
      for (final item in decoded) {
        try {
          final category = Category.fromJson(item as Map<String, dynamic>);
          if (seen.add(category.id)) categories.add(category);
        } catch (e) {
          logWarning('Warning: Skipping invalid category: $item');
        }
      }
      if (categories.isEmpty) return null;

      categories.sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
      });
      return categories;
    } catch (e) {
      return null;
    }
  }
}
