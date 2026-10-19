import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/demo/demo_world.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/notification_service.dart';
import 'package:atomic_momentum/core/theme/app_palette.dart';
import 'package:atomic_momentum/core/theme/ios_theme.dart';
import 'package:atomic_momentum/presentation/howto/guides.dart';
import 'package:atomic_momentum/presentation/howto/phone_frame.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/quote_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/presentation/tour/world_scope.dart';
import 'package:atomic_momentum/screens/how_to_screen.dart';

import '../helpers/fake_notifications_plugin.dart';
import '../helpers/real_fonts.dart';

void main() {
  setUpAll(loadRealFonts);

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    NotificationService.debugOverride(plugin: FakeNotificationsPlugin());
    await initializeDependencies(seedDefaultHabit: false);
  });

  tearDown(() async {
    NotificationService.debugReset();
    await resetDependencies();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Widget app(Widget home, AppPalette palette) => MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: get<ThemeProvider>()),
          ChangeNotifierProvider<HabitProvider>.value(value: get<HabitProvider>()),
          ChangeNotifierProvider<CategoryProvider>.value(value: get<CategoryProvider>()),
          ChangeNotifierProvider<SettingsProvider>.value(value: get<SettingsProvider>()),
          ChangeNotifierProvider<QuoteProvider>.value(value: get<QuoteProvider>()),
        ],
        child: MaterialApp(theme: IOSTheme.material(palette).copyWith(platform: TargetPlatform.iOS), home: home),
      );

  for (final palette in [AppPalette.sepia, AppPalette.dark, AppPalette.light]) {
    testWidgets('every guide\'s pictures show the app and ring what they\'re about (${palette.theme.name}, 375pt, 135%)',
        (tester) async {
      tester.view.physicalSize = const Size(375, 667) * 3;
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 1.35 * sfWidthAllowance;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final prefs = get<SharedPreferences>();
      final before = jsonEncode({for (final k in prefs.getKeys()) k: prefs.get(k)});
      final world = AppWorld.example(await DemoWorld.create(DemoSeed.build(DateTime.now())));
      addTearDown(world.dispose);

      for (final guide in Guides.all) {
        await tester.pumpWidget(app(GuideScreen(guide: guide, world: world), palette));
        await settle(tester);
        for (var i = 0; i < guide.cards.length; i++) {
          final card = find.byKey(Key('guideCard_${guide.id}_$i'));
          await tester.scrollUntilVisible(card, 300, scrollable: find.byType(Scrollable).first);
          await settle(tester);
          expect(tester.takeException(), isNull, reason: '${guide.id} card ${i + 1}');
          if (guide.cards[i].scene.highlight != null) {
            expect(find.descendant(of: card, matching: find.byKey(const Key('howToRing'))), findsOneWidget,
                reason: '${guide.id} card ${i + 1} rings ${guide.cards[i].scene.highlight!.name}');
          }
        }
      }
      expect(jsonEncode({for (final k in prefs.getKeys()) k: prefs.get(k)}), before, reason: "pictures never touch the person's data");
    });
  }

  testWidgets('How to lists the guides once the example habits are ready, and opens one', (tester) async {
    await tester.pumpWidget(app(HowToScreen(seed: (now) async => DemoSeed.build(now)), AppPalette.sepia));
    await settle(tester);
    for (final guide in Guides.all.take(3)) {
      expect(find.text(guide.title), findsOneWidget);
    }
    await tester.tap(find.byKey(const Key('guide_log')));
    await settle(tester);
    expect(find.byType(GuideScreen), findsOneWidget);
    expect(find.byType(PhonePicture), findsWidgets);
  });
}
