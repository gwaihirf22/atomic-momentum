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

import 'package:atomic_momentum/core/services/plus_store.dart';

import '../helpers/fake_plus_store.dart';
import '../helpers/fake_support_link.dart';

/// Settings → Say thanks → "Buy Paul a coffee".
void main() {
  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
  });

  tearDown(resetDependencies);

  Future<void> pump(WidgetTester tester) async {
    // Tall enough for all of Settings, so Support (near the end) is built
    tester.view.physicalSize = const Size(390, 6000);
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
    // Personal, and plain about where it goes
    expect(find.text('Buy Paul a coffee'), findsOneWidget);
    expect(find.text('Opens buymeacoffee.com in your browser'), findsOneWidget);
    expect(find.textContaining('say thanks'), findsOneWidget);
    expect(find.textContaining('keep it going'), findsNothing);
    expect(find.text('Say thanks'), findsOneWidget, reason: 'its own section, not mistaken for Contact & support');
    await tester.tap(coffee);
    await tester.pumpAndSettle();
    expect(link.opened, 1);
    expect(find.text("Couldn't open the page"), findsNothing);
  });

  testWidgets('is hidden where neither the link nor tips are offered (outside the US, on Android)', (tester) async {
    FakeSupportLink.install(available: false);
    FakePlusStore.install(isSupported: false);
    await pump(tester);
    expect(coffee, findsNothing);
    expect(find.text('Say thanks'), findsNothing);
  });

  testWidgets('outside the US on an iPhone: Plus first, then Apple tips, which unlock nothing', (tester) async {
    FakeSupportLink.install(available: false);
    final plus = FakePlusStore.install();
    await pump(tester);
    expect(coffee, findsNothing);
    expect(find.text('Say thanks'), findsOneWidget);
    expect(find.text(r'Get Momentum Plus · $1.99'), findsOneWidget);
    for (final price in [r'$0.99', r'$2.99', r'$4.99']) {
      expect(find.text('Leave a $price tip'), findsOneWidget);
    }
    // Plus above the tips
    expect(tester.getTopLeft(find.byKey(const Key('sayThanksPlus'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('tip_small'))).dy));

    await tester.tap(find.byKey(const Key('tip_medium')));
    await tester.pumpAndSettle();
    expect(plus.bought, [PlusProducts.tipMedium]);
    expect(find.byKey(const Key('tipThanks')), findsOneWidget);
    expect(plus.unlocked, isFalse);

    // With Plus, only the tips
    plus.unlocked = true;
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sayThanksPlus')), findsNothing);
    expect(find.text(r'Leave a $0.99 tip'), findsOneWidget);
  });

  testWidgets('in the US, the coffee link and no Apple tips', (tester) async {
    FakeSupportLink.install();
    FakePlusStore.install();
    await pump(tester);
    expect(coffee, findsOneWidget);
    expect(find.byKey(const Key('tip_small')), findsNothing);
    expect(find.byKey(const Key('sayThanksPlus')), findsNothing);
  });

  testWidgets("says so when the page can't open", (tester) async {
    FakeSupportLink.install(opens: false);
    await pump(tester);
    await tester.tap(coffee);
    await tester.pumpAndSettle();
    expect(find.text("Couldn't open the page"), findsOneWidget);
  });
}
