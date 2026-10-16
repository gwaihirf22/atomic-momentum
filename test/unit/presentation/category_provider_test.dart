import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/data/datasources/shared_preferences_datasource.dart';
import 'package:atomic_momentum/data/repositories/category_repository_impl.dart';
import 'package:atomic_momentum/data/repositories/habit_repository_impl.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/usecases/manage_categories_usecase.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import '../../helpers/test_data.dart';

void main() {
  late CategoryProvider provider;
  late ManageCategoriesUseCase manage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final categories = CategoryRepositoryImpl(prefs);
    manage = ManageCategoriesUseCase(categories, HabitRepositoryImpl(SharedPreferencesDataSource(prefs)));
    provider = CategoryProvider(categories, manage);
    await provider.load();
  });

  final read = TestData.createTestHabit(id: 'read', categoryId: BuiltInCategoryIds.mind);
  final run = TestData.createTestHabit(id: 'run', categoryId: BuiltInCategoryIds.body);
  final pottery = TestData.createTestHabit(id: 'pottery', categoryId: 'hobbies');

  test('loads the built-in categories on first launch', () {
    expect(provider.categories, Category.defaults);
    expect(provider.deletedCategories, isEmpty);
  });

  test('resolves deleted and unknown ids to Uncategorized', () async {
    expect(provider.resolve(BuiltInCategoryIds.mind).name, 'Mind');
    expect(provider.resolve('hobbies'), Category.uncategorized);

    await manage.softDelete(BuiltInCategoryIds.mind);
    await provider.load();
    expect(provider.resolve(BuiltInCategoryIds.mind), Category.uncategorized);
    expect(provider.deletedCategories.single.id, BuiltInCategoryIds.mind);
  });

  test('offers Uncategorized as a filter only while some habit needs it', () {
    expect(provider.filterOptions([read, run]).map((c) => c.id), BuiltInCategoryIds.all);
    expect(provider.filterOptions([read, pottery]).last, Category.uncategorized);
  });

  test('filters by category id and by Uncategorized', () {
    provider.toggleCategory(BuiltInCategoryIds.mind);
    expect(provider.filterHabits([read, run, pottery]), [read]);

    provider.toggleCategory(Category.uncategorizedId);
    expect(provider.filterHabits([read, run, pottery]), [pottery]);

    provider.toggleCategory(Category.uncategorizedId);
    expect(provider.selectedCategory, isNull);
    expect(provider.filterHabits([read, run, pottery]), hasLength(3));
  });

  test('stats are keyed by category id, including Uncategorized', () {
    final stats = provider.getCategoryStats([read, run, pottery]);
    expect(stats.keys, containsAll([BuiltInCategoryIds.mind, BuiltInCategoryIds.body, Category.uncategorizedId]));
    expect(stats[Category.uncategorizedId]!.totalHabits, 1);
    expect(stats.containsKey(BuiltInCategoryIds.spirit), isFalse);
  });

  test('a selected category that gets deleted stops filtering', () async {
    provider.setSelectedCategoryId(BuiltInCategoryIds.mind);
    await manage.softDelete(BuiltInCategoryIds.mind);
    await provider.load();

    expect(provider.selectedCategory, isNull);
    expect(provider.filterHabits([read, run]), hasLength(2));

    provider.updateAvailableCategories([read, run]);
    expect(provider.selectedCategoryId, isNull);
  });
}
