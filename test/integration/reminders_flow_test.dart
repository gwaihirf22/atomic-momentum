import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/reminder_service.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/reminder_settings.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/domain/usecases/delete_habit_usecase.dart';
import 'package:atomic_momentum/domain/usecases/get_habits_usecase.dart';
import 'package:atomic_momentum/domain/usecases/update_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import '../helpers/fake_reminder_scheduler.dart';

void main() {
  late FakeReminderScheduler scheduler;
  late HabitProvider habits;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    scheduler = FakeReminderScheduler();
    habits = HabitProvider(
      getHabitsUseCase: get<GetHabitsUseCase>(),
      createHabitUseCase: get<CreateHabitUseCase>(),
      updateHabitUseCase: get<UpdateHabitUseCase>(),
      deleteHabitUseCase: get<DeleteHabitUseCase>(),
      // Just after midnight, so tonight's 11pm reminder is still ahead
      reminderService: ReminderService(scheduler: scheduler, clock: () => today.add(const Duration(minutes: 1))),
    );
    await habits.loadHabits();
  });

  tearDown(resetDependencies);

  bool remindedToday(String id) => scheduler.forHabit(id).any((r) => DateUtils.isSameDay(r.at, today));

  test('reminders are scheduled on create, dropped for today once done, and cleared on delete', () async {
    await habits.createHabit(CreateHabitParams(
      name: 'Stretch',
      target: 2,
      color: HabitColor.teal,
      categoryId: BuiltInCategoryIds.body,
      reminder: ReminderSettings.smart(time: const TimeOfDay(hour: 23, minute: 0)),
    ));
    final id = habits.habits.single.id;
    expect(remindedToday(id), isTrue);

    await habits.updateHabitProgress(id, 1);
    await habits.updateHabitProgress(id, 2);
    await pumpEventQueue();
    expect(remindedToday(id), isFalse, reason: 'done for today');
    expect(scheduler.forHabit(id), isNotEmpty, reason: 'later days still remind');

    await habits.deleteHabit(id);
    expect(scheduler.scheduled, isEmpty);
  });

  test('reminders are scheduled again when habits load', () async {
    await habits.createHabit(CreateHabitParams(
      name: 'Read',
      target: 1,
      color: HabitColor.blue,
      categoryId: BuiltInCategoryIds.mind,
      reminder: ReminderSettings.smart(time: const TimeOfDay(hour: 23, minute: 0)),
    ));
    scheduler.scheduled.clear();

    await habits.loadHabits();
    expect(scheduler.scheduled, isNotEmpty);
  });
}
