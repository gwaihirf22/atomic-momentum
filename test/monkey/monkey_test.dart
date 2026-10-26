import 'dart:io';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/demo/demo_world.dart';
import 'package:atomic_momentum/core/dev/year_of_use.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/achievement_store.dart';
import 'package:atomic_momentum/core/services/home_widget_bridge.dart';
import 'package:atomic_momentum/core/services/notification_service.dart';
import 'package:atomic_momentum/data/datasources/shared_preferences_datasource.dart';
import 'package:atomic_momentum/main.dart';
import 'package:atomic_momentum/presentation/tour/tour.dart';
import 'package:atomic_momentum/presentation/tour/tour_controller.dart';
import 'package:atomic_momentum/presentation/tour/world_scope.dart';

import '../helpers/fake_app_icon_service.dart';
import '../helpers/fake_health_source.dart';
import '../helpers/fake_home_widget_bridge.dart';
import '../helpers/fake_notifications_plugin.dart';
import '../helpers/fake_sharer.dart';
import '../helpers/fake_support_link.dart';
import '../helpers/fake_web_pages.dart';
import '../helpers/real_fonts.dart';

/// A monkey loose in the app: a year of use, then thousands of random taps,
/// holds, swipes, scrolls, typing and backs, anywhere. Any exception,
/// failed assertion or overflow fails it, with the seed, the step and the
/// last actions, so it can be replayed exactly.
///
/// The suite runs a short walk at two sizes; longer ones with other seeds:
///   tool/monkey.sh [steps] [first seed] [seeds]
const _steps = int.fromEnvironment('MONKEY_STEPS', defaultValue: 300);
const _seed = int.fromEnvironment('MONKEY_SEED', defaultValue: 1);

/// Prints where the monkey went (screens seen, things touched) at the end.
const _verbose = bool.fromEnvironment('MONKEY_VERBOSE');

