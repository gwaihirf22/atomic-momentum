// Pictures of the real app at any window size, with real fonts and a year
// of use, for checking layouts by eye (iPad sizes most of all, which a
// simulator can't turn from the command line). Not part of the suite (it's
// under tool/):
//
//   ./flutter/bin/flutter test tool/screens/layout_shots_test.dart
//
// writes build/layout_shots/<size>_<screen>.png. Set up as the monkey test
// is (test/monkey/monkey_test.dart).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/demo/demo_world.dart';
import 'package:atomic_momentum/core/dev/year_of_use.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/achievement_store.dart';
import 'package:atomic_momentum/core/services/home_widget_bridge.dart';
import 'package:atomic_momentum/core/services/notification_service.dart';
import 'package:atomic_momentum/data/datasources/shared_preferences_datasource.dart';
import 'package:atomic_momentum/main.dart';
import 'package:atomic_momentum/presentation/tour/tour.dart';
import 'package:atomic_momentum/presentation/tour/tour_controller.dart';
import 'package:atomic_momentum/presentation/tour/world_scope.dart';

import '../../test/helpers/fake_app_icon_service.dart';
import '../../test/helpers/fake_health_source.dart';
import '../../test/helpers/fake_home_widget_bridge.dart';
import '../../test/helpers/fake_notifications_plugin.dart';
import '../../test/helpers/fake_sharer.dart';
import '../../test/helpers/fake_support_link.dart';
import '../../test/helpers/fake_web_pages.dart';
import '../../test/helpers/real_fonts.dart';

const sizes = {
  'ipad11_wide': Size(1194, 834),
  'ipad11_upright': Size(834, 1194),
  'ipad13_wide': Size(1376, 1032),
  'split_half': Size(597, 834),
  'iphone': Size(390, 844),
};

const tabs = ['habits', 'calendar', 'insights', 'inspire', 'settings'];

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  setUpAll(loadRealFonts);

  late WorldController worlds;

  setUp(() async {
    await resetDependencies();
    final now = clock.now();
    final year = YearOfUse.stored(YearOfUse.personaEnding(now), now);
    SharedPreferences.setMockInitialValues({
      SharedPreferencesDataSource.habitsKey: year.habits,
      AchievementStore.key: year.seen,
      TourStore.key: [for (final id in TourId.values) id.name],
    });
    NotificationService.debugOverride(plugin: FakeNotificationsPlugin());
    await initializeDependencies(seedDefaultHabit: false);
    FakeHealthSource.install();
    FakeSharer.install();
    FakeSupportLink.install();
    FakeWebPages.install();
    FakeAppIconService.install();
    sl.unregister<HomeWidgetBridge>();
    sl.registerSingleton<HomeWidgetBridge>(FakeHomeWidgetBridge());
    worlds = WorldController(seed: (now) async => DemoSeed.build(now));
  });

  tearDown(() async {
    NotificationService.debugReset();
    await resetDependencies();
  });

  Future<void> shot(WidgetTester tester, String name) async {
    await _settle(tester);
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shotBoundary')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/layout_shots/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    });
  }

  for (final entry in sizes.entries) {
    testWidgets('pictures at ${entry.key}', timeout: const Timeout(Duration(minutes: 5)), (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(RepaintBoundary(key: const Key('shotBoundary'), child: MomentumApp(worlds: worlds)));
      await _settle(tester);
      // Anything that opened over the tabs (a celebration) closes first
      void closeOverlays() => tester.state<NavigatorState>(find.byType(Navigator).first).popUntil((r) => r.isFirst);
      for (final tab in tabs) {
        closeOverlays();
        await _settle(tester);
        await tester.tap(find.byKey(Key('tab_$tab')));
        await shot(tester, '${entry.key}_$tab');
      }
      // A habit's page (beside the list when wide)
      closeOverlays();
      await tester.tap(find.byKey(const Key('tab_habits')));
      await _settle(tester);
      final card = find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('habitCard_'));
      await tester.tap(card.first);
      await shot(tester, '${entry.key}_habit');
    });
  }
}
