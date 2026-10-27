import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';

import '../../core/services/health_sync_service.dart';
import '../../core/services/home_widget_bridge.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/plus_store.dart';
import '../../core/theme/app_palette.dart';
import '../../domain/entities/habit.dart';
import '../../domain/services/quote_of_the_day.dart';
import '../../domain/services/step_size.dart';
import '../providers/category_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/quote_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../../screens/ios_main_navigation.dart';
import 'widget_snapshot.dart';

/// Keeps the home screen widgets in step with the app: rewrites their
/// snapshot shortly after anything they show changes, and logs the taps made
/// on their + buttons the way a tap on the card would (so streaks, momentum,
/// Health and reminders follow).
class HomeWidgetSync with WidgetsBindingObserver {
  final HomeWidgetBridge bridge;
  final HabitProvider habits;
  final SettingsProvider settings;
  final ThemeProvider theme;
  final QuoteProvider quotes;
  final CategoryProvider? categories;

  /// Momentum Plus (the snapshot says whether Siri and Shortcuts, and the
  /// watch's Plus screens, work).
  final PlusStore? plus;

  /// What Apple Health says a linked habit holds on a day: the watch's Crown
  /// stops there (`HealthSyncService.floorOn`).
  final int Function(Habit habit, DateTime day)? floorOn;

  /// [floorOn] from [health]: Health's number for a linked habit being
  /// built, 0 for any other.
  static int Function(Habit habit, DateTime day)? healthFloor(HealthSyncService? health) {
    if (health == null) return null;
    return (habit, day) => habit.health == null || habit.isBreak ? 0 : health.floorOn(habit, day);
  }

  /// Changes come in bursts (a tap notifies several times); one write after.
  static const delay = Duration(milliseconds: 400);

  HomeWidgetSync({
    required this.bridge,
    required this.habits,
    required this.settings,
    required this.theme,
    required this.quotes,
    this.categories,
    this.plus,
    this.floorOn,
  });

  Timer? _timer;
  String? _lastWritten;
  bool _started = false;
  bool _loadedOnce = false;
  bool _applying = false;
  bool _applyAgain = false;

  /// Starts listening; does nothing where there are no widgets. In the
  /// [background] (no screen) it takes queued taps and writes, but leaves
  /// a widget's link to the app that opens.
  void start({bool background = false}) {
    if (_started || !bridge.isSupported) return;
    _started = true;
    habits.addListener(_changed);
    settings.addListener(_changed);
    theme.addListener(_changed);
    quotes.addListener(_changed);
    categories?.addListener(_changed);
    plus?.addListener(_changed);
    bridge.onLogsWaiting = applyLogs;
    WidgetsBinding.instance.addObserver(this);
    _changed();
    if (background) return;
    bridge.onOpen = _open;
    // A widget tap that launched the app
    bridge.takeOpened().then((route) {
      if (route != null) _open(route);
    });
  }

  /// Goes where a tapped widget leads: a habit (shown the way a reminder's
  /// tap shows it) or a tab.
  void _open(String route) {
    if (route.startsWith('habit/')) {
      NotificationService.focusRequests.value = HabitFocusRequest(route.substring('habit/'.length));
      return;
    }
    final tab = switch (route) {
      'inspire' => AppTab.inspire,
      'insights' => AppTab.insights,
      _ => AppTab.habits,
    };
    IOSMainNavigation.tabRequests.value = tab;
  }

  void dispose() {
    if (!_started) return;
    _started = false;
    _timer?.cancel();
    habits.removeListener(_changed);
    settings.removeListener(_changed);
    theme.removeListener(_changed);
    quotes.removeListener(_changed);
    categories?.removeListener(_changed);
    plus?.removeListener(_changed);
    bridge.onLogsWaiting = null;
    bridge.onOpen = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  // Not after a failed load either: its empty list would blank the widgets
  bool get _loaded => habits.state == HabitProviderState.loaded;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Taps queued while the app wasn't running
    if (state == AppLifecycleState.resumed) applyLogs();
  }

  void _changed() {
    // Never hand the widgets the empty list of a launch still loading
    if (!_loaded) return;
    if (!_loadedOnce) {
      _loadedOnce = true;
      // Taps made while the app was closed
      applyLogs();
    }
    _timer?.cancel();
    _timer = Timer(delay, write);
  }

