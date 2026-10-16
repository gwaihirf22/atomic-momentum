import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/exceptions/storage_exceptions.dart';
import 'package:atomic_momentum/core/validation/category_validator.dart';
import 'package:atomic_momentum/data/datasources/shared_preferences_datasource.dart';
import 'package:atomic_momentum/data/repositories/category_repository_impl.dart';
import 'package:atomic_momentum/data/repositories/habit_repository_impl.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/usecases/manage_categories_usecase.dart';

void main() {
  late CategoryRepositoryImpl categories;
  late HabitRepositoryImpl habits;
  late ManageCategoriesUseCase manage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    categories = CategoryRepositoryImpl(prefs);
    habits = HabitRepositoryImpl(SharedPreferencesDataSource(prefs));
    manage = ManageCategoriesUseCase(categories, habits);
  });

  Matcher throwsValidation(String messagePart) =>
      throwsA(isA<ValidationException>().having((e) => e.message, 'message', contains(messagePart)));

  Future<List<Category>> active() async => [for (final c in await categories.getAll()) if (!c.isDeleted) c];

  Future<Habit> saveHabit(String name, String categoryId) async {
    final habit = Habit.create(name: name, target: 1, color: HabitColor.blue, categoryId: categoryId);
    await habits.saveHabit(habit);
    return habit;
  }

  Future<String> addCategory(String name) async {
    final all = await manage.add(name: name, iconKey: 'star', colorValue: 0xFF000000);
    return all.firstWhere((c) => c.name == name.trim()).id;
  }

  group('add', () {
    test('creates a category with a new id, placed last', () async {
      final id = await addCategory('  Hobbies ');

      final list = await active();
      expect(list.last.id, id);
      expect(list.last.name, 'Hobbies');
      expect(id, startsWith('cat_'));
      expect(BuiltInCategoryIds.all, isNot(contains(id)));
    });

    test('allows up to 24 active categories; deleted ones do not count', () async {
      for (var i = 0; i < 18; i++) {
        await addCategory('Extra $i');
      }
      expect(await active(), hasLength(24));
      expect(() => addCategory('One too many'), throwsValidation('up to 24'));

      await manage.softDelete(BuiltInCategoryIds.body);
      await addCategory('Fits now');
      expect(await active(), hasLength(24));
    });

    test('rejects bad names', () async {
      expect(() => addCategory('   '), throwsValidation('Enter a name'));
      expect(() => addCategory('x' * 21), throwsValidation('up to 20'));
      expect(() => addCategory('BODY'), throwsValidation('already have a category called Body'));
      expect(() => addCategory('uncategorized'), throwsValidation('reserved'));
    });
  });

  group('update', () {
    test('a built-in category can be renamed, recolored and given a new icon, keeping its id', () async {
      final body = (await active()).first;
      await manage.update(body.copyWith(name: 'Fitness', iconKey: 'sport', colorValue: 0xFF111111));

      final updated = (await active()).first;
      expect(updated.id, BuiltInCategoryIds.body);
      expect([updated.name, updated.iconKey, updated.colorValue], ['Fitness', 'sport', 0xFF111111]);
    });

    test('a category may keep its own name but not take another\'s', () async {
      final mind = (await active()).firstWhere((c) => c.id == BuiltInCategoryIds.mind);
      await manage.update(mind.copyWith(name: 'mind'));
      expect(() => manage.update(mind.copyWith(name: 'Spirit')), throwsValidation('already have'));
    });
  });

  group('reorder', () {
    test('saves the new order', () async {
      final ids = (await active()).map((c) => c.id).toList().reversed.toList();
      await manage.reorder(ids);

      expect((await active()).map((c) => c.id), ids);
    });

    test('rejects an order that misses or adds a category', () async {
      final ids = (await active()).map((c) => c.id).toList();
      expect(() => manage.reorder(ids.sublist(1)), throwsValidation('every category'));
      expect(() => manage.reorder([...ids.sublist(1), 'nope']), throwsValidation('every category'));
    });
  });

  group('delete and restore', () {
    test('deleting keeps the category in Recently Deleted and leaves habits untouched', () async {
      final habit = await saveHabit('Read', BuiltInCategoryIds.mind);
      await manage.softDelete(BuiltInCategoryIds.mind);

      final all = await categories.getAll();
      expect(all.firstWhere((c) => c.id == BuiltInCategoryIds.mind).isDeleted, isTrue);
      expect((await habits.getHabitById(habit.id))!.categoryId, BuiltInCategoryIds.mind);
    });

    test('the last active category cannot be deleted', () async {
      for (final id in BuiltInCategoryIds.all.skip(1)) {
        await manage.softDelete(id);
      }
      expect(() => manage.softDelete(BuiltInCategoryIds.body), throwsValidation('at least one'));
    });

    test('restoring puts the category back at the end', () async {
      await manage.softDelete(BuiltInCategoryIds.body);
      final restored = await manage.restore(BuiltInCategoryIds.body);

      expect(restored.isDeleted, isFalse);
      expect((await active()).last.id, BuiltInCategoryIds.body);
    });

    test('restoring renames it if the name was taken meanwhile', () async {
      await manage.softDelete(BuiltInCategoryIds.mind);
      await addCategory('Mind');

      final restored = await manage.restore(BuiltInCategoryIds.mind);
      expect(restored.name, 'Mind 2');
    });

    test('the restore rename stays within the length limit', () async {
      final longId = await addCategory('A' * 20);
      await manage.softDelete(longId);
      await addCategory('a' * 20);

      final restored = await manage.restore(longId);
      expect(restored.name, '${'A' * 18} 2');
      expect(CategoryValidator.validateName(restored.name, const []), isNull);
    });

    test('restoring is blocked at 24 active categories', () async {
      await manage.softDelete(BuiltInCategoryIds.body);
      for (var i = 0; i < 19; i++) {
        await addCategory('Extra $i');
      }
      expect(() => manage.restore(BuiltInCategoryIds.body), throwsValidation('Delete one first'));
    });
  });

  group('delete permanently and move habits', () {
    test('only a deleted category with no habits can be removed for good', () async {
      final habit = await saveHabit('Read', BuiltInCategoryIds.mind);

      expect(() => manage.deletePermanently(BuiltInCategoryIds.mind), throwsValidation('Delete the category'));

      await manage.softDelete(BuiltInCategoryIds.mind);
      expect(() => manage.deletePermanently(BuiltInCategoryIds.mind), throwsValidation('Move or delete its habits'));

      expect(await manage.moveHabits(BuiltInCategoryIds.mind, BuiltInCategoryIds.body), 1);
      expect((await habits.getHabitById(habit.id))!.categoryId, BuiltInCategoryIds.body);

      await manage.deletePermanently(BuiltInCategoryIds.mind);
      expect((await categories.getAll()).map((c) => c.id), isNot(contains(BuiltInCategoryIds.mind)));
    });

    test('habits cannot be moved into a deleted category', () async {
      await saveHabit('Read', BuiltInCategoryIds.mind);
      await manage.softDelete(BuiltInCategoryIds.body);

      expect(() => manage.moveHabits(BuiltInCategoryIds.mind, BuiltInCategoryIds.body),
          throwsValidation('isn\'t deleted'));
    });
  });
}
