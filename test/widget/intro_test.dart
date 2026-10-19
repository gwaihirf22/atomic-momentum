import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/theme/app_palette.dart';
import 'package:atomic_momentum/core/theme/ios_theme.dart';
import 'package:atomic_momentum/main.dart';
import 'package:atomic_momentum/presentation/intro/intro_screen.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';

/// The cold-launch intro: Building, Rolling, Strong, Unstoppable, ATOMIC over
/// a MOMENTUM that holds still, then the mark, then the app.
void main() {
  Duration ms(int n) => Duration(milliseconds: n);
  Finder word(String level) => find.byKey(Key('introWord_$level'));
  final momentum = find.byKey(const Key('introMomentum'));
  final mark = find.byKey(const Key('introMark'));

  /// Plays [time] of intro frame by frame (the intro counts only frames it
  /// was drawn in, at most IntroScreen.maxStep each).
  Future<void> play(WidgetTester tester, Duration time) async {
    const frame = Duration(milliseconds: 16);
    for (var left = time; left > Duration.zero; left -= frame) {
      await tester.pump(left < frame ? left : frame);
    }
  }

  double opacityOf(WidgetTester tester, Finder finder) =>
      tester.widget<Opacity>(find.ancestor(of: finder, matching: find.byType(Opacity)).first).opacity;

  Future<void> pumpGate(WidgetTester tester,
      {VoidCallback? onDone,
      bool Function()? isReady,
      Widget app = const Text('the app'),
      bool reduceMotion = false,
      AppPalette palette = AppPalette.dark}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: IOSTheme.material(palette),
      home: MediaQuery(
        data: MediaQueryData(size: const Size(390, 844), disableAnimations: reduceMotion),
        child: IntroGate(enabled: true, onDone: onDone, isReady: isReady, child: Scaffold(body: Center(child: app))),
      ),
    ));
  }

  testWidgets('the levels climb over a MOMENTUM that stays put, to ATOMIC and the mark, then the app', (tester) async {
    var done = 0;
    await pumpGate(tester, onDone: () => done++);
    await play(tester, ms(150));
    final momentumAt = tester.getCenter(momentum);

    const turns = {150: 'building', 450: 'rolling', 750: 'strong', 1050: 'unstoppable'};
    var at = 150;
    for (final turn in turns.entries) {
      await play(tester, ms(turn.key - at));
      at = turn.key;
      expect(word(turn.value), findsOneWidget, reason: '${turn.value} at ${turn.key} ms');
      for (final other in turns.values.where((w) => w != turn.value)) {
        expect(word(other), findsNothing, reason: 'only ${turn.value} at ${turn.key} ms');
      }
      expect(tester.getCenter(momentum), momentumAt, reason: 'MOMENTUM holds still');
      expect(opacityOf(tester, mark), 0, reason: 'no mark yet');
    }

    await play(tester, ms(1400 - at));
    expect(word('atomic'), findsOneWidget);
    expect(find.text('ATOMIC'), findsOneWidget);
    expect(tester.getCenter(momentum), momentumAt);

    await play(tester, ms(600));
    expect(opacityOf(tester, mark), 1, reason: 'the mark has risen by 2 s');
    expect(word('atomic'), findsOneWidget, reason: '"Atomic Momentum" under the mark');
    expect(done, 0);

    await play(tester, ms(500));
    await tester.pump();
    expect(find.byKey(const Key('intro')), findsNothing);
    expect(find.text('the app'), findsOneWidget);
    expect(done, 1);
  });

  testWidgets('a stalled start pauses the intro instead of running it out unseen', (tester) async {
    var done = 0;
    await pumpGate(tester, onDone: () => done++);
    await play(tester, ms(150));
    // A busy first launch: three seconds without a frame
    await tester.pump(const Duration(seconds: 3));
    expect(done, 0);
    expect(find.byKey(const Key('intro')), findsOneWidget);
    expect(word('building'), findsOneWidget, reason: 'it carries on where it was');
    await play(tester, IntroScreen.duration);
    await tester.pump();
    expect(done, 1);
  });

  group('waiting for the app', () {
    testWidgets('holds on "Atomic Momentum" until the habits are loaded, then fades', (tester) async {
      var done = 0;
      var ready = false;
      await pumpGate(tester, onDone: () => done++, isReady: () => ready);
      await play(tester, IntroScreen.duration + ms(1500));
      expect(done, 0);
      expect(opacityOf(tester, mark), 1, reason: 'the final frame, in full');
      expect(
          tester
              .widget<Opacity>(
                  find.descendant(of: find.byKey(const Key('intro')), matching: find.byType(Opacity)).first)
              .opacity,
          1,
          reason: 'not fading yet');
      ready = true;
      await play(tester, ms(400));
      await tester.pump();
      expect(done, 1);
      expect(find.byKey(const Key('intro')), findsNothing);
    });

    testWidgets('gives up after IntroScreen.maxHold', (tester) async {
      var done = 0;
      await pumpGate(tester, onDone: () => done++, isReady: () => false);
      await play(tester, IntroScreen.duration + IntroScreen.maxHold + ms(100));
      await tester.pump();
      expect(done, 1);
    });

    testWidgets("doesn't wait when the app is ready in time", (tester) async {
      var done = 0;
      await pumpGate(tester, onDone: () => done++, isReady: () => true);
      await play(tester, IntroScreen.duration + ms(50));
      await tester.pump();
      expect(done, 1);
    });

    testWidgets("a tap doesn't wait for the app", (tester) async {
      var done = 0;
      await pumpGate(tester, onDone: () => done++, isReady: () => false);
      await play(tester, ms(300));
      await tester.tap(find.byKey(const Key('intro')));
      await play(tester, ms(400));
      await tester.pump();
      expect(done, 1);
    });
  });

  testWidgets('a tap skips to the end', (tester) async {
    var done = 0;
    await pumpGate(tester, onDone: () => done++);
    await play(tester, ms(300));
    await tester.tap(find.byKey(const Key('intro')));
    await play(tester, ms(350));
    await tester.pump();
    expect(find.byKey(const Key('intro')), findsNothing);
    expect(done, 1);
  });

  testWidgets('with Reduce Motion, only the final frame, briefly', (tester) async {
    var done = 0;
    await pumpGate(tester, onDone: () => done++, reduceMotion: true);
    await play(tester, ms(100));
    expect(word('atomic'), findsOneWidget);
    expect(word('building'), findsNothing);
    expect(opacityOf(tester, mark), 1);
    await play(tester, ms(800));
    await tester.pump();
    expect(find.byKey(const Key('intro')), findsNothing);
    expect(done, 1);
  });

  testWidgets('the app underneath keeps its state when the intro goes', (tester) async {
    final key = GlobalKey<_CounterState>();
    await pumpGate(tester, app: _Counter(key: key));
    final before = key.currentState;
    expect(before, isNotNull);
    await play(tester, IntroScreen.duration + ms(50));
    await tester.pump();
    expect(find.byKey(const Key('intro')), findsNothing);
    expect(key.currentState, same(before));
  });

  testWidgets('VoiceOver hears "Momentum", not the app behind it', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpGate(tester);
    await play(tester, ms(500));
    expect(find.bySemanticsLabel('Momentum'), findsOneWidget);
    expect(find.bySemanticsLabel('the app'), findsNothing);
    await play(tester, IntroScreen.duration);
    await tester.pump();
    expect(find.byKey(const Key('intro')), findsNothing);
    expect(find.bySemanticsLabel('the app'), findsOneWidget);
    semantics.dispose();
  });

  for (final palette in [AppPalette.dark, AppPalette.light, AppPalette.sepia]) {
    testWidgets('draws in ${palette.theme.name}', (tester) async {
      await pumpGate(tester, palette: palette);
      var at = 0;
      for (final t in [150, 1050, 1300, 1900]) {
        await play(tester, ms(t - at));
        at = t;
        expect(tester.takeException(), isNull, reason: 'at $t ms');
      }
      final background = tester.widget<ColoredBox>(
          find.descendant(of: find.byKey(const Key('intro')), matching: find.byType(ColoredBox)).first);
      expect(background.color, palette.background);
      await play(tester, IntroScreen.duration);
      await tester.pump();
    });
  }

  group('the app', () {
    setUp(() async {
      await resetDependencies();
      SharedPreferences.setMockInitialValues({});
      await initializeDependencies(seedDefaultHabit: false);
    });

    tearDown(resetDependencies);

    testWidgets('plays the intro when launched with it, then shows Habits and runs onIntroDone', (tester) async {
      var done = 0;
      await tester.pumpWidget(MomentumApp(showIntro: true, onIntroDone: () => done++));
      await play(tester, ms(500));
      expect(find.byKey(const Key('intro')), findsOneWidget);
      expect(done, 0, reason: 'notification permission waits for the intro');
      await play(tester, IntroScreen.duration);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('intro')), findsNothing);
      expect(find.byKey(const Key('habitsGreeting')).hitTestable(), findsOneWidget);
      expect(done, 1);
    });

    test('a cold launch plays it unless a notification opened the app or it is turned off', () {
      expect(IntroScreen.shouldPlay(fromNotification: false, enabled: true), isTrue);
      expect(IntroScreen.shouldPlay(fromNotification: true, enabled: true), isFalse);
      expect(IntroScreen.shouldPlay(fromNotification: false, enabled: false), isFalse);
      expect(IntroScreen.shouldPlay(fromNotification: true, enabled: false), isFalse);
    });

    testWidgets('Settings → Display → Launch intro turns it off for the next launch', (tester) async {
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MomentumApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tab_settings')));
      await tester.pumpAndSettle();
      final settings = get<SettingsProvider>();
      expect(settings.playIntro, isTrue);
      await tester.tap(find.byKey(const Key('introSwitch')));
      await tester.pumpAndSettle();
      expect(settings.playIntro, isFalse);
      expect(IntroScreen.shouldPlay(fromNotification: false, enabled: settings.playIntro), isFalse);
    });

    testWidgets('has no intro unless asked (tests, and launches from a notification)', (tester) async {
      await tester.pumpWidget(const MomentumApp());
      await tester.pump();
      expect(find.byKey(const Key('intro')), findsNothing);
      expect(find.byKey(const Key('habitsGreeting')).hitTestable(), findsOneWidget);
    });
  });
}

class _Counter extends StatefulWidget {
  const _Counter({super.key});

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  @override
  Widget build(BuildContext context) => const Text('the app');
}
