import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../screens/ios_main_navigation.dart';
import '../tour/spotlight.dart';
import '../tour/tour_bubble.dart';
import '../widgets/floating_tab_bar.dart';

/// Settings → Developer → "Tour style preview" (debug and test builds): the
/// tours' spotlight and bubbles over the real Habits screen, a step at a
/// time, to judge the look in each theme and text size before the tours are
/// built. Touches never reach the app, so nothing changes.
abstract final class TourStylePreview {
  static OverlayEntry? _entry;

  /// The step showing, for tests and the screenshot run.
  static final step = ValueNotifier<int>(0);

  static bool get isShowing => _entry != null;

  static void show(BuildContext context, {int at = 0}) {
    close();
    step.value = at;
    IOSMainNavigation.tabRequests.value = AppTab.habits;
    final entry = OverlayEntry(builder: (_) => const _Preview());
    _entry = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  static void close() {
    _entry?.remove();
    _entry = null;
  }

  static const steps = [
    _Step(
      target: _Target.key('overallMomentum'),
      eyebrow: 'Habits',
      text: "This is your momentum: how steadily you've been showing up. "
          'Steady practice reaches 80 in about 66 days.',
      example: true,
    ),
    _Step(
      target: _Target.prefix('incrementHabit_'),
      eyebrow: 'Try it',
      text: 'Tap + to log one more glass.',
      tryIt: true,
      example: true,
    ),
    _Step(
      target: _Target.prefix('habitCard_'),
      eyebrow: 'Habits',
      text: "Swipe a card right to freeze a day you can't make, or left to edit it.",
      example: true,
    ),
    _Step(
      target: _Target.key('addHabitButton'),
      eyebrow: 'Your turn',
      text: 'Add your first habit here. More short tours appear as you visit the other tabs.',
      next: 'Done',
    ),
    _Step(
      eyebrow: 'New',
      text: 'Short tours show you around the app. Take the Habits tour?',
      offer: true,
    ),
  ];
}

class _Target {
  final String text;
  final bool isPrefix;
  const _Target.key(this.text) : isPrefix = false;
  const _Target.prefix(this.text) : isPrefix = true;

  bool matches(Key? key) {
    if (key is! ValueKey<String>) return false;
    return isPrefix ? key.value.startsWith(text) : key.value == text;
  }
}

class _Step {
  final _Target? target;
  final String eyebrow;
  final String text;
  final bool tryIt;
  final bool example;
  final bool offer;
  final String next;

  const _Step({
    this.target,
    required this.eyebrow,
    required this.text,
    this.tryIt = false,
    this.example = false,
    this.offer = false,
    this.next = 'Next',
  });
}

class _Preview extends StatefulWidget {
  const _Preview();

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => _follow());
  Rect? _rect;

  @override
  void initState() {
    super.initState();
    TourStylePreview.step.addListener(_changed);
    _ticker.start();
  }

  @override
  void dispose() {
    TourStylePreview.step.removeListener(_changed);
    _ticker.dispose();
    super.dispose();
  }

  void _changed() => setState(() => _rect = _find());

  /// Follows the target as it moves (a scroll, a tab switching in).
  void _follow() {
    final rect = _find();
    if (rect != _rect) setState(() => _rect = rect);
  }

  _Step get _step => TourStylePreview.steps[TourStylePreview.step.value.clamp(0, TourStylePreview.steps.length - 1)];

  /// The first visible widget whose key matches, skipping tabs kept offstage.
  Rect? _find() {
    final target = _step.target;
    if (target == null) return null;
    Rect? found;
    void visit(Element element) {
      if (found != null) return;
      final widget = element.widget;
      if (widget is Offstage && widget.offstage) return;
      if (widget is _Preview) return;
      if (target.matches(widget.key)) {
        final box = element.renderObject;
        if (box is RenderBox && box.attached && box.hasSize) {
          found = box.localToGlobal(Offset.zero) & box.size;
          return;
        }
      }
      element.visitChildElements(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildElements(visit);
    return found;
  }

  void _next() {
    final next = TourStylePreview.step.value + 1;
    if (next >= TourStylePreview.steps.length) {
      TourStylePreview.close();
    } else {
      TourStylePreview.step.value = next;
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _step;
    final index = TourStylePreview.step.value;
    final media = MediaQuery.of(context);
    final pinned = step.target == null || _rect == null;
    final shown = step.offer ? 1 : 4;
    return Stack(children: [
      Positioned.fill(
        child: TourSpotlight(
          target: _rect,
          tryIt: step.tryIt,
          onTapHole: step.tryIt ? _next : null,
          bottomCovered: FloatingTabBar.coveredHeight(media.padding.bottom),
          bubble: TourBubble(
            eyebrow: step.eyebrow,
            text: step.text,
            step: step.offer ? 0 : index,
            steps: step.offer || pinned && step.target != null ? 0 : shown,
            tryIt: step.tryIt,
            nextLabel: step.next,
            onNext: _next,
            onSkip: TourStylePreview.close,
            actions: step.offer
                ? [
                    const TextButton(onPressed: TourStylePreview.close, child: Text('Not now')),
                    const SizedBox(width: 4),
                    TourNextButton(label: 'Start', onPressed: _next),
                  ]
                : null,
          ),
        ),
      ),
      if (step.example)
        Positioned(
          top: media.padding.top + 6,
          left: 0,
          right: 0,
          child: const Center(child: ExampleHabitsPill()),
        ),
    ]);
  }
}
