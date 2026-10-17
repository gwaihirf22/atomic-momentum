import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/reminder_service.dart';
import 'package:atomic_momentum/data/datasources/local_habit_datasource.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/reminder_settings.dart';
import 'package:atomic_momentum/domain/entities/two_minute_version.dart';
import 'package:atomic_momentum/domain/repositories/habit_repository.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/domain/usecases/delete_habit_usecase.dart';
import 'package:atomic_momentum/domain/usecases/get_habits_usecase.dart';
import 'package:atomic_momentum/domain/usecases/update_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import '../helpers/failing_habit_repository.dart';
import '../helpers/fake_reminder_scheduler.dart';

/// The two-minute version end to end: provider, real use cases and storage.
void main() {
  late FailingHabitRepository repository;
  late FakeReminderScheduler scheduler;
  late HabitProvider habits;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(now.year, now.month, now.day - 1);

  const oneGlass = TwoMinuteVersion(description: 'One glass of water');

  HabitProvider newProvider(HabitRepository repo) => HabitProvider(
        getHabitsUseCase: GetHabitsUseCase(repo),
        createHabitUseCase: CreateHabitUseCase(repo),
        updateHabitUseCase: UpdateHabitUseCase(repo),
        deleteHabitUseCase: DeleteHabitUseCase(repo),
        // Just after midnight, so tonight's 11pm reminder is still ahead
        reminderService: ReminderService(scheduler: scheduler, clock: () => today.add(const Duration(minutes: 1))),
      );

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    repository = FailingHabitRepository(get<LocalHabitDataSource>());
    scheduler = FakeReminderScheduler();
    habits = newProvider(repository);
    await habits.loadHabits();
  });

  tearDown(resetDependencies);

  Future<String> createWater() async {
    await habits.createHabit(CreateHabitParams(
      name: 'Water',
      target: 8,
      units: 'glasses',
      color: HabitColor.blue,
      categoryId: BuiltInCategoryIds.body,
      reminder: ReminderSettings.smart(time: const TimeOfDay(hour: 23, minute: 0)),
      twoMinute: oneGlass,
    ));
    return habits.habits.single.id;
  }

  Future<HabitProvider> reloaded() async {
    final fresh = newProvider(repository);
    await fresh.loadHabits();
    return fresh;
  }

  test('the version is saved with the habit', () async {
    final id = await createWater();
    expect((await reloaded()).getHabitById(id)!.twoMinute, oneGlass);
  });

  test('a tap shows at once, keeps the day, and survives reloading', () async {
    final id = await createWater();

    final saving = habits.setTwoMinute(id, true);
    expect(habits.getHabitById(id)!.isTwoMinuteOn(today), isTrue, reason: 'shown before the save finishes');
    expect(await saving, isTrue);

    final stored = (await reloaded()).getHabitById(id)!;
    expect(stored.twoMinuteDays, {today});
    expect(stored.streak.current, 1);
    expect(stored.momentum.score, greaterThan(0));
  });

  test("a tap drops today's reminder", () async {
    final id = await createWater();
    bool remindedToday() => scheduler.forHabit(id).any((r) => DateUtils.isSameDay(r.at, today));
    expect(remindedToday(), isTrue);

    await habits.setTwoMinute(id, true);
    await pumpEventQueue();
    expect(remindedToday(), isFalse);
  });

  test('quick taps on progress and "2 min" are all saved', () async {
    final id = await createWater();

    await Future.wait([
      habits.updateHabitProgress(id, 1),
      habits.setTwoMinute(id, true),
      habits.updateHabitProgress(id, 2),
    ]);

    final shown = habits.getHabitById(id)!;
    expect(shown.progress, 2);
    expect(shown.twoMinuteDays, {today});

    final stored = (await reloaded()).getHabitById(id)!;
    expect(stored.progress, 2);
    expect(stored.twoMinuteDays, {today});
  });

  test('undo removes the day', () async {
    final id = await createWater();
    await habits.setTwoMinute(id, true);
    await habits.setTwoMinute(id, false);

    expect((await reloaded()).getHabitById(id)!.twoMinuteDays, isEmpty);
  });

  test('a failed save rolls back and is reported', () async {
    final id = await createWater();
    repository.failSaves = true;

    expect(await habits.setTwoMinute(id, true), isFalse);
    expect(habits.getHabitById(id)!.twoMinuteDays, isEmpty, reason: 'never show what isn\'t stored');
    expect(habits.error, isNotNull);
  });

  test('a past day can be marked from the Calendar', () async {
    final id = await createWater();
    await habits.setTwoMinute(id, true, date: yesterday);

    final stored = (await reloaded()).getHabitById(id)!;
    expect(stored.twoMinuteDays, {yesterday});
    expect(stored.isTwoMinuteOn(yesterday), isTrue);
  });

  test('editing can remove the version; its days stay recorded', () async {
    final id = await createWater();
    await habits.setTwoMinute(id, true);

    await habits.updateHabitDetails(id, const UpdateHabitParams(removeTwoMinute: true));

    final stored = (await reloaded()).getHabitById(id)!;
    expect(stored.twoMinute, isNull);
    expect(stored.twoMinuteDays, {today});
  });
}
