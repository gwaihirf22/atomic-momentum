import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/plus_store.dart';
import 'package:atomic_momentum/core/sync/sync_service.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/screens/plus_screen.dart';

import '../helpers/fake_cloud.dart';
import '../helpers/fake_plus_store.dart';
import '../helpers/fake_support_link.dart';

/// The Momentum Plus page: buying, restoring, tips once it's yours.
void main() {
  late FakePlusStore plus;
  late SyncService sync;

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    plus = FakePlusStore.install();
    sl.unregister<SyncService>();
    sync = SyncService(prefs: get<SharedPreferences>(), transport: FakeCloud().link(), delay: const Duration(hours: 1));
    sl.registerSingleton<SyncService>(sync);
    final habits = get<HabitProvider>();
    await habits.loadHabits();
    sync.attach(habits: habits);
  });

  tearDown(() async {
    await sync.turnOff();
    sync.dispose();
    await resetDependencies();
  });

  Future<void> pump(WidgetTester tester, {bool us = true}) async {
    FakeSupportLink.install(available: us);
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: get<ThemeProvider>()),
        ChangeNotifierProvider<SettingsProvider>.value(value: get<SettingsProvider>()),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(key: const Key('open'), onPressed: () => PlusScreen.open(context), child: const Text('Open')),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
  }

  final buy = find.byKey(const Key('plusBuy'));

  testWidgets('says what it is, what\'s coming, the price, and the promise', (tester) async {
    await pump(tester);
    expect(find.text(r'Get Plus · $1.99'), findsOneWidget);
    for (final now in ['Sync with iCloud', 'A year in review', 'Health insights', 'Siri and Shortcuts']) {
      expect(find.text(now), findsOneWidget);
    }
    expect(find.text('COMING NEXT').evaluate().isNotEmpty || find.text('Coming next').evaluate().isNotEmpty, isTrue);
    for (final coming in ['Apple Watch', 'New icons and themes']) {
      expect(find.text(coming), findsOneWidget);
    }
    expect(find.textContaining('Nothing that\'s free today will ever cost money'), findsOneWidget);
    expect(find.byKey(const Key('plusRestore')), findsOneWidget);
    expect(find.textContaining('Family Sharing'), findsOneWidget);
  });

  testWidgets('buying makes it yours, then offers to turn on sync', (tester) async {
    await pump(tester);
    await tester.tap(buy);
    await tester.pumpAndSettle();
    expect(plus.unlocked, isTrue);
    expect(find.byKey(const Key('plusOwned')), findsOneWidget);
    expect(buy, findsNothing);

    await tester.tap(find.byKey(const Key('plusTurnOnSync')));
    await tester.pumpAndSettle();
    expect(sync.isOn, isTrue);
    expect(find.byType(PlusScreen), findsNothing, reason: 'back to where it was opened');
    // Nothing left waiting to run when the test ends
    await sync.turnOff();
  });

  testWidgets('pending, failed and cancelled purchases say so, or nothing, and leave it locked', (tester) async {
    await pump(tester);
    plus.next = PurchaseOutcome.pending;
    await tester.tap(buy);
    await tester.pumpAndSettle();
    expect(find.text('Waiting for approval'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    plus.next = const PurchaseOutcome(PurchaseResult.failed, 'Payment declined');
    await tester.tap(buy);
    await tester.pumpAndSettle();
    expect(find.text("Couldn't complete the purchase"), findsOneWidget);
    expect(find.text('Payment declined'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    plus.next = PurchaseOutcome.cancelled;
    await tester.tap(buy);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(plus.unlocked, isFalse);
  });

  testWidgets('when the store can\'t be reached: "Get Plus" (never "…"), and it says why', (tester) async {
    plus.reachable = false;
    await pump(tester);
    expect(find.text('Get Plus'), findsOneWidget);
    await tester.tap(buy);
    await tester.pumpAndSettle();
    expect(find.text("Can't reach the App Store"), findsOneWidget);
  });

  testWidgets('Restore Purchases: welcome back, or nothing to restore', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('plusRestore')));
    await tester.pumpAndSettle();
    expect(find.text('Nothing to restore'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    plus.restoreFinds = true;
    await tester.tap(find.byKey(const Key('plusRestore')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plusRestored')), findsOneWidget);
    expect(find.byKey(const Key('plusOwned')), findsOneWidget);
  });

  testWidgets('tips once it\'s yours, outside the US only; a tip thanks and unlocks nothing new', (tester) async {
    await pump(tester, us: false);
    expect(find.byKey(const Key('plusTip_small')), findsNothing, reason: 'not before Plus');
    plus.unlocked = true;
    await tester.pumpAndSettle();
    expect(find.text('Want to give more?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('plusTip_large')));
    await tester.pumpAndSettle();
    expect(plus.bought, [PlusProducts.tipLarge]);
    expect(find.byKey(const Key('tipThanks')), findsOneWidget);
  });

  testWidgets('no tips in the US, where the coffee link is', (tester) async {
    plus.unlocked = true;
    await pump(tester);
    expect(find.text('Want to give more?'), findsNothing);
  });
}
