import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/freeze_bank.dart';
import 'package:atomic_momentum/core/sync/cloud_transport.dart';
import 'package:atomic_momentum/core/sync/sync_service.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/quote_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/presentation/widgets/sync_settings_section.dart';

import '../helpers/fake_cloud.dart';

/// Settings → Sync.
void main() {
  late FakeCloud cloud;
  late FakeCloudLink link;
  late SyncService sync;
  late HabitProvider habits;

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    cloud = FakeCloud();
    link = cloud.link();
    sl.unregister<SyncService>();
    sync = SyncService(prefs: get<SharedPreferences>(), transport: link, delay: const Duration(hours: 1));
    sl.registerSingleton<SyncService>(sync);
    habits = get<HabitProvider>();
    await habits.loadHabits();
    sync.attach(habits: habits, settings: get<SettingsProvider>(), bank: get<FreezeBank>());
  });

  tearDown(() async {
    sync.dispose();
    await resetDependencies();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: get<ThemeProvider>()),
        ChangeNotifierProvider<HabitProvider>.value(value: habits),
        ChangeNotifierProvider<CategoryProvider>.value(value: get<CategoryProvider>()),
        ChangeNotifierProvider<SettingsProvider>.value(value: get<SettingsProvider>()),
        ChangeNotifierProvider<QuoteProvider>.value(value: get<QuoteProvider>()),
      ],
      child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: SyncSettingsSection(always: true)))),
    ));
    await tester.pumpAndSettle();
  }

  Finder text(String s) => find.textContaining(s);
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

  testWidgets('turns on, syncs, and says when it last did', (tester) async {
    await pump(tester);
    expect(find.text('Sync with iCloud'), findsOneWidget);
    expect(find.byKey(const Key('syncNow')), findsNothing);

    await tester.tap(find.byKey(const Key('syncSwitch')));
    await tester.pumpAndSettle();
    expect(sync.isOn, isTrue);
    expect(text('Synced'), findsOneWidget);
    expect(find.byKey(const Key('syncNow')), findsOneWidget);
    expect(cloud.buckets, isNotEmpty);

    // Offline: says it'll go when it can
    link.offline = true;
    await tester.tap(find.byKey(const Key('syncNow')));
    await tester.pumpAndSettle();
    expect(text('Waiting for a connection'), findsOneWidget);
    // Nothing left waiting to run when the test ends
    await sync.turnOff();
  }, variant: ios);

  testWidgets('turning off asks whether to keep the copy in iCloud', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('syncSwitch')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('syncSwitch')));
    await tester.pumpAndSettle();
    expect(find.text('Turn off sync?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('syncOffCancel')));
    await tester.pumpAndSettle();
    expect(sync.isOn, isTrue);

    await tester.tap(find.byKey(const Key('syncSwitch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('syncOffDelete')));
    await tester.pumpAndSettle();
    expect(sync.isOn, isFalse);
    expect(cloud.buckets, isEmpty);
  }, variant: ios);

  testWidgets('without an iCloud account it stays off and says why', (tester) async {
    link.availabilityNow = CloudAvailability.noAccount;
    await pump(tester);
    await tester.tap(find.byKey(const Key('syncSwitch')));
    await tester.pumpAndSettle();
    expect(sync.isOn, isFalse);
    expect(text('Sign in to iCloud'), findsOneWidget);
  }, variant: ios);

  testWidgets('explains where the habits go', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('syncAbout')));
    await tester.pumpAndSettle();
    expect(text('I never see it'), findsOneWidget);
    expect(text('Apple Health numbers stay out of it'), findsOneWidget);
  }, variant: ios);

  testWidgets('says Google Drive on Android', (tester) async {
    await pump(tester);
    expect(find.text('Sync with Google Drive'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
