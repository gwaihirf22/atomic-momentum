import 'dart:convert';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/health_sync_service.dart';
import 'package:atomic_momentum/core/services/notification_service.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/health_link.dart';
import 'package:atomic_momentum/domain/services/health_days.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';

import '../../helpers/fake_health_source.dart';

/// Sixty days of the real app linked to a scripted Health, across the
/// autumn clock change: steps walked through each day, water logged in the
/// app (and written back) and in another app. The person taps + and −, types
/// numbers and edits past days on Calendar, often below what Health says.
///
/// Checked after every action and sync:
/// - a sync never lowers a day, and never touches one it doesn't look at
///   (over a week ago, or before the habit was linked);
/// - no day ever shows less than Health says (less the app's own water);
/// - lowering stops at Health's number exactly when it should, and says so;
///   a change accepted without a notice is never put back by the next sync;
/// - Health holds exactly the other app's water plus what the app wrote
///   and hasn't taken back.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    NotificationService.debugReset();
    await resetDependencies();
  });

  test('sixty days linked to Health: the rules hold every time', () async {
    var now = DateTime(2026, 10, 12, 7);
    final problems = <String>[];
    void problem(String message) => problems.add('${now.toIso8601String().substring(0, 16)}  $message');
    DateTime day(DateTime t) => DateTime(t.year, t.month, t.day);

    await withClock(Clock(() => now), () async {
      await resetDependencies();
      SharedPreferences.setMockInitialValues({});
      await initializeDependencies(seedDefaultHabit: false);
      final health = FakeHealthSource.install();
      final habits = get<HabitProvider>();
      await habits.loadHabits();
      final linkedOn = day(now);

      await habits.createHabit(CreateHabitParams(
        name: 'Walk',
        target: 8000,
        units: 'steps',
        color: HabitColor.green,
        categoryId: BuiltInCategoryIds.body,
        health: HealthLink(metric: HealthMetric.steps, linkedOn: linkedOn),
      ));
      await habits.createHabit(CreateHabitParams(
        name: 'Water',
        target: 8,
        units: 'glasses',
        color: HabitColor.blue,
        categoryId: BuiltInCategoryIds.body,
        health: HealthLink(metric: HealthMetric.water, logToHealth: true, linkedOn: linkedOn),
      ));
      Habit walk() => habits.habits.firstWhere((h) => h.name == 'Walk');
      Habit water() => habits.habits.firstWhere((h) => h.name == 'Water');
      final sync = get<HealthSyncService>();

      // The world: each day's steps (some walked before each look), and the
      // water another app logged
      final dayTotal = <DateTime, int>{};
      final otherWater = <DateTime, int>{};
      final steps = health.values.putIfAbsent(HealthMetric.steps, () => {});
      final ml = health.values.putIfAbsent(HealthMetric.water, () => {});

      Future<void> settle() async {
        for (var i = 0; i < 8; i++) {
          await Future<void>.delayed(Duration.zero);
        }
      }

      int writesHeld(DateTime d) => [
            for (final w in (get<SharedPreferences>().getString(HealthSyncService.writesKey) == null
                ? const <HealthWrite>[]
                : _writes(get<SharedPreferences>().getString(HealthSyncService.writesKey)!)))
              if (w.day == d) w.amount.round(),
          ].fold(0, (a, b) => a + b);

      void checkWater() {
        // The app keeps its write records a week (what − can still take back)
        final weekAgo = DateTime(now.year, now.month, now.day - 7);
        for (final d in {...ml.keys}) {
          if (d.isBefore(weekAgo)) continue;
          final want = (otherWater[d] ?? 0) + writesHeld(d);
          if ((ml[d] ?? 0) != want) problem('water in Health on ${d.month}/${d.day} is ${ml[d]} ml, expected $want');
        }
      }

      /// A sync, checked: never lower, never outside its window, never
      /// below Health's number.
      Future<void> syncAndCheck({bool force = true}) async {
        final before = {for (final h in habits.habits) h.id: Map.of(h.history)};
        await habits.syncHealth(force: force);
        await settle();
        for (final h in habits.habits) {
          final first = HealthMerge.firstDay(h, day(now));
          for (final d in {...before[h.id]!.keys, ...h.history.keys}) {
            final was = before[h.id]![d] ?? 0, is_ = h.history[d] ?? 0;
            if (is_ < was) problem('${h.name}: a sync lowered ${d.month}/${d.day} from $was to $is_');
            if (is_ != was && d.isBefore(first)) problem('${h.name}: a sync changed ${d.month}/${d.day}, outside its window');
          }
        }
        for (var d = HealthMerge.firstDay(walk(), day(now)); !d.isAfter(day(now)); d = DateTime(d.year, d.month, d.day + 1)) {
          if ((walk().history[d] ?? 0) < (steps[d] ?? 0)) {
            problem('Walk shows ${walk().history[d] ?? 0} on ${d.month}/${d.day}, below Health\'s ${steps[d]}');
          }
        }
        final w = water();
        for (var d = HealthMerge.firstDay(w, day(now)); !d.isAfter(day(now)); d = DateTime(d.year, d.month, d.day + 1)) {
          final glasses = ((otherWater[d] ?? 0) / 250).floor();
          if ((w.history[d] ?? 0) < glasses) problem('Water shows ${w.history[d] ?? 0} on ${d.month}/${d.day}, below Health\'s');
        }
        checkWater();
      }

      /// The person changes [habit] on [d] to [amount] (the card for today,
      /// Calendar for a past day), then the rules: it stops at Health's
      /// number exactly when it should, and what's accepted stays.
      Future<void> change(Habit Function() habit, DateTime d, int amount) async {
        final floor = sync.floorOn(habit(), d);
        final wasDay = habit().history[d] ?? 0;
        habits.takeHealthNotice();
        if (d == day(now)) {
          final rest = habit().progressForPeriodContaining(d) - wasDay;
          await habits.updateHabitProgress(habit().id, rest + amount);
        } else {
          await habits.updateProgressForDate(habit().id, d, amount);
        }
        await settle();
        final shown = habit().history[d] ?? 0;
        final notice = habits.takeHealthNotice();
        if (amount < floor) {
          if (shown != floor) problem('${habit().name} ${d.month}/${d.day}: lowered to $amount, shows $shown, not Health\'s $floor');
          if (notice == null || !notice.contains('Change it in')) problem('${habit().name}: no notice stopping at $floor');
        } else {
          if (shown != amount) problem('${habit().name} ${d.month}/${d.day}: set to $amount, shows $shown (floor $floor)');
          if (notice != null) problem('${habit().name}: a notice "$notice" for an allowed change');
          // Accepted: an immediate sync (nothing new in Health) keeps it
          await syncAndCheck();
          final after = habit().history[d] ?? 0;
          if (after != shown) problem('${habit().name} ${d.month}/${d.day}: $shown was put back to $after by a sync');
        }
      }

      for (var i = 0; i < 60; i++) {
        final today = day(now);
        final dice = Random(i * 7919 + 17);
        dayTotal[today] = 3000 + dice.nextInt(9000);

        // Morning: the app opens (a sync)
        now = DateTime(today.year, today.month, today.day, 8);
        steps[today] = (dayTotal[today]! * 0.2).round();
        await syncAndCheck(force: false);

        // Midday: steps so far, water from the other app, the person's taps
        now = DateTime(today.year, today.month, today.day, 12, 30);
        steps[today] = (dayTotal[today]! * 0.5).round();
        if (dice.nextDouble() < 0.4) {
          otherWater[today] = (otherWater[today] ?? 0) + 250;
          ml[today] = (ml[today] ?? 0) + 250;
        }
        await syncAndCheck();
        final glasses = water().history[today] ?? 0;
        await change(water, today, glasses + 1 + dice.nextInt(3));
        if (dice.nextDouble() < 0.5) await change(water, today, max(0, (water().history[today] ?? 0) - 1 - dice.nextInt(3)));
        if (dice.nextDouble() < 0.4) {
          final s = walk().history[today] ?? 0;
          await change(walk, today, max(0, s - 2000 + dice.nextInt(4000)));
        }

        // Evening: Calendar edits a past day, sometimes outside the window
        now = DateTime(today.year, today.month, today.day, 18);
        steps[today] = (dayTotal[today]! * 0.9).round();
        if (i > 0 && dice.nextDouble() < 0.5) {
          final back = 1 + dice.nextInt(min(i, 12));
          final d = DateTime(today.year, today.month, today.day - back);
          final s = walk().history[d] ?? 0;
          await change(walk, d, max(0, s - 3000 + dice.nextInt(5000)));
        }
        if (dice.nextDouble() < 0.3) await syncAndCheck();

        // Late: the rest of the day's steps, and midnight's sync
        steps[today] = dayTotal[today]!;
        now = DateTime(today.year, today.month, today.day + 1, 0, 0, 1);
        await syncAndCheck();
        now = DateTime(today.year, today.month, today.day + 1, 7);
      }
    });

    expect(problems, isEmpty, reason: '\n${problems.length} problems:\n${problems.take(40).join('\n')}');
  }, timeout: const Timeout(Duration(minutes: 5)));
}

List<HealthWrite> _writes(String raw) {
  final decoded = jsonDecode(raw);
  return decoded is List ? [for (final e in decoded) if (HealthWrite.fromJson(e) case final w?) w] : const [];
}
