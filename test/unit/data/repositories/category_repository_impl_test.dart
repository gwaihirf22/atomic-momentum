import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/data/repositories/category_repository_impl.dart';
import 'package:atomic_momentum/domain/entities/category.dart';

void main() {
  const key = CategoryRepositoryImpl.storageKey;

  Future<(CategoryRepositoryImpl, SharedPreferences)> repoWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    return (CategoryRepositoryImpl(prefs), prefs);
  }

  test('first use seeds and stores the six defaults', () async {
    final (repo, prefs) = await repoWith({});

    expect(await repo.getAll(), Category.defaults);
    expect(prefs.getString(key), isNotNull);
  });

  test('does not re-seed once the user has changed categories', () async {
    final (repo, _) = await repoWith({});
    final edited = [Category.defaults.first.copyWith(name: 'Fitness')];
    await repo.saveAll(edited);

    expect(await repo.getAll(), edited);
  });

  test('round-trips and sorts by sort order', () async {
    final (repo, _) = await repoWith({});
    const a = Category(id: 'a', name: 'A', iconKey: 'star', colorValue: 1, sortOrder: 2);
    const b = Category(id: 'b', name: 'B', iconKey: 'star', colorValue: 1, sortOrder: 0);
    await repo.saveAll([a, b]);

    expect(await repo.getAll(), [b, a]);
  });

  test('unreadable data falls back to defaults without throwing and keeps a backup', () async {
    for (final bad in ['not json', '{}', '[]', '[1, 2]']) {
      final (repo, prefs) = await repoWith({key: bad});

      expect(await repo.getAll(), Category.defaults, reason: bad);
      expect(prefs.getString(CategoryRepositoryImpl.corruptBackupKey), bad);
    }
  });

  test('skips individual bad entries and duplicate ids', () async {
    final (repo, _) = await repoWith({
      key: jsonEncode([
        {'id': 'a', 'name': 'A', 'icon': 'star', 'color': 1, 'sortOrder': 0},
        {'name': 'no id'},
        {'id': 'a', 'name': 'Duplicate', 'icon': 'star', 'color': 1, 'sortOrder': 1},
      ]),
    });

    final categories = await repo.getAll();
    expect(categories.map((c) => c.name), ['A']);
  });
}
