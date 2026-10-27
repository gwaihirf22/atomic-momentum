import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/branding/app_icons.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/quote_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/screens/app_icon_screen.dart';
import 'package:atomic_momentum/screens/settings_screen.dart';

import '../helpers/fake_app_icon_service.dart';

/// Settings → App icon.
void main() {
  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
  });

  tearDown(resetDependencies);

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: get<ThemeProvider>()),
        ChangeNotifierProvider<HabitProvider>.value(value: get<HabitProvider>()),
        ChangeNotifierProvider<CategoryProvider>.value(value: get<CategoryProvider>()),
        ChangeNotifierProvider<SettingsProvider>.value(value: get<SettingsProvider>()),
        ChangeNotifierProvider<QuoteProvider>.value(value: get<QuoteProvider>()),
      ],
      child: MaterialApp(home: home),
    ));
    await tester.pumpAndSettle();
  }

  Finder tile(AppIconChoice icon) => find.byKey(Key('appIcon_${icon.id}'));
  bool checked(AppIconChoice icon) =>
      find.descendant(of: tile(icon), matching: find.byKey(const Key('appIconCheck'))).evaluate().isNotEmpty;

  group('the App icon screen', () {
    testWidgets('on iPhone offers Match system, Charged and Light, with the current one checked', (tester) async {
      FakeAppIconService.install();
      await pump(tester, const AppIconScreen());

      for (final icon in AppIcons.all) {
        expect(tile(icon), findsOneWidget, reason: icon.id);
      }
      expect(checked(AppIcons.system), isTrue);
      expect(checked(AppIcons.light), isFalse);
      expect(find.textContaining('iOS 18'), findsOneWidget);
      // iOS keeps the old icon in notifications until a restart: say so
      expect(find.textContaining('until you restart your iPhone'), findsOneWidget);
    });

    testWidgets('picking an icon changes it and moves the check', (tester) async {
      final service = FakeAppIconService.install();
      await pump(tester, const AppIconScreen());

      await tester.tap(tile(AppIcons.light));
      await tester.pumpAndSettle();
      expect(service.changes, [AppIcons.light]);
      expect(checked(AppIcons.light), isTrue);
      expect(checked(AppIcons.system), isFalse);

      // The current one again does nothing
      await tester.tap(tile(AppIcons.light));
      await tester.pumpAndSettle();
      expect(service.changes, [AppIcons.light]);
    });

    testWidgets('when the phone refuses, says so and keeps the icon', (tester) async {
      final service = FakeAppIconService.install()..failWith = 'The operation was cancelled.';
      await pump(tester, const AppIconScreen());

      await tester.tap(tile(AppIcons.charged));
      await tester.pumpAndSettle();
      expect(find.text('Couldn\'t change the icon'), findsOneWidget);
      expect(find.text('The operation was cancelled.'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(service.icon, AppIcons.system);
      expect(checked(AppIcons.system), isTrue);
      expect(checked(AppIcons.charged), isFalse);
    });

    testWidgets('on Android offers fixed icons only, and says when it changes', (tester) async {
      final service = FakeAppIconService.install(platform: TargetPlatform.android);
      await pump(tester, const AppIconScreen());

      expect(tile(AppIcons.system), findsNothing);
      expect(checked(AppIcons.light), isTrue, reason: 'Light by default');
      expect(find.text('Your new icon appears after you leave Momentum.'), findsOneWidget);
      expect(find.textContaining('restart'), findsNothing, reason: 'an iPhone quirk');

      await tester.tap(tile(AppIcons.charged));
      await tester.pumpAndSettle();
      expect(service.changes, [AppIcons.charged]);
    });
  });

  group('Settings', () {
    testWidgets('shows the current icon and opens the picker', (tester) async {
      FakeAppIconService.install();
      await pump(tester, const SettingsScreen());

      final row = find.byKey(const Key('appIconSetting'));
      expect(find.descendant(of: row, matching: find.text('Match system')), findsOneWidget);
      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.tap(tile(AppIcons.light));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.descendant(of: row, matching: find.text('Light')), findsOneWidget);
    });

    testWidgets('leaves it out where icons can\'t change', (tester) async {
      FakeAppIconService.install(platform: TargetPlatform.macOS, isSupported: false);
      await pump(tester, const SettingsScreen());
      expect(find.byKey(const Key('appIconSetting')), findsNothing);
    });
  });
}