void main() {
  setUpAll(loadRealFonts);

  late WorldController worlds;

  setUp(() async {
    await resetDependencies();
    final now = clock.now();
    // A year of use, as Settings → Developer → "Load a year of use" builds it
    final year = YearOfUse.stored(YearOfUse.personaEnding(now), now);
    SharedPreferences.setMockInitialValues({
      SharedPreferencesDataSource.habitsKey: year.habits,
      AchievementStore.key: year.seen,
      // Tours seen: they'd only dim the screen around their Next
      TourStore.key: [for (final id in TourId.values) id.name],
    });
    NotificationService.debugOverride(plugin: FakeNotificationsPlugin());
    await initializeDependencies(seedDefaultHabit: false);
    FakeHealthSource.install();
    FakeSharer.install();
    FakeSupportLink.install();
    FakeWebPages.install();
    FakeAppIconService.install();
    sl.unregister<HomeWidgetBridge>();
    sl.registerSingleton<HomeWidgetBridge>(FakeHomeWidgetBridge());
    // The example habits built at once, not in an isolate (a test's clock)
    worlds = WorldController(seed: (now) async => DemoSeed.build(now));
  });

  tearDown(() async {
    NotificationService.debugReset();
    await resetDependencies();
  });

  for (final (name, size, scale) in const [
    ('6.1-inch iPhone, standard text', Size(390, 844), 1.0),
    ('iPhone SE, 135% text', Size(375, 667), 1.35),
    // iPads: the sidebar, and sideways a habit beside its list
    ('11-inch iPad sideways', Size(1194, 834), 1.0),
    ('11-inch iPad upright, 135% text', Size(834, 1194), 1.35),
  ]) {
    testWidgets('$_steps random steps on a $name (seed $_seed)', timeout: const Timeout(Duration(minutes: 30)),
        (tester) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      // A report left by an earlier run would be mistaken for this one's
      final report = File('build/monkey_report.txt');
      if (report.existsSync()) report.deleteSync();
      await tester.pumpWidget(MomentumApp(worlds: worlds));
      await _settle(tester);
      final monkey = _Monkey(tester, Random(_seed + (scale == 1.0 ? 0 : 1000) + (size.width > 600 ? 500 : 0)), size);
      for (var step = 1; step <= _steps; step++) {
        await monkey.step();
        final error = tester.takeException();
        if (error != null) {
          final text = monkey.report(step, error);
          report
            ..createSync(recursive: true)
            ..writeAsStringSync(text);
          fail(text);
        }
      }
      if (_verbose) {
        // ignore: avoid_print
        print('MONKEY ${monkey.screens.length} screens: ${monkey.screens.join(', ')}');
        // ignore: avoid_print
        print('MONKEY ${monkey.log.toSet().length} different actions of ${monkey.log.length}');
      }
      // Leave nothing running
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}

/// A few frames: enough for taps, sheets and page slides to land, without
/// waiting on anything that animates for good.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

class _Monkey {
  final WidgetTester tester;
  final Random random;
  final Size size;
  final log = <String>[];

  /// The pages and sheets seen on top (by their widget's type).
  final screens = <String>{};

  /// How often each thing has been touched: new things are picked first,
  /// so the walk goes deep instead of tapping the tab bar all day.
  final _touched = <String, int>{};

  /// One of [targets], the less touched the likelier.
  Element _pick(List<Element> targets) {
    final weights = [for (final t in targets) 1 / (1 + 2 * (_touched[_describe(t)] ?? 0))];
    var roll = random.nextDouble() * weights.fold(0.0, (a, b) => a + b);
    for (var i = 0; i < targets.length; i++) {
      roll -= weights[i];
      if (roll <= 0) return targets[i];
    }
    return targets.last;
  }

  void _note(Element target) => _touched.update(_describe(target), (n) => n + 1, ifAbsent: () => 1);

  _Monkey(this.tester, this.random, this.size);

  static const _texts = [
    '',
    'a',
    'Read',
    '0',
    '12',
    '99999',
    '-3',
    '1.5',
    'Drink water every single morning before coffee and breakfast',
    '😀🔥 emoji',
    '   ',
    'Ünïcödé ñ',
  ];

  /// Something that answers a tap or a hold, on screen and on top.
  List<Element> _targets() => find
      .byWidgetPredicate((w) =>
          (w is GestureDetector && (w.onTap != null || w.onLongPress != null)) ||
          (w is InkWell && (w.onTap != null || w.onLongPress != null)) ||
          (w is CupertinoButton && w.onPressed != null) ||
          (w is ButtonStyleButton && w.onPressed != null) ||
          (w is IconButton && w.onPressed != null) ||
          (w is Switch && w.onChanged != null) ||
          (w is CupertinoSwitch && w.onChanged != null) ||
          (w is ListTile && w.onTap != null) ||
          (w is CupertinoListTile && w.onTap != null))
      .hitTestable()
      .evaluate()
      .toList();

  String _describe(Element e) {
    final key = e.widget.key;
    final texts = find
        .descendant(of: find.byElementPredicate((x) => x == e), matching: find.byType(Text))
        .evaluate()
        .map((t) => (t.widget as Text).data)
        .whereType<String>()
        .take(2)
        .join(' / ');
    return '${e.widget.runtimeType}${key == null ? '' : ' $key'}${texts.isEmpty ? '' : ' "$texts"'}';
  }

  Offset _centerOf(Element e) {
    final box = e.renderObject! as RenderBox;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  Offset _anywhere() => Offset(random.nextDouble() * size.width, 60 + random.nextDouble() * (size.height - 120));

  Future<void> step() async {
    final roll = random.nextDouble();
    final targets = _targets();
    if (roll < 0.5 && targets.isNotEmpty) {
      final target = _pick(targets);
      _note(target);
      log.add('tap ${_describe(target)}');
      await tester.tapAt(_centerOf(target));
    } else if (roll < 0.58 && targets.isNotEmpty) {
      final target = _pick(targets);
      _note(target);
      log.add('hold ${_describe(target)}');
      await tester.longPressAt(_centerOf(target));
    } else if (roll < 0.66) {
      final from = targets.isNotEmpty && random.nextBool() ? _centerOf(targets[random.nextInt(targets.length)]) : _anywhere();
      final dx = (random.nextBool() ? 1 : -1) * (80 + random.nextDouble() * 220);
      log.add('swipe ${dx.round()} from ${from.dx.round()},${from.dy.round()}');
      await tester.dragFrom(from, Offset(dx, 0));
    } else if (roll < 0.78) {
      final dy = (random.nextBool() ? 1 : -1) * (100 + random.nextDouble() * 400);
      log.add('scroll ${dy.round()}');
      await tester.dragFrom(Offset(size.width / 2, size.height / 2), Offset(0, dy));
    } else if (roll < 0.84) {
      final fields = find.byType(EditableText).hitTestable().evaluate().toList();
      if (fields.isEmpty) {
        log.add('(no field to type in)');
      } else {
        final text = _texts[random.nextInt(_texts.length)];
        log.add('type "$text"');
        // As a person would: tap the field, then the keyboard types
        await tester.tapAt(_centerOf(fields[random.nextInt(fields.length)]));
        await tester.pump();
        if (tester.testTextInput.isVisible) tester.testTextInput.enterText(text);
      }
    } else if (roll < 0.92) {
      log.add('back');
      await tester.binding.handlePopRoute();
    } else {
      final at = _anywhere();
      log.add('tap at ${at.dx.round()},${at.dy.round()}');
      await tester.tapAt(at);
    }
    await _settle(tester);
    for (final route in find.byWidgetPredicate((w) => w.runtimeType.toString().endsWith('Screen') || w.runtimeType.toString().endsWith('Sheet')).hitTestable().evaluate()) {
      screens.add(route.widget.runtimeType.toString());
    }
  }

  String report(int step, Object error) => [
        'Monkey failed at step $step (MONKEY_SEED=$_seed, ${size.width.round()}pt): $error',
        'Last actions:',
        for (final line in log.reversed.take(25).toList().reversed) '  $line',
      ].join('\n');
}
