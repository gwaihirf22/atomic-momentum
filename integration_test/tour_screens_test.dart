import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/main.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/presentation/tour/tour.dart';
import 'package:atomic_momentum/presentation/tour/tour_controller.dart';
import 'package:atomic_momentum/presentation/tour/tours.dart';
import 'package:atomic_momentum/screens/ios_main_navigation.dart';

/// Screenshots of the tours on a real screen, for review: the first launch's
/// Habits tour step by step in Light, Sepia and Charged, at the default
/// text size and iOS's largest standard one (135%), then every other tour
/// once. Storage is in memory; the device's own habits are never touched.
///
/// Run with tool/tour_screens.sh "<simulator or emulator>"; the pictures land
/// in build/tour_screens/<device>/.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<TourController> launch(WidgetTester tester, Map<String, Object> values, {required TourStart start}) async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues(values);
    await initializeDependencies(seedDefaultHabit: false);
    await tester.pumpWidget(Container());
    await tester.pumpWidget(MomentumApp(tourStart: start));
    await _wait(tester, 1500);
    return Provider.of<TourController>(tester.element(find.byType(IOSMainNavigation)), listen: false);
  }

  Future<void> walk(WidgetTester tester, TourController tours, Tour tour, String prefix) async {
    for (var i = 0; i < tour.steps.length; i++) {
      await _ready(tester, tours);
      await _wait(tester, 600);
      await binding.takeScreenshot('${prefix}_step${i + 1}');
      if (!tours.isRunning) break;
      // Not awaited: its frames come from the pumping above
      unawaited(tours.next());
    }
    if (tours.isRunning) unawaited(tours.skip());
    await _wait(tester, 600);
  }

  testWidgets('the tours, step by step, in every theme and text size', (tester) async {
    var converted = false;
    for (final theme in [Appearance.sepia, Appearance.dark, Appearance.light]) {
      for (final scale in [1.0, 1.35]) {
        binding.platformDispatcher.textScaleFactorTestValue = scale;
        final tours = await launch(tester, {}, start: TourStart.firstRun);
        if (Platform.isAndroid && !converted) {
          await binding.convertFlutterSurfaceToImage();
          converted = true;
        }
        await Provider.of<ThemeProvider>(tester.element(find.byType(IOSMainNavigation)), listen: false)
            .setAppearance(theme);
        await walk(tester, tours, Tours.habits, 'habits_${theme.name}_${(scale * 100).round()}');
        await _wait(tester, 800);
      }
    }
    binding.platformDispatcher.clearTextScaleFactorTestValue();

    // The others once, in Sepia, with the Habits tour behind them
    for (final tour in Tours.all.values.where((t) => t.id != TourId.habits && t.id != TourId.editor)) {
      final tours = await launch(tester, {TourStore.key: ['habits']}, start: TourStart.none);
      await Provider.of<ThemeProvider>(tester.element(find.byType(IOSMainNavigation)), listen: false)
          .setAppearance(Appearance.sepia);
      unawaited(tours.start(tour.id));
      await walk(tester, tours, tour, tour.id.name);
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}

/// Waits, in real time, for the tour's step to be ready (the example
/// habits are built off the main thread first; a pump alone doesn't wait).
Future<void> _ready(WidgetTester tester, TourController tours) async {
  final watch = Stopwatch()..start();
  while (tours.isRunning && !tours.isReady && watch.elapsed < const Duration(seconds: 60)) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 16));
  }
  // ignore: avoid_print
  print('TOUR ${tours.tour?.id.name} step ${tours.stepIndex + 1} ready after ${watch.elapsedMilliseconds} ms');
  expect(!tours.isRunning || tours.isReady, isTrue, reason: 'the step never became ready');
}

/// Lets frames run for [ms] (the spotlight's pulse never settles).
Future<void> _wait(WidgetTester tester, int ms) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
