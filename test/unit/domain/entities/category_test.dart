import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/category.dart';

void main() {
  group('Category', () {
    const hobbies = Category(id: 'cat_1', name: 'Hobbies', iconKey: 'star', colorValue: 0xFF123456, sortOrder: 6);

    test('round-trips through JSON, including deletion', () {
      expect(Category.fromJson(hobbies.toJson()), hobbies);

      final deleted = hobbies.markDeleted(DateTime(2026, 10, 16, 9));
      final restored = Category.fromJson(deleted.toJson());
      expect(restored.isDeleted, isTrue);
      expect(restored.deletedAt, DateTime(2026, 10, 16, 9));
    });

    test('requires a non-empty id and name', () {
      expect(() => Category.fromJson({'name': 'X'}), throwsFormatException);
      expect(() => Category.fromJson({'id': '', 'name': 'X'}), throwsFormatException);
      expect(() => Category.fromJson({'id': 'a', 'name': '  '}), throwsFormatException);
      expect(() => Category.fromJson({'id': 3, 'name': 'X'}), throwsFormatException);
    });

    test('tolerates bad optional fields and keeps unknown icon keys', () {
      final c = Category.fromJson({
        'id': 'a',
        'name': 'A',
        'icon': 'rocket_from_the_future',
        'color': 'red',
        'sortOrder': 'first',
        'deletedAt': 'yesterday',
      });
      expect(c.iconKey, 'rocket_from_the_future');
      expect(c.colorValue, 0xFF8E8E93);
      expect(c.sortOrder, 0);
      expect(c.isDeleted, isFalse);
      expect(c.builtIn, isFalse);
    });

    test('defaults match the original six categories exactly', () {
      final table = Category.defaults.map((c) => [c.id, c.name, c.iconKey, c.colorValue, c.sortOrder, c.builtIn]);
      expect(table, [
        ['body', 'Body', 'heart', 0xFF2196F3, 0, true],
        ['spirit', 'Spirit', 'leaf', 0xFF9C27B0, 1, true],
        ['mind', 'Mind', 'book', 0xFF00BCD4, 2, true],
        ['social', 'Social', 'people', 0xFF4CAF50, 3, true],
        ['career', 'Career', 'briefcase', 0xFFFF9800, 4, true],
        ['creative', 'Creative', 'paintbrush', 0xFFE91E63, 5, true],
      ]);
      expect(Category.defaults.map((c) => c.id), BuiltInCategoryIds.all);
    });

    test('markDeleted and restored', () {
      final deleted = hobbies.markDeleted(DateTime(2026, 10, 16));
      expect(deleted.isDeleted, isTrue);

      final back = deleted.restored(sortOrder: 9, name: 'Hobbies 2');
      expect(back.isDeleted, isFalse);
      expect(back.sortOrder, 9);
      expect(back.name, 'Hobbies 2');
      expect(back.id, hobbies.id);
    });

    test('copyWith keeps id, deletion and built-in status', () {
      final renamed = Category.defaults.first.copyWith(name: 'Fitness', colorValue: 0xFF000000);
      expect(renamed.id, 'body');
      expect(renamed.builtIn, isTrue);
      expect(renamed.name, 'Fitness');
    });

    test('uncategorized uses the reserved id', () {
      expect(Category.uncategorized.id, Category.uncategorizedId);
      expect(BuiltInCategoryIds.all, isNot(contains(Category.uncategorizedId)));
    });
  });
}
