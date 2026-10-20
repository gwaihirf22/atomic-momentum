import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_palette.dart';
import '../widgets/floating_tab_bar.dart';
import 'spotlight.dart';
import 'tour_bubble.dart';
import 'tour_controller.dart';

/// The running tour over everything (the tab bar, pages and sheets): the
/// spotlight on the step's target, following it as it moves, and the bubble
/// with Skip and Next. Every step can also be done for real: touches inside
/// the spotlight reach the app, and a step waiting for that thing moves on
/// when it's done. Nothing while no tour runs.
class TourLayer extends StatefulWidget {
  const TourLayer({super.key});

  @override
  State<TourLayer> createState() => _TourLayerState();
}

class _TourLayerState extends State<TourLayer> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => _follow());
  Rect? _rect;
  TourController? _tours;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tours = context.read<TourController>();
    if (tours != _tours) {
      _tours?.removeListener(_changed);
      _tours = tours..addListener(_changed);
      _changed();
    }
  }

  @override
  void dispose() {
    _tours?.removeListener(_changed);
    _ticker.dispose();
    super.dispose();
  }

  void _changed() {
    final running = _tours?.isRunning ?? false;
    if (running && !_ticker.isActive) _ticker.start();
    if (!running && _ticker.isActive) _ticker.stop();
    if (mounted) setState(() => _rect = _find());
  }

  /// Follows the target as it moves (a scroll, a swipe, a page sliding in).
  void _follow() {
    final rect = _find();
    if (rect != _rect) setState(() => _rect = rect);
  }

  Rect? _find() {
    final tours = _tours;
    final anchor = tours?.step?.anchor;
    if (tours == null || anchor == null || !tours.isReady) return null;
    return tours.anchors.rectOf(anchor, tag: _tagOf(tours));
  }

  String? _tagOf(TourController tours) => tours.step?.habit == null ? null : tours.stepHabitId;

  @override
  Widget build(BuildContext context) {
    final tours = _tours;
    if (tours != null && tours.isOffering) {
      return TourSpotlight(
        target: null,
        bubble: TourBubble(
          eyebrow: 'New',
          text: 'Short tours show you around the app, on example habits. Take the Habits tour?',
          actions: [
            TextButton(
              key: const Key('tourOfferNotNow'),
              onPressed: tours.declineOffer,
              child: const Text('Not now'),
            ),
            const SizedBox(width: 4),
            TourNextButton(key: const Key('tourOfferStart'), label: 'Start', onPressed: tours.acceptOffer),
          ],
        ),
      );
    }
    final tour = tours?.tour;
    final step = tours?.step;
    if (tours == null || tour == null || step == null) return const SizedBox.shrink();
    if (!tours.isReady) {
      // Between steps (a tab switching, a page sliding in): dimmed, still
      return AbsorbPointer(child: ColoredBox(color: AppPalette.of(context).scrim, child: const SizedBox.expand()));
    }
    final index = tours.stepIndex;
    final last = index == tour.steps.length - 1;
    final media = MediaQuery.of(context);
    return TourSpotlight(
      target: _rect,
      side: step.side,
      tryIt: step.wait != null,
      // A try-it step can be done for real; any step moved on with Next
      passThrough: step.passesTouches,
      bottomCovered: FloatingTabBar.coveredHeight(media.padding.bottom),
      bubble: TourBubble(
        // A new step: VoiceOver moves to it
        key: ValueKey((tour.id, index)),
        eyebrow: step.eyebrow ?? (step.wait != null ? 'Try it' : tour.title),
        text: step.text,
        step: index,
        steps: tour.steps.length,
        tryIt: step.wait != null,
        nextLabel: last ? (step.nextLabel ?? 'Done') : 'Next',
        onNext: tours.next,
        onSkip: tours.skip,
      ),
    );
  }
}
