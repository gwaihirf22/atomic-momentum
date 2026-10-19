import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/habit_goal.dart';
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

    // Each weighed by how formed it is
    final ma = habits.getHabitById(a)!.momentum, mb = habits.getHabitById(b)!.momentum;
    expect(ma.formed, greaterThan(mb.formed));
    expect(habits.overallMomentum!.score,
        closeTo((ma.score * ma.formed + mb.score * mb.formed) / (ma.formed + mb.formed), 0.001));
  });

  test('starting a habit barely moves it', () async {
    final now = DateTime.now();
    final read = await add('Read');
    for (var i = 1; i <= 90; i++) {
      await habits.updateProgressForDate(read, DateTime(now.year, now.month, now.day - i), 1);
    }
    final before = habits.overallMomentum!.score;
    expect(before, greaterThan(80));

    final run = await add('Run');
    await habits.updateProgressForDate(run, DateTime(now.year, now.month, now.day - 1), 1);
    expect(habits.overallMomentum!.score, closeTo(before, 2.5), reason: 'not halved by a habit a day old');
  });

  test('a habit being broken counts once a day has passed, though it logs nothing', () async {
    final now = DateTime.now();
    Future<void> addQuit(String name, DateTime at) => withClock(
          Clock.fixed(at),
          () => habits.createHabit(CreateHabitParams(
            name: name,
            target: 0,
            color: HabitColor.red,
            categoryId: BuiltInCategoryIds.body,
            goal: HabitGoal.quit,
          )),
        );
    await addQuit('Smoking', DateTime(now.year, now.month, now.day - 10, 9));
    await habits.loadHabits();
    final clean = habits.habits.single;
    expect(clean.momentum.score, greaterThan(0));
    expect(habits.overallMomentum!.score, closeTo(clean.momentum.score, 0.001));

    await addQuit('Soda', now);
    expect(habits.overallMomentum!.score, closeTo(clean.momentum.score, 0.001), reason: 'added today: not yet');
  });
}
