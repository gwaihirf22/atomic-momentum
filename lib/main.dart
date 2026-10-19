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
import 'presentation/providers/habit_provider.dart';
import 'presentation/providers/category_provider.dart';
import 'presentation/providers/quote_provider.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/tour/tour_bubble.dart';
import 'presentation/tour/world_scope.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize dependency injection
  await initializeDependencies();

  // Portrait only on phones (matches Info.plist)
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // The intro plays on a cold launch, unless a notification tap opened the
  // app (then it goes straight to the habit) or it's turned off in Settings
  final showIntro = IntroScreen.shouldPlay(
    fromNotification: NotificationService.focusRequests.value != null,
    enabled: get<SettingsProvider>().playIntro,
  );

  // Ask for notification permission once the app is on screen (after the
  // intro, so the system prompt doesn't cover it)
  void askPermission() {
    if (NotificationService.isSupported) NotificationService.requestPermission();
  }

  runApp(MomentumApp(showIntro: showIntro, onIntroDone: askPermission));
  if (!showIntro) WidgetsBinding.instance.addPostFrameCallback((_) => askPermission());
}

class MomentumApp extends StatelessWidget {
  /// The cold-launch intro (main turns it on; tests leave it off).
  final bool showIntro;
  final VoidCallback? onIntroDone;

  /// Switches between the person's habits and a tour's example world (tests
  /// pass their own, which builds the example habits in place).
  final WorldController? worlds;

  const MomentumApp({Key? key, this.showIntro = false, this.onIntroDone, this.worlds}) : super(key: key);

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
        // The person's own habits, or a tour's example world
        if (worlds case final worlds?)
          ChangeNotifierProvider<WorldController>.value(value: worlds)
        else
          ChangeNotifierProvider<WorldController>(create: (_) => WorldController()),
      ],
      // Above the app there's no MediaQuery yet; this one tracks the device's
      // light/dark setting so "System" follows it as it changes. The home
      // screen widgets follow the providers from here
      child: HomeWidgetHost(
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
                      child: Stack(children: [
                        Positioned.fill(
                          child: WorldScope(
                            world: world,
                            child: KeyedSubtree(key: ObjectKey(world), child: ScaffoldMessenger(child: child!)),
                          ),
                        ),
                        // Never mistaken for the person's own habits
                        if (world.isDemo)
                          Positioned(
                            top: MediaQuery.paddingOf(context).top + 4,
                            left: 0,
                            right: 0,
                            child: Center(child: ExampleHabitsPill(onDone: worlds.exitDemo)),
                          ),
                      ]),
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
    );
  }
}
