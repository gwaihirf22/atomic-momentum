import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/theme/app_palette.dart';
import 'package:atomic_momentum/core/theme/ios_theme.dart';
import 'package:atomic_momentum/main.dart';
import 'package:atomic_momentum/presentation/intro/intro_screen.dart';

/// The cold-launch intro: Building, Rolling, Strong, Unstoppable, ATOMIC over
/// a MOMENTUM that holds still, then the mark, then the app.
void main() {
  Duration ms(int n) => Duration(milliseconds: n);
  Finder word(String level) => find.byKey(Key('introWord_$level'));
  final momentum = find.byKey(const Key('introMomentum'));
  final mark = find.byKey(const Key('introMark'));

  double opacityOf(WidgetTester tester, Finder finder) =>
      tester.widget<Opacity>(find.ancestor(of: finder, matching: find.byType(Opacity)).first).opacity;

  Future<void> pumpGate(WidgetTester tester,
      {VoidCallback? onDone, Widget app = const Text('the app'), bool reduceMotion = false, AppPalette palette = AppPalette.dark}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: IOSTheme.material(palette),
      home: MediaQuery(
        data: MediaQueryData(size: const Size(390, 844), disableAnimations: reduceMotion),
        child: IntroGate(enabled: true, onDone: onDone, child: Scaffold(body: Center(child: app))),
      ),
    ));
  }

  testWidgets('the levels climb over a MOMENTUM that stays put, to ATOMIC and the mark, then the app', (tester) async {
    var done = 0;
    await pumpGate(tester, onDone: () => done++);
    await tester.pump(ms(150));
    final momentumAt = tester.getCenter(momentum);

    const turns = {150: 'building', 450: 'rolling', 750: 'strong', 1050: 'unstoppable'};
    var at = 150;
    for (final turn in turns.entries) {
      await tester.pump(ms(turn.key - at));
      at = turn.key;
      expect(word(turn.value), findsOneWidget, reason: '${turn.value} at ${turn.key} ms');
      for (final other in turns.values.where((w) => w != turn.value)) {
        expect(word(other), findsNothing, reason: 'only ${turn.value} at ${turn.key} ms');
      }
      expect(tester.getCenter(momentum), momentumAt, reason: 'MOMENTUM holds still');
      expect(opacityOf(tester, mark), 0, reason: 'no mark yet');
    }

    await tester.pump(ms(1400 - at));
    expect(word('atomic'), findsOneWidget);
    expect(find.text('ATOMIC'), findsOneWidget);
    expect(tester.getCenter(momentum), momentumAt);

    await tester.pump(ms(600));
    expect(opacityOf(tester, mark), 1, reason: 'the mark has risen by 2 s');
    expect(word('atomic'), findsOneWidget, reason: '"Atomic Momentum" under the mark');
    expect(done, 0);

    await tester.pump(ms(500));
    await tester.pump();
    expect(find.byKey(const Key('intro')), findsNothing);
    expect(find.text('the app'), findsOneWidget);
    expect(done, 1);
  });

  testWidgets('a tap skips to the end', (tester) async {
    var done = 0;
    await pumpGate(tester, onDone: () => done++);
    await tester.pump(ms(300));
    await tester.tap(find.byKey(const Key('intro')));
    await tester.pump(ms(350));
    await tester.pump();
    expect(find.byKey(const Key('intro')), findsNothing);
    expect(done, 1);
  });

  testWidgets('with Reduce Motion, only the final frame, briefly', (tester) async {
    var done = 0;
    await pumpGate(tester, onDone: () => done++, reduceMotion: true);
    await tester.pump(ms(100));
    expect(word('atomic'), findsOneWidget);
    expect(word('building'), findsNothing);
    expect(opacityOf(tester, mark), 1);
    await tester.pump(ms(800));
    await tester.pump();
    expect(find.byKey(const Key('intro')), findsNothing);
    expect(done, 1);
  });

  testWidgets('the app underneath keeps its state when the intro goes', (tester) async {
    final key = GlobalKey<_CounterState>();
    await pumpGate(tester, app: _Counter(key: key));
    final before = key.currentState;
    expect(before, isNotNull);
    await tester.pump(IntroScreen.duration + ms(50));
    await tester.pump();
    expect(find.byKey(const Key('intro')), findsNothing);
    expect(key.currentState, same(before));
  });

  testWidgets('VoiceOver hears "Momentum", not the app behind it', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpGate(tester);
    await tester.pump(ms(500));
    expect(find.bySemanticsLabel('Momentum'), findsOneWidget);
    expect(find.bySemanticsLabel('the app'), findsNothing);
    await tester.pump(IntroScreen.duration);
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
        await tester.pump(ms(t - at));
        at = t;
        expect(tester.takeException(), isNull, reason: 'at $t ms');
      }
      final background = tester.widget<ColoredBox>(
          find.descendant(of: find.byKey(const Key('intro')), matching: find.byType(ColoredBox)).first);
      expect(background.color, palette.background);
      await tester.pump(IntroScreen.duration);
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
      await tester.pump(ms(500));
      expect(find.byKey(const Key('intro')), findsOneWidget);
      expect(done, 0, reason: 'notification permission waits for the intro');
      await tester.pump(IntroScreen.duration);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('intro')), findsNothing);
      expect(find.byKey(const Key('habitsGreeting')).hitTestable(), findsOneWidget);
      expect(done, 1);
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
