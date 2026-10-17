import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/domain/usecases/get_habits_usecase.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';

/// Clearing a period and undoing it go through the same save queue as taps,
/// so quick changes in any order end up stored as they were shown.
void main() {
  late HabitProvider habits;
  late String id;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    habits = get<HabitProvider>();
    await habits.createHabit(const CreateHabitParams(
      name: 'Read',
      target: 3,
      color: HabitColor.teal,
      categoryId: BuiltInCategoryIds.mind,
    ));
    id = habits.habits.single.id;
  });

  tearDown(resetDependencies);

  Future<int> stored() async {
    final all = await get<GetHabitsUseCase>().call();
    return all.single.progress;
  }

  test('a tap then a clear: the clear wins, as shown', () async {
    final tap = habits.updateHabitProgress(id, 2);
    final clear = habits.setDays(id, {today: 0});
    expect(habits.habits.single.progress, 0);
    expect(await tap && await clear, isTrue);
    expect(await stored(), 0);
  });

  test('a clear then a tap: the tap counts after it', () async {
    await habits.updateHabitProgress(id, 3);
    final clear = habits.setDays(id, {today: 0});
    final tap = habits.updateHabitProgress(id, 1);
    expect(habits.habits.single.progress, 1);
    expect(await clear && await tap, isTrue);
    expect(await stored(), 1);
  });

  test('clear and undo leave things as they were', () async {
    await habits.updateHabitProgress(id, 2);
    final before = habits.habits.single.periodDays(now);
    final clear = habits.setDays(id, {for (final d in before.keys) d: 0});
    final undo = habits.setDays(id, before);
    expect(await clear && await undo, isTrue);
    expect(await stored(), 2);
  });

  test('a why and a day note are saved', () async {
    expect(await habits.setWhy(id, 'Learn more'), isTrue);
    expect(await habits.setDayNote(id, today, 'Two chapters on the train'), isTrue);
    final saved = (await get<GetHabitsUseCase>().call()).single;
    expect(saved.why, 'Learn more');
    expect(saved.dayNotes, {today: 'Two chapters on the train'});
  });

  test('progress past the target is stored, however it is set', () async {
    expect(await habits.updateHabitProgress(id, 4), isTrue);
    expect(await stored(), 4);
  });

  test('typing past the target is stored', () async {
    expect(await habits.setDays(id, {today: 5}), isTrue);
    expect(await stored(), 5);
    expect(habits.habits.single.isCompleted, isTrue);
  });
}
