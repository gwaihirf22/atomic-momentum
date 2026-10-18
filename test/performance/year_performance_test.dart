import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/dev/year_of_use.dart';
import 'package:atomic_momentum/core/dev/year_persona.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/data/datasources/shared_preferences_datasource.dart';
import 'package:atomic_momentum/data/models/habit_model.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/services/achievements.dart';
import 'package:atomic_momentum/domain/services/habit_stats.dart';
import 'package:atomic_momentum/domain/services/insights.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';

/// How long the work a mature user's app does takes, at one and two years
/// of history: a cold start (and the first one of a day, which saves every
/// habit that rolled over), a tap, and the first time each history screen
/// opens. Debug VM numbers, so several times what ships, but they move
/// together: the budgets catch anything that grows out of hand.
///
/// `--dart-define=PERF_PRINT=true` prints the table.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const print = bool.fromEnvironment('PERF_PRINT');

  // A year ending today (and, for two, the same year again before it)
  final now = DateTime(2027, 10, 18, 20);
  final persona = YearOfUse.personaEnding(now);
  final year = YearOfUse.build(persona, now);

  /// [habits] with their history repeated [years] times back.
  List<Habit> spanning(List<Habit> habits, int years) => withClock(Clock.fixed(now), () {
        DateTime back(DateTime d, int y) => DateTime(d.year, d.month, d.day - 364 * y);
        return [
          for (final h in habits)
            h.copyWith(
              history: {
                for (var y = 0; y < years; y++)
                  for (final e in h.history.entries) back(e.key, y): e.value,
              },
              twoMinuteDays: {
                for (var y = 0; y < years; y++)
                  for (final d in h.twoMinuteDays) back(d, y),
              },
              metadata: h.metadata.copyWith(createdDate: back(h.metadata.createdDate, years - 1)),
            ).refresh(now),
        ];
      });

  String stored(List<Habit> habits) =>
      jsonEncode([for (final h in habits) HabitModel.fromDomain(h).toCompactJson()]);

  final results = <String, Map<int, int>>{};
  int time(String what, int years, void Function() work) {
    final watch = Stopwatch()..start();
    work();
    final ms = watch.elapsedMilliseconds;
    (results[what] ??= {})[years] = ms;
    return ms;
  }

  Future<int> timeAsync(String what, int years, Future<void> Function() work) async {
    final watch = Stopwatch()..start();
    await work();
    final ms = watch.elapsedMilliseconds;
    (results[what] ??= {})[years] = ms;
    return ms;
  }

  tearDown(resetDependencies);

  // Once through everything first, so the first numbers aren't the VM warming up
  setUpAll(() async {
    final at = now.add(const Duration(minutes: 1));
    await resetDependencies();
    SharedPreferences.setMockInitialValues({SharedPreferencesDataSource.habitsKey: stored(year)});
    await withClock(Clock.fixed(at), () async {
      await initializeDependencies(seedDefaultHabit: false);
      await get<HabitProvider>().loadHabits();
      final fresh = [for (final h in year) h.refresh(at)];
      Achievements.earned(fresh, at);
      Achievements.next(fresh, at);
      Insights.kept(fresh, from: persona.start, now: at);
      Insights.weekdays(fresh, from: persona.start, now: at);
      Insights.momentumByMonth(fresh, at);
      HabitStats.of(fresh.first, at);
    });
    await resetDependencies();
  });

  tearDownAll(() {
    if (!print) return;
    final lines = [
      '${'(ms, debug VM)'.padRight(34)}1 year  2 years',
      for (final e in results.entries)
        '${e.key.padRight(34)}${'${e.value[1] ?? '-'}'.padLeft(6)}  ${'${e.value[2] ?? '-'}'.padLeft(7)}',
    ];
    // ignore: avoid_print
    print_(lines.join('\n'));
  });

  for (final years in [1, 2]) {
    group('$years year${years == 1 ? '' : 's'} of history', () {
      late List<Habit> habits;

      setUp(() => habits = spanning(year, years));

      Future<HabitProvider> launch(DateTime at) async {
        await resetDependencies();
        SharedPreferences.setMockInitialValues({SharedPreferencesDataSource.habitsKey: stored(habits)});
        return withClock(Clock.fixed(at), () async {
          await initializeDependencies(seedDefaultHabit: false);
          final provider = get<HabitProvider>();
          await provider.loadHabits();
          return provider;
        });
      }

      test('a cold start, and the first one of a day', () async {
        await timeAsync('cold start (same day)', years, () => launch(now.add(const Duration(minutes: 5))));
        // The next morning every daily habit rolls over and is saved
        await timeAsync('cold start (first of a day)', years, () => launch(DateTime(now.year, now.month, now.day + 1, 7)));
      });

      test('a tap, saved', () async {
        final provider = await launch(now.add(const Duration(minutes: 5)));
        final read = provider.habits.firstWhere((h) => h.name == YearPersona.read);
        await withClock(Clock.fixed(now.add(const Duration(minutes: 6))), () async {
          await timeAsync('tap + (saved)', years, () async {
            await provider.updateHabitProgress(read.id, read.progress + 1);
            await pumpEventQueue();
          });
        });
      });

      test('the first look at each history screen', () {
        final at = now.add(const Duration(minutes: 5));
        withClock(Clock.fixed(at), () {
          // Fresh instances, as after a launch: nothing worked out yet
          final fresh = [for (final h in habits) h.refresh(at)];
          time('achievements check (main screen)', years, () => Achievements.earned(fresh, at));
          final today = DateTime(at.year, at.month, at.day);
          final from = DateTime(today.year, today.month, today.day - 26 * 7 + 1);
          time('Insights (all of it)', years, () {
            Insights.days(fresh, from: from, to: today, now: at);
            Insights.kept(fresh, from: from, now: at);
            Insights.kept(fresh, from: from, now: at);
            Insights.momentumByMonth(fresh, at);
            Insights.weekdays(fresh, from: from, now: at);
            Insights.longestStreak(fresh);
            Insights.formed(fresh);
            Achievements.earned(fresh, at);
            Achievements.next(fresh, at);
          });
          final first = fresh.map((h) => h.trackedFrom).reduce((a, b) => a.isBefore(b) ? a : b);
          time('full heatmap', years, () => Insights.days(fresh, from: first, to: today, now: at));
          time('Achievements page', years, () {
            Achievements.earned(fresh, at);
            Achievements.next(fresh, at);
          });
          final water = [for (final h in habits) h.refresh(at)].firstWhere((h) => h.name == YearPersona.water);
          time('habit page (fresh habit)', years, () {
            HabitStats.of(water, at);
            Insights.days([water], from: from, to: today, now: at);
            Achievements.earned([water], at);
            Achievements.next([water], at);
          });
        });
      });
    });
  }
}

// ignore: avoid_print
void print_(String text) => print(text);
