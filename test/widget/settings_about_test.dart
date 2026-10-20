import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/sharer.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/quote_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/screens/settings_screen.dart';

import '../helpers/fake_web_pages.dart';

/// Settings → About: the privacy policy and support pages, reachable in the
/// app as App Review asks.
void main() {
  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
  });

  tearDown(resetDependencies);

  Future<void> pump(WidgetTester tester) async {
    // Tall enough for all of Settings, so About (at the end) is built
    tester.view.physicalSize = const Size(390, 4000);
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
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('the privacy policy and support pages open in the browser', (tester) async {
    final pages = FakeWebPages.install();
    await pump(tester);
    expect(find.text(AppLinks.supportEmail), findsOneWidget);

    await tester.tap(find.byKey(const Key('privacyPolicy')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('contactSupport')));
    await tester.pumpAndSettle();
    expect(pages.opened, [AppLinks.privacy, AppLinks.support]);
    expect(find.text("Couldn't open the page"), findsNothing);
  });

  testWidgets("says where the page is when it can't open", (tester) async {
    FakeWebPages.install(opens: false);
    await pump(tester);
    await tester.tap(find.byKey(const Key('privacyPolicy')));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't open the page"), findsOneWidget);
    expect(find.textContaining(AppLinks.privacy), findsOneWidget);
  });

  test('the links are the published pages', () {
    expect(AppLinks.privacy, 'https://paul-blake.com/momentum/privacy');
    expect(AppLinks.support, 'https://paul-blake.com/momentum/support');
  });
}
