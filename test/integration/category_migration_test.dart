import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';

import '../helpers/test_data.dart';

/// Habits saved before categories became editable must load unchanged.
void main() {
  const habitsKey = 'atomic_momentum_habits_v2';

  // One habit per category, in the exact format the app stored before
  List<Map<String, dynamic>> legacyHabits() => [
        for (final id in BuiltInCategoryIds.all)
          TestData.habitJsonData
            ..['id'] = 'legacy_$id'
            ..['name'] = 'Legacy $id'
            ..['category'] = id,
      ];

  late HabitProvider habitProvider;

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({habitsKey: jsonEncode(legacyHabits())});
    await initializeDependencies(seedDefaultHabit: false);
    habitProvider = get<HabitProvider>();
    await habitProvider.loadHabits();
  });

  tearDown(() async {
    await resetDependencies();
  });

  test('stored habits keep their category ids', () {
    final byName = {for (final h in habitProvider.habits) h.name: h.categoryId};
    expect(byName, {for (final id in BuiltInCategoryIds.all) 'Legacy $id': id});
  });

  test('saving again leaves the stored category values unchanged', () async {
    final mind = habitProvider.habits.firstWhere((h) => h.categoryId == BuiltInCategoryIds.mind);
    expect(await habitProvider.updateHabitProgress(mind.id, 1), isTrue);

    final prefs = await SharedPreferences.getInstance();
    final stored = (jsonDecode(prefs.getString(habitsKey)!) as List).cast<Map<String, dynamic>>();
    expect(
      {for (final h in stored) h['id']: h['category']},
      {for (final id in BuiltInCategoryIds.all) 'legacy_$id': id},
    );
  });
}
