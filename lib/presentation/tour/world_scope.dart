import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/demo/demo_world.dart';
import '../../core/injection/injection_container.dart';
import '../../core/services/health_source.dart';
import '../../domain/entities/health_link.dart';
import '../../screens/ios_main_navigation.dart';
import '../providers/category_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/quote_provider.dart';
import '../providers/settings_provider.dart';
import 'tour_controller.dart';

/// What the app shows: the person's own habits, or a tour's example world
/// ([demo]). Each world has its own root navigator ([navigatorKey]), so
/// switching remounts everything below the app (pages, sheets, the editor
/// on the root navigator) on the world's providers, while the theme, the
/// intro and the home screen widgets stay with the real ones above.
class AppWorld {
  final DemoWorld? demo;
  final AppTab initialTab;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final MainNavigationController nav = MainNavigationController();

  AppWorld.real({this.initialTab = AppTab.habits}) : demo = null;
  AppWorld.example(DemoWorld this.demo, {this.initialTab = AppTab.habits});

  bool get isDemo => demo != null;

  void dispose() => demo?.dispose();
}

/// Switches the app between the person's habits and a tour's example world.
class WorldController extends ChangeNotifier {
  /// Where the example habits come from (tests build them in place).
  final Future<DemoSeed> Function(DateTime now) seed;

  WorldController({Future<DemoSeed> Function(DateTime now)? seed}) : seed = seed ?? DemoSeed.forDay;

  AppWorld _world = AppWorld.real();
  AppWorld get world => _world;

  bool _switching = false;

  /// The person's tab when the example world opened: where they go back to.
  AppTab _returnTab = AppTab.habits;

  /// Shows the example habits, on [tab]. The person's own pages close;
  /// leaving brings them back to [tab] of their own app.
  Future<void> enterDemo({AppTab tab = AppTab.habits}) async {
    if (_world.isDemo || _switching) return;
    _switching = true;
    try {
      final settings = sl.isRegistered<SharedPreferences>() ? get<SharedPreferences>() : null;
      final demo = await DemoWorld.create(await seed(clock.now()), settingsFrom: settings);
      if (_disposed) {
        demo.dispose();
        return;
      }
      _returnTab = _world.nav.current.value;
      _replace(AppWorld.example(demo, initialTab: tab));
    } finally {
      _switching = false;
    }
  }

  /// Back to the person's own habits, on [tab] (by default the tab they
  /// were on when the example world opened).
  void exitDemo({AppTab? tab}) {
    if (!_world.isDemo) return;
    _replace(AppWorld.real(initialTab: tab ?? _returnTab));
  }

  bool _disposed = false;

  void _replace(AppWorld next) {
    if (_disposed) {
      next.dispose();
      return;
    }
    final old = _world;
    _world = next;
    notifyListeners();
    // Once the old world's screens are gone
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _disposed = true;
    _world.dispose();
    super.dispose();
  }
}

/// Puts [world]'s providers around the app below it (the root navigator
/// included), and tells screens whether they show example habits.
class WorldScope extends InheritedWidget {
  final AppWorld world;

  WorldScope({super.key, required this.world, required Widget child})
      : super(child: _providers(world, child));

  static Widget _providers(AppWorld world, Widget child) {
    final demo = world.demo;
    if (demo == null) return child;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<HabitProvider>.value(value: demo.habits),
        ChangeNotifierProvider<CategoryProvider>.value(value: demo.categories),
        ChangeNotifierProvider<SettingsProvider>.value(value: demo.settings),
        ChangeNotifierProvider<QuoteProvider>.value(value: demo.quotes),
      ],
      child: child,
    );
  }

  static AppWorld? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<WorldScope>()?.world;

  /// Whether [context] shows a tour's example habits (outside any scope:
  /// no).
  static bool isDemo(BuildContext context) =>
      context.getInheritedWidgetOfExactType<WorldScope>()?.world.isDemo ?? false;

  /// Where Health numbers come from: the phone's Health, or, with example
  /// habits, a Health that's never there (they never touch the real one).
  static HealthSource healthSourceOf(BuildContext context) =>
      isDemo(context) ? const NoHealthSource() : get<HealthSource>();

  @override
  bool updateShouldNotify(WorldScope oldWidget) => oldWidget.world != world;
}

/// The app's first page in the current world: the tabs, starting on the
/// world's tab, and in an example world quiet (no celebrations, and taps on
/// notifications or widgets left for the person's own app).
class WorldHome extends StatelessWidget {
  const WorldHome({super.key});

  @override
  Widget build(BuildContext context) {
    final world = WorldScope.maybeOf(context) ?? AppWorld.real();
    return _TourBack(
      child: IOSMainNavigation(
        key: ObjectKey(world),
        demo: world.isDemo,
        initialTab: world.initialTab,
        controller: world.nav,
      ),
    );
  }
}

/// Android's back during a tour: a step back, and on the first step, Skip.
class _TourBack extends StatefulWidget {
  final Widget child;
  const _TourBack({required this.child});

  @override
  State<_TourBack> createState() => _TourBackState();
}

class _TourBackState extends State<_TourBack> {
  TourController? _tours;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tours = TourController.maybeOf(context);
    if (tours != _tours) {
      _tours?.removeListener(_changed);
      _tours = tours?..addListener(_changed);
    }
  }

  @override
  void dispose() {
    _tours?.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tours = _tours;
    final running = tours?.isRunning ?? false;
    return PopScope(
      canPop: !running,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || tours == null || !tours.isRunning) return;
        tours.stepIndex == 0 ? tours.skip() : tours.back();
      },
      child: widget.child,
    );
  }
}

/// Health for the example habits: never available, and never asks the phone.
class NoHealthSource implements HealthSource {
  const NoHealthSource();

  @override
  String get name => get<HealthSource>().name;

  @override
  bool get isAndroid => get<HealthSource>().isAndroid;

  @override
  Future<HealthAvailability> availability() async => HealthAvailability.unsupported;

  @override
  Future<bool> requestAccess({required Set<HealthMetric> read, Set<HealthMetric> write = const {}}) async => false;

  @override
  Future<bool> ensureAccess({required Set<HealthMetric> read, Set<HealthMetric> write = const {}}) async => false;

  @override
  Future<void> installHealthConnect() async {}

  @override
  Future<Map<DateTime, int>> dailyValues(HealthMetric metric, DateTime from, DateTime to) async => const {};

  @override
  Future<HealthRecord?> log(HealthMetric metric, double baseAmount, DateTime at) async => null;

  @override
  Future<bool> remove(HealthRecord record) async => false;

  @override
  Future<bool> addSampleData() async => false;
}