  /// Writes the snapshot now, if it changed.
  Future<void> write() async {
    _timer?.cancel();
    if (!_started || !_loaded) return;
    final now = clock.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final pool = quotes.from(settings.quoteFamilies);
    final quote = quotes.today(settings.quoteFamilies, now: now);
    final quoteNext = QuoteOfTheDay.pick(tomorrow, pool);
    final snapshot = WidgetSnapshot.build(
      habits: habits.habits,
      momentum: habits.overallMomentum,
      now: now,
      light: _lightLook,
      dark: _darkLook,
      quote: quote,
      quoteNext: quoteNext,
      shortQuote: WidgetSnapshot.shortFor(quote, pool, now),
      shortQuoteNext: WidgetSnapshot.shortFor(quoteNext, pool, tomorrow),
      categories: categories?.categories ?? const [],
      findQuote: quotes.find,
      weekStart: settings.firstDayOfWeek,
      plus: plus?.unlocked ?? false,
      floorOn: floorOn,
    );
    final written = jsonEncode(snapshot);
    // The time it was written changes every time; anything else is news
    final compared = jsonEncode(Map.of(snapshot)..remove('written'));
    if (compared == _lastWritten) return;
    _lastWritten = compared;
    await bridge.save(written);
  }

  AppTheme get _lightLook => switch (theme.appearance) {
        Appearance.system => theme.dayTheme,
        Appearance.light => AppTheme.light,
        Appearance.sepia => AppTheme.sepia,
        Appearance.dark => AppTheme.dark,
      };

  AppTheme get _darkLook => theme.appearance == Appearance.system ? AppTheme.dark : _lightLook;

  /// Whether queued logs are being applied now.
  bool get isApplying => _applying;

  /// Logs every queued widget tap, rewrites the snapshot, and lets the
  /// waiting widget know. Waits for habits to load first.
  Future<void> applyLogs() async {
    if (!_started) return;
    if (!_loaded) return; // the first load calls back here
    if (_applying) {
      _applyAgain = true;
      return;
    }
    _applying = true;
    try {
      do {
        _applyAgain = false;
        for (final log in await bridge.takeLogs()) {
          await _apply(log);
        }
      } while (_applyAgain);
      _lastWritten = null; // the widget drew its own guess; replace it
      await write();
    } finally {
      _applying = false;
    }
    await bridge.applied();
  }

  /// One log from a widget, Siri, the watch or a reminder, on the day it
  /// was made (as the card for today, the Calendar for an earlier day):
  /// the next step toward the target, an amount the watch's Crown set, or
  /// the two-minute version.
  Future<void> _apply(WidgetLog log) async {
    final habit = habits.getHabitById(log.habitId);
    if (habit == null || habit.isBreak) return;
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    // A log dated after today (the clock moved back): ignored
    if (log.day.isAfter(today)) return;
    final isToday = log.day == today;
    final total = isToday ? habit.progress : habit.progressForPeriodContaining(log.day);
    switch (log.kind) {
      case WidgetLogKind.step:
        if (total >= habit.target) return;
        await _setTotal(habit, log.day, isToday, total, StepSize.up(total, habit.target));
      case WidgetLogKind.set:
        // The Crown goes up to the target (or what's already over it)
        final amount = math.min(log.amount ?? total, math.max(habit.target, total));
        if (amount == total) return;
        await _setTotal(habit, log.day, isToday, total, amount);
      case WidgetLogKind.twoMinute:
        if (habit.twoMinute == null || total >= habit.target || habit.usedTwoMinuteButtonOn(log.day)) return;
        await habits.setTwoMinute(habit.id, true, date: log.day);
    }
  }

  /// Sets the period containing [day] to [amount] (from [total]): today as
  /// the card does, an earlier day by changing that day's own amount.
  Future<void> _setTotal(Habit habit, DateTime day, bool isToday, int total, int amount) async {
    if (isToday) {
      await habits.updateHabitProgress(habit.id, amount);
    } else {
      final logged = habit.getProgressForDate(day);
      await habits.updateProgressForDate(habit.id, day, math.max(0, logged + amount - total));
    }
  }
}
