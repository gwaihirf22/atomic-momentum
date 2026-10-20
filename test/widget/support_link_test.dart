import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/quote_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/screens/settings_screen.dart';

import '../helpers/fake_support_link.dart';

/// Settings → Support → "Buy me a coffee".
void main() {
  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
  });

  tearDown(resetDependencies);

  Future<void> pump(WidgetTester tester) async {
    // Tall enough for all of Settings, so Support (near the end) is built
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

  final coffee = find.byKey(const Key('buyMeACoffee'));

  testWidgets('shows where it is offered, and opens the page', (tester) async {
    final link = FakeSupportLink.install();
    await pump(tester);
    expect(coffee, findsOneWidget);
    expect(find.textContaining('Momentum is free'), findsOneWidget);
    await tester.tap(coffee);
    await tester.pumpAndSettle();
    expect(link.opened, 1);
    expect(find.text("Couldn't open the page"), findsNothing);
  });

  testWidgets('is hidden where it is not offered (outside the US, or no page yet)', (tester) async {
    FakeSupportLink.install(available: false);
    await pump(tester);
    expect(coffee, findsNothing);
    expect(find.text('SUPPORT'), findsNothing);
  });

  testWidgets("says so when the page can't open", (tester) async {
    FakeSupportLink.install(opens: false);
    await pump(tester);
    await tester.tap(coffee);
    await tester.pumpAndSettle();
    expect(find.text("Couldn't open the page"), findsOneWidget);
  });
}
