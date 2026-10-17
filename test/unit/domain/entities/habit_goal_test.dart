import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/validation/habit_validator.dart';
import 'package:atomic_momentum/data/models/habit_model.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/habit_goal.dart';
import 'package:atomic_momentum/domain/entities/habit_notify.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/domain/usecases/update_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import '../../../helpers/test_data.dart';

/// A habit's goal (build, quit, limit) and its notification settings.
void main() {
  Habit create({HabitGoal goal = HabitGoal.build, int target = 1, HabitNotify notify = HabitNotify.standard}) =>
      Habit.create(
        name: 'Smoking',
        target: target,
        color: HabitColor.red,
        categoryId: BuiltInCategoryIds.body,
        goal: goal,
        notify: notify,
      );

  group('saving and loading', () {
    test('goal and notifications survive both formats', () {
      final habit = create(
        goal: HabitGoal.limit,
        target: 2,
        notify: const HabitNotify(sound: NotifySound.ding, timeSensitive: true, streakWarnings: false),
      );
      for (final loaded in [
        Habit.fromJson(habit.toJson()),
        HabitModel.fromJson(HabitModel.fromDomain(habit).toJson()).toDomain(),
      ]) {
        expect(loaded.goal, HabitGoal.limit);
        expect(loaded.notify, const HabitNotify(sound: NotifySound.ding, timeSensitive: true, streakWarnings: false));
      }
    });

    test('habits saved before goals existed load as build habits with standard notifications', () {
      final json = HabitModel.fromDomain(TestData.createTestHabit()).toJson();
      expect(json.containsKey('goal'), isFalse, reason: 'nothing stored for the defaults');
      expect(json.containsKey('notify'), isFalse);
      final loaded = HabitModel.fromJson(json).toDomain();
      expect(loaded.goal, HabitGoal.build);
      expect(loaded.notify, HabitNotify.standard);
    });

    test('a quit habit (allowing nothing) is kept when stored, not filtered out as invalid', () {
      expect(HabitModel.fromDomain(create(goal: HabitGoal.quit, target: 0)).isValid(), isTrue);
      expect(HabitModel.fromDomain(create(target: 0)).isValid(), isFalse);
    });

    test('an unknown goal or sound falls back safely', () {
      expect(HabitGoal.fromJson('juggle'), HabitGoal.build);
      expect(HabitNotify.fromJson({'sound': 'kazoo'}).sound, isNull);
      expect(HabitNotify.fromJson('nonsense'), HabitNotify.standard);
    });
  });

  group('rules', () {
    test('a quit habit allows nothing; a limit habit and a build habit need a target', () {
      expect(HabitValidator.validate(create(goal: HabitGoal.quit, target: 0)).isValid, isTrue);
      expect(HabitValidator.validate(create(goal: HabitGoal.quit, target: 1)).isValid, isFalse);
      expect(HabitValidator.validate(create(goal: HabitGoal.limit, target: 2)).isValid, isTrue);
      expect(HabitValidator.validate(create(goal: HabitGoal.limit, target: 0)).isValid, isFalse);
      expect(HabitValidator.validate(create(target: 0)).isValid, isFalse);
    });

    test('break habits have room to log slips well past the limit, and no two-minute version', () {
      expect(create(goal: HabitGoal.quit, target: 0).maxPeriodTotal, 99);
      expect(create(goal: HabitGoal.limit, target: 20).maxPeriodTotal, 200);
      expect(create(target: 8).maxPeriodTotal, 80);
      expect(HabitGoal.quit.isBreak, isTrue);
      expect(HabitGoal.build.isBreak, isFalse);
    });

    test('editing keeps the goal and can change notifications', () {
      final habit = create(goal: HabitGoal.limit, target: 2);
      final edited = habit.updateDetails(name: 'Drinks', notify: const HabitNotify(sound: NotifySound.silent));
      expect(edited.goal, HabitGoal.limit);
      expect(edited.notify.sound, NotifySound.silent);
      expect(habit.updateDetails(name: 'Drinks').notify, HabitNotify.standard, reason: 'null leaves it alone');
    });
  });

  group('through the app', () {
    setUp(() async {
      await resetDependencies();
      SharedPreferences.setMockInitialValues({});
      await initializeDependencies(seedDefaultHabit: false);
    });
    tearDown(resetDependencies);

    test('a quit habit is created and its notifications updated', () async {
      final habits = get<HabitProvider>();
      expect(
        await habits.createHabit(const CreateHabitParams(
          name: 'Smoking',
          target: 0,
          color: HabitColor.red,
          categoryId: BuiltInCategoryIds.body,
          goal: HabitGoal.quit,
        )),
        isTrue,
        reason: habits.error,
      );
      final id = habits.habits.single.id;
      expect(habits.habits.single.goal, HabitGoal.quit);
      expect(
        await habits.updateHabitDetails(id, const UpdateHabitParams(notify: HabitNotify(timeSensitive: true))),
        isTrue,
      );
      expect(habits.habits.single.notify.timeSensitive, isTrue);
    });

    test('a build habit with no target is still refused', () async {
      final habits = get<HabitProvider>();
      expect(
        await habits.createHabit(const CreateHabitParams(
          name: 'Read',
          target: 0,
          color: HabitColor.teal,
          categoryId: BuiltInCategoryIds.mind,
        )),
        isFalse,
      );
    });
  });
}
