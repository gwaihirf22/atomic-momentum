import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/presentation/widgets/category_icons.dart';
import 'package:atomic_momentum/presentation/widgets/habit_icons.dart';
import '../../helpers/test_data.dart';

void main() {
  final mind = Category.defaults.firstWhere((c) => c.id == BuiltInCategoryIds.mind);

  test('the habit icon library has 20 icons', () {
    expect(HabitIcons.library.length, 20);
    expect(HabitIcons.of('water'), Icons.local_drink);
    expect(HabitIcons.of('no-such-icon'), isNull);
    expect(HabitIcons.of(null), isNull);
  });

  test('a chosen icon wins', () {
    final habit = TestData.createTestHabit().updateDetails(icon: 'run');
    expect(habitIcon(habit, mind), Icons.directions_run);
  });

  test('no icon, or an unknown one, falls back to the category icon', () {
    final none = TestData.createTestHabit().updateDetails(icon: '');
    final unknown = TestData.createTestHabit().updateDetails(icon: 'from_an_old_version');

    expect(habitIcon(none, mind), mind.icon);
    expect(habitIcon(unknown, mind), mind.icon);
  });
}
