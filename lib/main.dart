import 'core/demo/demo_world.dart';
import 'package:clock/clock.dart';
import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/injection/injection_container.dart';
import 'core/services/notification_service.dart';
import 'core/theme/ios_theme.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/intro/intro_screen.dart';
import 'presentation/home_widgets/home_widget_host.dart';
import 'presentation/sync/sync_host.dart';
import 'presentation/layout/app_layout.dart';
import 'presentation/providers/habit_provider.dart';
import 'presentation/providers/category_provider.dart';
import 'presentation/providers/quote_provider.dart';
import 'presentation/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'presentation/tour/tour.dart';
import 'presentation/tour/tour_anchor.dart';
import 'presentation/tour/tour_bubble.dart';
import 'presentation/tour/tour_controller.dart';
import 'presentation/tour/tour_layer.dart';
import 'presentation/tour/tours.dart';
import 'presentation/tour/world_scope.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize dependency injection
  await initializeDependencies();

  await DeviceKind.load();
  // Portrait only on phones (matches Info.plist); iPads and tablets turn
  // any way (Info.plist's ~ipad list), and the layout follows the window
  if (!isTabletScreen()) SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // The intro plays on a cold launch, unless a notification tap opened the
  // app (then it goes straight to the habit) or it's turned off in Settings
  final showIntro = IntroScreen.shouldPlay(
    fromNotification: NotificationService.focusRequests.value != null,
    enabled: get<SettingsProvider>().playIntro,
  );

  // Ask for notification permission once the app is on screen (after the
  // intro, so the system prompt doesn't cover it; on a first launch, after
  // the first tour)
  void askPermission() {
    if (NotificationService.isSupported) NotificationService.requestPermission();
  }

  // Tours: a new install takes the Habits tour (its example habits built
  // while the intro plays); someone who had habits before tours is offered it
  final prefs = get<SharedPreferences>();
  final tourStart = await TourStart.forLaunch(prefs, fromNotification: NotificationService.focusRequests.value != null);
  if (tourStart == TourStart.firstRun) {
    unawaited(DemoSeed.forDay(clock.now()));
  } else if (TourStore(prefs).seen.length < Tours.all.length) {
    // A tour still to come on a tab: its example habits ready ahead of it
    Timer(const Duration(seconds: 3), () => DemoSeed.forDay(clock.now()));
  }

  runApp(MomentumApp(
    showIntro: showIntro,
    onIntroDone: tourStart == TourStart.firstRun ? null : askPermission,
    tourStart: tourStart,
    onFirstTourDone: askPermission,
  ));
  if (!showIntro && tourStart != TourStart.firstRun) {
    WidgetsBinding.instance.addPostFrameCallback((_) => askPermission());
  }
}

/// Whether the device is a tablet, before any widget has a window to
/// measure: as iOS says (an iPad; never the iPhone Duo, however big it
/// unfolds), else from the screen ([AppLayout.tabletFrom]).
bool isTabletScreen() {
  final known = DeviceKind.tablet;
  if (known != null) return known;
  final views = PlatformDispatcher.instance.views;
  if (views.isEmpty) return false;
  final display = views.first.display;
  return display.size.shortestSide / display.devicePixelRatio >= AppLayout.tabletFrom;
}

class MomentumApp extends StatefulWidget {
  /// The cold-launch intro (main turns it on; tests leave it off).
  final bool showIntro;
  final VoidCallback? onIntroDone;

  /// Switches between the person's habits and a tour's example world (tests
  /// pass their own, which builds the example habits in place).
  final WorldController? worlds;

  /// The tours (tests pass their own).
  final Map<TourId, Tour>? tours;

  /// Whether this launch begins with the Habits tour, or offers it.
  final TourStart tourStart;

  /// The first launch's tour ended (finished or skipped).
  final VoidCallback? onFirstTourDone;

  const MomentumApp({
    Key? key,
    this.showIntro = false,
    this.onIntroDone,
    this.worlds,
    this.tours,
    this.tourStart = TourStart.none,
    this.onFirstTourDone,
  }) : super(key: key);

  @override
  State<MomentumApp> createState() => _MomentumAppState();
}

class _MomentumAppState extends State<MomentumApp> {
  late final WorldController _worlds = widget.worlds ?? WorldController();

  /// Where whatever a tour can point at registers.
  final _anchors = TourAnchors();

  late final TourController _tours = TourController(
    worlds: _worlds,
    tours: widget.tours ?? Tours.all,
    anchors: _anchors,
    store: sl.isRegistered<SharedPreferences>() ? TourStore(get<SharedPreferences>()) : null,
  );

