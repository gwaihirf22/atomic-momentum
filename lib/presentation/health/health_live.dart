import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../core/injection/injection_container.dart';
import '../../core/services/health_watch.dart';
import '../../domain/entities/health_link.dart';
import '../providers/habit_provider.dart';

/// Keeps habits filled in from Health up to date while the app is open:
/// reads again a moment after Health says it changed ([HealthWatch]), and
/// every [every] anyway (Health Connect can't say). Each device shows what
/// its own Health shows; Health's numbers never travel through sync, so
/// two phones meet once Apple Health has shared their steps itself.
class HealthLive {
  final HabitProvider habits;
  final HealthWatch watch;

  /// How often to read while open, Health or not saying anything.
  final Duration every;

  /// How long after a change to read: Health writes in bursts.
  final Duration settle;

  HealthLive({
    required this.habits,
    required this.watch,
    this.every = const Duration(minutes: 5),
    this.settle = const Duration(seconds: 5),
  });

  bool _foreground = true;
  Set<HealthMetric> _watching = const {};
  Timer? _timer;
  Timer? _settling;

  void start() {
    habits.addListener(_update);
    _update();
  }

  /// The app coming on screen or going.
  set foreground(bool on) {
    if (on == _foreground) return;
    _foreground = on;
    _update();
  }

  void dispose() {
    habits.removeListener(_update);
    _timer?.cancel();
    _settling?.cancel();
  }

  void _update() {
    final metrics = {
      for (final habit in habits.habits)
        if (habit.health case final link?) link.metric,
    };
    // iOS keeps watching in the background (to wake the app), so the list
    // follows the habits, not the screen
    if (!setEquals(metrics, _watching)) {
      _watching = metrics;
      watch.watch(metrics, _changed);
    }
    if (metrics.isEmpty || !_foreground) {
      _timer?.cancel();
      _timer = null;
      _settling?.cancel();
      _settling = null;
    } else {
      _timer ??= Timer.periodic(every, (_) => habits.syncHealth());
    }
  }

  void _changed() {
    if (!_foreground || _watching.isEmpty) return;
    _settling?.cancel();
    _settling = Timer(settle, () {
      _settling = null;
      habits.syncHealth(force: true);
    });
  }
}

/// Runs [HealthLive] for as long as the app is up, on the person's own
/// habits (never a tour's examples). Draws nothing of its own.
class HealthLiveHost extends StatefulWidget {
  final Widget child;

  const HealthLiveHost({super.key, required this.child});

  @override
  State<HealthLiveHost> createState() => _HealthLiveHostState();
}

class _HealthLiveHostState extends State<HealthLiveHost> with WidgetsBindingObserver {
  HealthLive? _live;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Tests that set up their own dependencies may leave the watch out
    if (_live != null || !sl.isRegistered<HealthWatch>()) return;
    _live = HealthLive(habits: context.read<HabitProvider>(), watch: get<HealthWatch>())..start();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _live?.foreground = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _live?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
