import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/dev/year_of_use.dart';
import 'package:atomic_momentum/core/dev/year_persona.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/data/datasources/shared_preferences_datasource.dart';
import 'package:atomic_momentum/data/models/habit_model.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/main.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';

/// How the real app performs with a year (or two) of history, on a device,
/// in profile mode (compiled ahead of time, as it ships): the launch and the
/// first look at each history screen, as wall time and frame times.
///
/// Run with tool/perf_check.sh "<device>" [years]: profile mode needs an
/// Android emulator or a real phone (the iOS simulator only runs debug).
/// Storage is in memory: the device's own habits are never touched.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const years = int.fromEnvironment('YEARS', defaultValue: 1);

  testWidgets('a year of history: launch and first looks', (tester) async {
    final now = clock.now();
    final year = YearOfUse.build(YearOfUse.personaEnding(now), now);
    DateTime back(DateTime d, int y) => DateTime(d.year, d.month, d.day - 364 * y);
    final habits = [
      for (final h in year)
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
        ),
    ];
    SharedPreferences.setMockInitialValues({
      SharedPreferencesDataSource.habitsKey: jsonEncode([for (final Habit h in habits) HabitModel.fromDomain(h).toCompactJson()]),
      'achievements_seen_v1': <String>[],
    });

    final wall = <String, int>{};
    Future<void> measure(String name, Future<void> Function() action) async {
      final watch = Stopwatch()..start();
      await binding.watchPerformance(action, reportKey: name);
      wall[name] = watch.elapsedMilliseconds;
    }

    Future<void> settle() async {
      try {
        await tester.pumpAndSettle(const Duration(milliseconds: 16), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
      } on FlutterError {
        // Something keeps animating
      }
    }

    Future<void> until(Finder finder) async {
      for (var i = 0; i < 600 && finder.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    await measure('launch', () async {
      await initializeDependencies(seedDefaultHabit: false);
      await tester.pumpWidget(const MomentumApp());
      await until(find.byKey(const Key('overallMomentum')));
      await settle();
    });
    // The app's own provider (HabitProvider is made per request)
    final provider = Provider.of<HabitProvider>(tester.element(find.byKey(const Key('overallMomentum'))), listen: false);
    expect(find.byKey(const Key('overallMomentum')), findsOneWidget);

    await measure('first look at Insights', () async {
      await tester.tap(find.byKey(const Key('tab_insights')));
      await settle();
    });

    await measure('full heatmap, opened and scrolled', () async {
      final expand = find.byKey(const Key('heatmapExpand')).first;
      await Scrollable.ensureVisible(tester.element(expand), alignment: 0.4);
      await settle();
      await tester.tap(expand);
      await settle();
      for (var i = 0; i < 3; i++) {
        await tester.fling(find.byKey(const Key('heatmapScroll')), const Offset(400, 0), 2000);
        await settle();
      }
      await tester.pageBack();
      await settle();
    });

    await measure('Achievements page', () async {
      final shelf = find.byKey(const Key('insightsSeeAllAchievements'));
      await Scrollable.ensureVisible(tester.element(shelf), alignment: 0.4);
      await settle();
      await tester.tap(shelf);
      await settle();
      await tester.pageBack();
      await settle();
    });

    await tester.tap(find.byKey(const Key('tab_habits')));
    await settle();
    final water = provider.habits.firstWhere((h) => h.name == YearPersona.water);
    await measure('habit page', () async {
      final card = find.byKey(Key('habitCard_${water.id}'));
      await Scrollable.ensureVisible(tester.element(card), alignment: 0.4);
      await settle();
      await tester.tap(card);
      await settle();
      await tester.pageBack();
      await settle();
    });

    final read = provider.habits.firstWhere((h) => h.name == YearPersona.read);
    await measure('a tap on +', () async {
      final plus = find.byKey(Key('incrementHabit_${read.id}'));
      await Scrollable.ensureVisible(tester.element(plus), alignment: 0.4);
      await settle();
      await tester.tap(plus);
      await settle();
    });

    binding.reportData = {...?binding.reportData, 'wall_ms': wall, 'years': years};
  }, timeout: const Timeout(Duration(minutes: 10)));
}