  @override
  void initState() {
    super.initState();
    switch (widget.tourStart) {
      case TourStart.firstRun:
        // Starts under the intro, so the example habits are there as it fades
        _tours.onEnd = (id, {required finished}) {
          if (id != TourId.habits) return;
          _tours.onEnd = null;
          widget.onFirstTourDone?.call();
        };
        WidgetsBinding.instance.addPostFrameCallback((_) => _tours.start(TourId.habits));
      case TourStart.offer:
        WidgetsBinding.instance.addPostFrameCallback((_) => _tours.offer());
      case TourStart.none:
        break;
    }
  }

  @override
  void dispose() {
    _tours.dispose();
    if (widget.worlds == null) _worlds.dispose();
    super.dispose();
  }

  bool get showIntro => widget.showIntro;
  VoidCallback? get onIntroDone => widget.onIntroDone;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => get<ThemeProvider>(),
        ),
        ChangeNotifierProvider<HabitProvider>(
          create: (_) => get<HabitProvider>(),
        ),
        // Shared singleton (category edits must reach every screen), so not owned here
        ChangeNotifierProvider<CategoryProvider>.value(
          value: get<CategoryProvider>(),
        ),
        // Shared singleton (the streak warning service reads it), so not owned here
        ChangeNotifierProvider<SettingsProvider>.value(
          value: get<SettingsProvider>(),
        ),
        // Shared singleton (loaded with the app's dependencies), so not owned here
        ChangeNotifierProvider<QuoteProvider>.value(
          value: get<QuoteProvider>(),
        ),
        // The person's own habits, or a tour's example world, and the tours
        ChangeNotifierProvider<WorldController>.value(value: _worlds),
        ChangeNotifierProvider<TourController>.value(value: _tours),
      ],
      // Above the app there's no MediaQuery yet; this one tracks the device's
      // light/dark setting so "System" follows it as it changes. The home
      // screen widgets and sync follow the providers from here
      child: HomeWidgetHost(
        child: SyncHost(
          child: MediaQuery.fromView(
            view: View.of(context),
            child: Consumer2<ThemeProvider, WorldController>(
              builder: (context, themeProvider, worlds, child) {
                final palette = themeProvider.paletteIn(context);
                final world = worlds.world;

                return CupertinoApp(
                  title: 'Atomic Momentum',
                  debugShowCheckedModeBanner: false,
                  theme: IOSTheme.cupertino(palette),
                  // A world of its own: switching remounts everything below,
                  // the editor and sheets on the root navigator included
                  navigatorKey: world.navigatorKey,
                  navigatorObservers: [_snackBarsAway[world] ??= _SnackBarsAway()],
                  home: const WorldHome(),
                  // Screens built from Material widgets read Theme.of(context), which
                  // CupertinoApp doesn't provide; it also carries the palette
                  // (AppPalette.of) every widget draws with
                  // ScaffoldMessenger: CupertinoApp doesn't provide one, and without
                  // it no SnackBar can show
                  builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
                    // Status bar icons that show on the theme's background (Android
                    // takes this; iOS follows the navigation bars too)
                    value: (palette.brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
                        .copyWith(statusBarColor: Colors.transparent),
                    child: Theme(
                      data: IOSTheme.material(palette),
                      child: IntroGate(
                        enabled: showIntro,
                        onDone: onIntroDone,
                        // Fades into Habits once they've loaded (a long history takes a moment)
                        isReady: () => context.read<HabitProvider>().state.index >= HabitProviderState.loaded.index,
                        // The world's providers around the root navigator, so
                        // whatever opens on it sees the same habits
                        child: TourAnchorScope(
                          anchors: _anchors,
                          child: Stack(children: [
                            Positioned.fill(
                              child: WorldScope(
                                world: world,
                                child: KeyedSubtree(key: ObjectKey(world), child: ScaffoldMessenger(child: child!)),
                              ),
                            ),
                            // A tour, over everything
                            const Positioned.fill(child: TourLayer()),
                            // Never mistaken for the person's own habits (a tour
                            // leaves them with its Skip)
                            if (world.isDemo)
                              Positioned(
                                top: MediaQuery.paddingOf(context).top + 4,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: ExampleHabitsPill(onDone: _tours.isRunning ? null : worlds.exitDemo),
                                ),
                              ),
                          ]),
                        ),
                      ),
                    ),
                  ),
                  localizationsDelegates: const [
                    GlobalMaterialLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// One per world: each has its own root navigator, and an observer belongs
/// to one navigator at a time.
final _snackBarsAway = Expando<_SnackBarsAway>('snack bars away');

/// A page opening over the whole app (the editor) clears the SnackBars
/// first. Flutter shows a SnackBar on every tab's page, and two
/// alike in the app below stop a page's animation ("multiple heroes share
/// the same tag"; found by the monkey test).
class _SnackBarsAway extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final context = navigator?.context;
    // Only pages animate heroes: a sheet or alert keeps the message up
    if (previousRoute == null || context == null || route is! PageRoute) return;
    // At once: one sliding out would still be there as the page opens
    ScaffoldMessenger.maybeOf(context)
      ?..clearSnackBars()
      ..removeCurrentSnackBar();
  }
}
