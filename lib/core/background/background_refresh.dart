import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../presentation/home_widgets/home_widget_sync.dart';
import '../../presentation/providers/category_provider.dart';
import '../../presentation/providers/habit_provider.dart';
import '../../presentation/providers/quote_provider.dart';
import '../../presentation/providers/settings_provider.dart';
import '../../presentation/providers/theme_provider.dart';
import '../injection/injection_container.dart';
import '../logging/log.dart';
import '../services/freeze_bank.dart';
import '../services/health_sync_service.dart';
import '../services/home_widget_bridge.dart';
import '../services/plus_store.dart';
import '../sync/sync_service.dart';

/// Work the app does while it isn't on screen (docs/design/sync.md, "In
/// the background"): another device's changes when iCloud says there are
/// some, and Health's numbers when Health says they changed (HealthWatch)
/// or every so often (iOS's background refresh), so reminders for what's
/// already done stop and the widgets show the day as it is.
///
/// iOS asks through `momentum/background` (`BackgroundRun` in
/// CloudSync.swift). With the app running, its own providers do the work
/// ([listen]); with it closed, a small engine of its own starts at
/// [backgroundMain], and the app, if opened meanwhile, waits for it
/// ([waitForBackground]), so two copies never write at once.
class BackgroundRefresh {
  const BackgroundRefresh._();

  static const channel = MethodChannel('momentum/background');

  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// iCloud said another device changed something.
  static const push = 'push';

  /// iOS's background refresh.
  static const refresh = 'refresh';

  /// Apple Health changed what a linked habit reads (HealthWatch.swift).
  static const health = 'health';

  /// The Apple Watch sent a log (WatchLink.swift): the widgets' queue has
  /// it, and HomeWidgetSync applies it.
  static const watch = 'watch';

  /// Does the work for [reason] on [habits]: Health (unless a push or a
  /// watch's log, which are about the app's own data), then sync, then waits
  /// until what they started (saves, notifications) is done.
  static Future<void> run({required HabitProvider habits, SyncService? sync, required String reason}) async {
    if (reason != push && reason != watch) await habits.syncHealth(force: true);
    if (sync != null && sync.isOn) {
      await sync.syncNow();
      await sync.whenIdle();
    }
    await habits.whenSettled();
  }

  /// At launch, before anything is read: waits while the background engine
  /// finishes (iOS stops it after a few seconds if it hasn't).
  static Future<void> waitForBackground() async {
    if (!isSupported) return;
    try {
      await channel.invokeMethod<void>('waitIdle').timeout(const Duration(seconds: 8));
    } catch (e) {
      // Not there (tests, older builds) or slow: carry on
      if (e is! MissingPluginException) logWarning('Background: $e');
    }
  }

  /// Takes iOS's requests while the app is running, on its own providers.
  static void listen({required HabitProvider habits, SyncService? sync}) {
    if (!isSupported) return;
    channel.setMethodCallHandler((call) async {
      if (call.method != 'run') return null;
      final reason = call.arguments as String? ?? refresh;
      sync?.log.add('Woke in the background ($reason)');
      logWarning('Background: $reason, in the app');
      await run(habits: habits, sync: sync, reason: reason);
      logWarning('Background: $reason done');
      // The widgets write a moment after a change (HomeWidgetSync.delay)
      await Future<void>.delayed(HomeWidgetSync.delay * 2);
      return true;
    });
  }
}

/// Where the background engine starts when the app isn't running: loads
/// the habits (which plans notifications afresh), does [BackgroundRefresh.run]
/// and writes the widgets, then tells iOS it's done.
@pragma('vm:entry-point')
Future<void> backgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  var done = false;
  try {
    final reason = await BackgroundRefresh.channel.invokeMethod<String>('reason') ?? BackgroundRefresh.refresh;
    logWarning('Background: $reason, in its own engine');
    await initializeDependencies();
    // No one is there to answer Health's permission sheet
    get<HealthSyncService>().mayAsk = false;
    final habits = get<HabitProvider>();
    await habits.loadHabits();
    logWarning('Background: ${habits.habits.length} habits loaded');
    final sync = get<SyncService>()
      ..attach(
        habits: habits,
        settings: get<SettingsProvider>(),
        theme: get<ThemeProvider>(),
        categories: get<CategoryProvider>(),
        quotes: get<QuoteProvider>(),
        bank: get<FreezeBank>(),
      );
    if (sync.isOn) sync.log.add('Started in the background ($reason)');
    final widgets = HomeWidgetSync(
      bridge: get<HomeWidgetBridge>(),
      habits: habits,
      settings: get<SettingsProvider>(),
      theme: get<ThemeProvider>(),
      quotes: get<QuoteProvider>(),
      categories: get<CategoryProvider>(),
      // What's remembered (no store lookups here), so the watch and Siri
      // keep Plus after a background run
      plus: get<PlusStore>(),
      floorOn: HomeWidgetSync.healthFloor(get<HealthSyncService>()),
    )..start(background: true);
    // Taps from the watch, widgets or a reminder's Log (starting it applied
    // them already; this waits for that to finish)
    await widgets.applyLogs();
    while (widgets.isApplying) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await BackgroundRefresh.run(habits: habits, sync: sync, reason: reason);
    await widgets.write();
    widgets.dispose();
    done = true;
    logWarning('Background: $reason done, ${habits.habits.length} habits');
  } catch (e) {
    logWarning('Background refresh failed: $e');
  } finally {
    try {
      await BackgroundRefresh.channel.invokeMethod<void>('done', done);
    } catch (_) {
      // iOS ends the engine anyway
    }
  }
}
