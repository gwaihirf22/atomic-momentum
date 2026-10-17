import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';

void main() {
  late HabitProvider habits;

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    habits = get<HabitProvider>();
  });

  tearDown(resetDependencies);

  Future<String> add(String name, {ResetFrequency frequency = ResetFrequency.daily}) async {
    await habits.createHabit(CreateHabitParams(
      name: name,
      target: 1,
      color: HabitColor.blue,
      categoryId: BuiltInCategoryIds.body,
      resetFrequency: frequency,
    ));
    return habits.habits.firstWhere((h) => h.name == name).id;
  }

  test('is null until something is logged', () async {
    await add('Read');
    expect(habits.overallMomentum, isNull);
  });

  test('averages the habits with history, ignoring untouched and never-resetting ones', () async {
    final now = DateTime.now();
    final a = await add('Read');
    final b = await add('Run');
    await add('Untouched');
    final never = await add('Lifetime', frequency: ResetFrequency.never);
    for (var i = 1; i <= 10; i++) {
      await habits.updateProgressForDate(a, DateTime(now.year, now.month, now.day - i), 1);
    }
    await habits.updateProgressForDate(b, DateTime(now.year, now.month, now.day - 1), 1);
    await habits.updateProgressForDate(never, DateTime(now.year, now.month, now.day - 1), 1);

    final scoreA = habits.getHabitById(a)!.momentum.score;
    final scoreB = habits.getHabitById(b)!.momentum.score;
    expect(habits.overallMomentum!.score, closeTo((scoreA + scoreB) / 2, 0.001));
  });
}
