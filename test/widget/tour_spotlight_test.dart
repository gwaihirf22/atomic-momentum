import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/core/theme/app_palette.dart';
import 'package:atomic_momentum/core/theme/ios_theme.dart';
import 'package:atomic_momentum/presentation/tour/spotlight.dart';
import 'package:atomic_momentum/presentation/tour/tour_bubble.dart';

import '../helpers/real_fonts.dart';

void main() {
  setUpAll(loadRealFonts);

  const phone = Size(375, 667);
  const safe = EdgeInsets.only(top: 20, bottom: 0);
  const tabBar = 90.0;

  Future<void> pump(
    WidgetTester tester, {
    Rect? target,
    BubbleSide side = BubbleSide.auto,
    bool tryIt = false,
    bool passThrough = false,
    VoidCallback? onTapHole,
    VoidCallback? onApp,
    double scale = 1,
    bool reduceMotion = false,
    String text = 'This is your momentum: how steadily you have been showing up.',
    AppPalette palette = AppPalette.sepia,
    Size screen = phone,
    double covered = tabBar,
  }) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: IOSTheme.material(palette),
      home: MediaQuery(
        data: MediaQueryData(
          size: screen,
          padding: safe,
          textScaler: TextScaler.linear(scale * sfWidthAllowance),
          disableAnimations: reduceMotion,
        ),
        child: Stack(children: [
          // The app underneath: one big button
          Positioned.fill(
            child: GestureDetector(
              key: const Key('app'),
              behavior: HitTestBehavior.opaque,
              onTap: onApp,
            ),
          ),
          Positioned.fill(
            child: TourSpotlight(
              target: target,
              side: side,
              tryIt: tryIt,
              passThrough: passThrough,
              onTapHole: onTapHole,
              bottomCovered: covered,
              bubble: TourBubble(eyebrow: 'Habits', text: text, step: 1, steps: 4, tryIt: tryIt, onNext: () {}, onSkip: () {}),
            ),
          ),
        ]),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
  }

  RenderCallout callout(WidgetTester tester) =>
      tester.renderObject(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_Callout'));

  group('where the bubble goes', () {
    test('the hole is the target with room around it', () {
      final hole = TourSpotlight.holeFor(const Rect.fromLTWH(100, 100, 50, 40));
      expect(hole.outerRect, const Rect.fromLTRB(94, 94, 156, 146));
    });

    testWidgets('below a target near the top, arrow pointing up at it', (tester) async {
      const target = Rect.fromLTWH(140, 80, 96, 96);
      await pump(tester, target: target);
      final c = callout(tester);
      final hole = TourSpotlight.holeFor(target).outerRect;
      expect(c.bubbleRect.top, greaterThan(hole.bottom));
      expect(c.arrowUp, isTrue);
      expect(c.arrowAt!.dy, closeTo(hole.bottom + TourSpotlight.gap, 0.01));
      // The arrow sits under the target's middle
      expect(c.arrowAt!.dx + RenderCallout.arrowSize.width / 2, closeTo(target.center.dx, 0.01));
    });

    testWidgets('above a target near the bottom, never under the tab bar', (tester) async {
      const target = Rect.fromLTWH(20, 480, 335, 80);
      await pump(tester, target: target);
      final c = callout(tester);
      expect(c.bubbleRect.bottom, lessThan(TourSpotlight.holeFor(target).outerRect.top));
      expect(c.arrowUp, isFalse);
      expect(c.bubbleRect.bottom, lessThanOrEqualTo(phone.height - tabBar));
    });

    testWidgets('flips to the other side when the asked-for side has no room', (tester) async {
      const target = Rect.fromLTWH(20, 60, 335, 60);
      await pump(tester, target: target, side: BubbleSide.above);
      expect(callout(tester).bubbleRect.top, greaterThan(TourSpotlight.holeFor(target).outerRect.bottom));
    });

    testWidgets('the arrow stays clear of the bubble corners for a target at the edge', (tester) async {
      const target = Rect.fromLTWH(330, 100, 40, 40);
      await pump(tester, target: target);
      final c = callout(tester);
      expect(c.arrowAt!.dx, lessThanOrEqualTo(c.bubbleRect.right - 18 - RenderCallout.arrowSize.width));
      expect(c.bubbleRect.right, lessThanOrEqualTo(phone.width - RenderCallout.margin));
    });

    testWidgets('beside a tall target with room at its side (the iPad\'s sidebar), arrow pointing across',
        (tester) async {
      const ipad = Size(1194, 834);
      const sidebar = Rect.fromLTWH(12, 100, 240, 640);
      await pump(tester, target: sidebar, side: BubbleSide.above, screen: ipad, covered: 0);
      final c = callout(tester);
      final hole = TourSpotlight.holeFor(sidebar).outerRect;
      expect(c.arrowSideways, isTrue);
      expect(c.arrowLeft, isTrue);
      expect(c.bubbleRect.left, greaterThan(hole.right));
      expect(c.arrowAt!.dx, closeTo(hole.right + TourSpotlight.gap, 0.01));
      // Level with the target's middle
      expect(c.bubbleRect.center.dy, closeTo(sidebar.center.dy, 1));

      // A tall target on the right: the bubble to its left, arrow pointing right
      const right = Rect.fromLTWH(900, 100, 280, 640);
      await pump(tester, target: right, screen: ipad, covered: 0);
      expect(callout(tester).arrowLeft, isFalse);
      expect(callout(tester).bubbleRect.right, lessThan(TourSpotlight.holeFor(right).outerRect.left));
    });

    testWidgets('no target, or no room either side: in the middle, no arrow', (tester) async {
      await pump(tester);
      expect(callout(tester).arrowAt, isNull);
      await pump(tester, target: const Rect.fromLTWH(0, 40, 375, 520));
      expect(callout(tester).arrowAt, isNull);
    });

    testWidgets('at 135% text on a 375pt phone, every theme: fits, nothing overflows', (tester) async {
      for (final palette in [AppPalette.light, AppPalette.sepia, AppPalette.dark]) {
        for (final target in [const Rect.fromLTWH(140, 80, 96, 96), const Rect.fromLTWH(20, 470, 335, 90), null]) {
          await pump(
            tester,
            target: target,
            scale: 1.35,
            palette: palette,
            text: "Swipe a card right to freeze a day you can't make, or left to edit it. "
                'Steady practice reaches 80 in about 66 days.',
          );
          expect(tester.takeException(), isNull);
          final bubble = callout(tester).bubbleRect;
          expect(bubble.top, greaterThanOrEqualTo(safe.top));
          expect(bubble.bottom, lessThanOrEqualTo(phone.height - tabBar));
          if (target != null && callout(tester).arrowAt != null) {
            expect(bubble.overlaps(TourSpotlight.holeFor(target).outerRect), isFalse);
          }
        }
      }
    });
  });

  group('touches', () {
    const target = Rect.fromLTWH(140, 300, 96, 60);

    testWidgets('never reach the app outside the hole', (tester) async {
      var app = 0;
      await pump(tester, target: target, passThrough: true, onApp: () => app++);
      await tester.tapAt(const Offset(30, 250));
      expect(app, 0);
    });

    testWidgets('a "try it" lets them through inside the hole', (tester) async {
      var app = 0;
      await pump(tester, target: target, tryIt: true, passThrough: true, onApp: () => app++);
      await tester.tapAt(target.center);
      expect(app, 1);
    });

    testWidgets('otherwise a tap in the hole goes to the tour, not the app', (tester) async {
      var app = 0, hole = 0;
      await pump(tester, target: target, onTapHole: () => hole++, onApp: () => app++);
      await tester.tapAt(target.center);
      expect((app, hole), (0, 1));
    });
  });

  testWidgets('every step can be done or skipped with Next: a "try it" keeps Next and Skip', (tester) async {
    var next = 0, skip = 0;
    await tester.pumpWidget(MaterialApp(
      theme: IOSTheme.material(AppPalette.sepia),
      home: Center(
        child: SizedBox(
          width: 340,
          child: TourBubble(
            eyebrow: 'Try it',
            text: 'Tap + to log one more glass, or tap Next.',
            tryIt: true,
            step: 1,
            steps: 4,
            onNext: () => next++,
            onSkip: () => skip++,
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Next'));
    await tester.tap(find.text('Skip'));
    expect((next, skip), (1, 1));
    expect(find.text('Skip step'), findsNothing);
  });

  testWidgets('a "try it" pulses, but not with Reduce Motion', (tester) async {
    await pump(tester, target: const Rect.fromLTWH(140, 300, 96, 60), tryIt: true);
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(Container());
    await pump(tester, target: const Rect.fromLTWH(140, 300, 96, 60), tryIt: true, reduceMotion: true);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
