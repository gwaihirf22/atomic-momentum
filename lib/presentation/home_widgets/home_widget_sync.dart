import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';

import '../../core/services/home_widget_bridge.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_palette.dart';
import '../../domain/services/step_size.dart';
import '../providers/habit_provider.dart';
import '../providers/quote_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
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

  /// Changes come in bursts (a tap notifies several times); one write after.
  static const delay = Duration(milliseconds: 400);

  HomeWidgetSync({
    required this.bridge,
    required this.habits,
    required this.settings,
    required this.theme,
    required this.quotes,
  });

  Timer? _timer;
  String? _lastWritten;
  bool _started = false;
  bool _loadedOnce = false;
  bool _applying = false;
  bool _applyAgain = false;

  /// Starts listening; does nothing where there are no widgets.
  void start() {
    if (_started || !bridge.isSupported) return;
    _started = true;
    habits.addListener(_changed);
    settings.addListener(_changed);
    theme.addListener(_changed);
    quotes.addListener(_changed);
    bridge.onLogsWaiting = applyLogs;
    bridge.onOpenHabit = _open;
    WidgetsBinding.instance.addObserver(this);
    _changed();
    // A widget tap that launched the app
    bridge.takeOpenedHabit().then((id) {
      if (id != null) _open(id);
    });
  }

  /// Shows the habit whose widget was tapped, the way a reminder's tap does.
  void _open(String habitId) => NotificationService.focusRequests.value = HabitFocusRequest(habitId);

  void dispose() {
    if (!_started) return;
    _started = false;
    _timer?.cancel();
    habits.removeListener(_changed);
    settings.removeListener(_changed);
    theme.removeListener(_changed);
    quotes.removeListener(_changed);
    bridge.onLogsWaiting = null;
    bridge.onOpenHabit = null;
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
    final snapshot = WidgetSnapshot.build(
      habits: habits.habits,
      momentum: habits.overallMomentum,
      now: now,
      light: _lightLook,
      dark: _darkLook,
      quote: quotes.today(settings.quoteFamilies, now: now),
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

  /// One + from a widget: the next step toward the target, on the day it was
  /// tapped (the card's + for today, the Calendar's for an earlier day).
  Future<void> _apply(WidgetLog log) async {
    final habit = habits.getHabitById(log.habitId);
    if (habit == null || habit.isBreak) return;
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    if (log.day == today) {
      if (habit.progress >= habit.target) return;
      await habits.updateHabitProgress(habit.id, StepSize.up(habit.progress, habit.target));
    } else if (log.day.isBefore(today)) {
      if (habit.progressForPeriodContaining(log.day) >= habit.target) return;
      final logged = habit.getProgressForDate(log.day);
      await habits.updateProgressForDate(habit.id, log.day, StepSize.up(logged, habit.target));
    }
    // A tap dated after today (the clock moved back): ignored
  }
}
