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

import '../helpers/fake_app_icon_service.dart';
import '../helpers/fake_health_source.dart';
import '../helpers/fake_home_widget_bridge.dart';
import '../helpers/fake_notifications_plugin.dart';
import '../helpers/fake_sharer.dart';
import '../helpers/fake_support_link.dart';
import '../helpers/fake_web_pages.dart';
import '../helpers/real_fonts.dart';

/// The whole app at iPad sizes, with a year of use and real fonts: every
/// section from the sidebar, a habit's page (beside the list when wide) and
/// Add as a form sheet, at standard and large text. Nothing may overflow or
/// be cut off. (Each screen alone at iPad widths is in small_screens_test.)
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

  bool isCard(Widget w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('habitCard_');

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  void expectNothingCutOff(WidgetTester tester, String where) {
    final error = tester.takeException();
    expect(error, isNull, reason: '$where: $error');
    final cut = [
      for (final p in tester.allRenderObjects.whereType<RenderParagraph>())
        if (p.didExceedMaxLines) '"${p.text.toPlainText()}"',
    ];
    expect(cut, isEmpty, reason: '$where: cut off: ${cut.join(', ')}');
  }

  for (final (name, size) in const [
    ('iPad 11" upright', Size(834, 1194)),
    ('iPad 11" sideways', Size(1194, 834)),
    ('iPad 13" upright', Size(1032, 1376)),
    ('iPad 13" sideways', Size(1376, 1032)),
    ('Split View, half', Size(597, 834)),
    ('Split View, two thirds', Size(780, 834)),
  ]) {
    for (final scale in [1.0, 1.35]) {
      final setting = '$name, text ${(scale * 100).round()}%';
      testWidgets('every section, a habit and Add fit at $setting', timeout: const Timeout(Duration(minutes: 3)),
          (tester) async {
        tester.view.physicalSize = size * 2;
        tester.view.devicePixelRatio = 2;
        tester.view.padding = const FakeViewPadding(top: 24 * 2, bottom: 20 * 2);
        tester.platformDispatcher.textScaleFactorTestValue = scale * sfWidthAllowance;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(MomentumApp(worlds: worlds));
        // A year of use loads off the main isolate: real time for it to finish
        for (var i = 0; i < 50 && find.byWidgetPredicate(isCard).evaluate().isEmpty; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
          await settle(tester);
        }
        void closeOverlays() =>
            tester.state<NavigatorState>(find.byType(Navigator).first).popUntil((route) => route.isFirst);

        for (final tab in ['calendar', 'insights', 'inspire', 'settings', 'habits']) {
          closeOverlays();
          await settle(tester);
          await tester.tap(find.byKey(Key('tab_$tab')));
          await settle(tester);
          expectNothingCutOff(tester, '$tab at $setting');
        }
        await tester.tap(find.byWidgetPredicate(isCard).first);
        await settle(tester);
        expectNothingCutOff(tester, 'a habit at $setting');

        closeOverlays();
        await settle(tester);
        await tester.tap(find.byKey(const Key('addHabitButton')));
        await settle(tester);
        expectNothingCutOff(tester, 'Add at $setting');
        closeOverlays();
        await settle(tester);
      });
    }
  }
}
