import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/freeze_bank.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/habit_goal.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';

/// Freezes end to end: the bank, the provider and real storage.
void main() {
  final now = DateTime(2026, 10, 20, 12);
  final today = DateTime(2026, 10, 20);
  final tomorrow = DateTime(2026, 10, 21);

  late HabitProvider habits;
  late FreezeBank bank;

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies();
    bank = get<FreezeBank>();
    habits = get<HabitProvider>();
  });

  tearDown(resetDependencies);

  Future<T> at<T>(Future<T> Function() body) => withClock(Clock.fixed(now), body);

  Future<String> add(String name, {HabitGoal goal = HabitGoal.build, int target = 1}) async {
    await habits.createHabit(CreateHabitParams(
      name: name,
      target: target,
      color: HabitColor.blue,
      categoryId: BuiltInCategoryIds.body,
      goal: goal,
    ));
    return habits.habits.firstWhere((h) => h.name == name).id;
  }

  group('the bank', () {
    test('starts with 3 and spends down to none', () async {
      expect(bank.available, FreezeBank.start);
      for (var i = 0; i < 3; i++) {
        expect(await bank.spend(now), isTrue);
      }
      expect(await bank.spend(now), isFalse);
      expect(bank.firstSpentOn, today);
    });

    test('milestones fill it to 5; the first look files what was already earned', () async {
      expect((await bank.credit(['streak_7_a'], now)).isEmpty, isTrue);
      expect(bank.available, 3, reason: 'already earned before freezes: filed quietly');
      final first = await bank.credit(['streak_7_a', 'streak_21_a', 'formed_a'], now);
      expect(first.added, ['streak_21_a', 'formed_a']);
      expect(bank.available, 5);
      final full = await bank.credit(['streak_66_a'], now);
      expect(full.full, ['streak_66_a']);
      expect(bank.available, 5, reason: 'never past the cap');
    });

    test('refunds stop at the cap; a month full is remembered for good', () async {
      await bank.credit([], now);
      await bank.credit(['a', 'b'], now);
      await bank.refund(now, 3);
      expect(bank.available, 5);
      expect(bank.fullSince, today);
      await bank.check(DateTime(2026, 11, 19, 9));
      expect(bank.fundReachedOn, DateTime(2026, 11, 19));
      await bank.spend(DateTime(2026, 11, 20));
      expect(bank.fullSince, isNull);
      expect(bank.fundReachedOn, DateTime(2026, 11, 19), reason: 'stays once reached');
    });

    test('survives a restart', () async {
      await bank.spend(now);
      final again = FreezeBank(get<SharedPreferences>());
      expect(again.available, 2);
      expect(again.firstSpentOn, today);
    });
  });

  group('spending them on habits', () {
    test('a freeze comes out of the bank and stays on the habit after a reload', () async {
      await at(() async {
        await habits.loadHabits();
        final id = await add('Read');
        expect(await habits.freeze(id, tomorrow), isTrue);
        expect(bank.available, 2);
        expect(habits.getHabitById(id)!.isFrozenOn(tomorrow), isTrue);

        final fresh = get<HabitProvider>();
        await fresh.loadHabits();
        expect(fresh.getHabitById(id)!.frozenDays, {tomorrow});
      });
    });

    test('unfreezing puts it back', () async {
      await at(() async {
        await habits.loadHabits();
        final id = await add('Read');
        await habits.freeze(id, tomorrow);
        expect(await habits.unfreeze(id, tomorrow), isTrue);
        expect(bank.available, 3);
        expect(habits.getHabitById(id)!.frozenDays, isEmpty);
      });
    });

    test('an empty bank, or a day that can\'t be frozen, says why', () async {
      await at(() async {
        await habits.loadHabits();
        final id = await add('Read');
        await habits.updateHabitProgress(id, 1);
        expect(await habits.freeze(id, today), isFalse, reason: 'already kept');
        expect(habits.error, contains('kept'));
        expect(bank.available, 3);

        for (var i = 0; i < 3; i++) {
          await bank.spend(now);
        }
        expect(await habits.freeze(id, tomorrow), isFalse);
        expect(habits.error, 'No freezes left');
      });
    });

    test('a frozen day kept anyway gives its freeze back, and says so', () async {
      await at(() async {
        await habits.loadHabits();
        final id = await add('Read');
        await habits.freeze(id, today);
        expect(bank.available, 2);
        await habits.updateHabitProgress(id, 1);
        await pumpEventQueue();
        expect(bank.available, 3);
        expect(habits.getHabitById(id)!.frozenDays, isEmpty);
        expect(habits.takeFreezeNotice(), contains('came back'));
        expect(habits.takeFreezeNotice(), isNull, reason: 'once');
      });
    });
  });

  test('vacation mode pauses every habit that resets, and ends cleanly', () async {
    await at(() async {
      await habits.loadHabits();
      final a = await add('Read');
      final b = await add('Smoking', goal: HabitGoal.quit, target: 0);
      expect(habits.onVacation, isFalse);
      await habits.startVacation();
      expect(habits.onVacation, isTrue);
      expect(habits.getHabitById(a)!.isOnVacation, isTrue);
      expect(habits.getHabitById(b)!.isOnVacation, isTrue);
      expect(bank.available, 3, reason: 'costs no freezes');

      final fresh = get<HabitProvider>();
      await fresh.loadHabits();
      expect(fresh.onVacation, isTrue, reason: 'stored');

      await habits.endVacation();
      expect(habits.onVacation, isFalse);
      expect(habits.getHabitById(a)!.pauses.single.to, today);
    });
  });

  test('vacation mode with a return date: stored, moved, and over by itself that morning', () async {
    final back = DateTime(2026, 10, 25);
    late String a;
    await at(() async {
      await habits.loadHabits();
      a = await add('Read');
      await habits.startVacation(back: DateTime(2026, 10, 28));
      expect(habits.vacationBack, DateTime(2026, 10, 28));
      await habits.setVacationReturn(back);
      expect(habits.vacationBack, back);
      expect(habits.vacation!.since, today);
    });

    await withClock(Clock.fixed(DateTime(2026, 10, 25, 7)), () async {
      final fresh = get<HabitProvider>();
      await fresh.loadHabits();
      expect(fresh.onVacation, isFalse, reason: 'back today, without turning it off');
      expect(fresh.getHabitById(a)!.isOnVacationOn(DateTime(2026, 10, 24)), isTrue);
      expect(fresh.vacationForNotices?.back, back, reason: "this morning's welcome back still comes");
    });
    await withClock(Clock.fixed(DateTime(2026, 10, 26, 7)), () async {
      expect(get<HabitProvider>().vacationForNotices, isNull);
    });
  });

  test('without a return date, one can be added and taken off again', () async {
    await at(() async {
      await habits.loadHabits();
      await add('Read');
      await habits.startVacation();
      expect(habits.vacationBack, isNull);
      await habits.setVacationReturn(tomorrow);
      expect(habits.vacationBack, tomorrow);
      await habits.setVacationReturn(null);
      expect(habits.vacationBack, isNull);
      expect(habits.onVacation, isTrue);
    });
  });
}
