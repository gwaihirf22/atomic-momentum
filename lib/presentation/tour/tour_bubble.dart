import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

/// What a tour says at one step: a small eyebrow (the tour's name, or
/// "Try it"), one or two short sentences, the steps as dots, and Skip / Next.
/// On a "try it" step Next gives way to a quieter "Skip step": the step moves
/// on by itself once the person does the thing.
class TourBubble extends StatelessWidget {
  final String eyebrow;
  final String text;
  final int step;
  final int steps;
  final bool tryIt;

  /// The last step's Next reads "Done".
  final String nextLabel;
  final VoidCallback? onNext;
  final VoidCallback? onSkip;

  /// Replaces Next / Skip (the "Take the tour?" offer's Start / Not now).
  final List<Widget>? actions;

  const TourBubble({
    super.key,
    required this.eyebrow,
    required this.text,
    this.step = 0,
    this.steps = 0,
    this.tryIt = false,
    this.nextLabel = 'Next',
    this.onNext,
    this.onSkip,
    this.actions,
  });

  static const radius = 18.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Semantics(
      container: true,
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: steps > 1 ? '$eyebrow, step ${step + 1} of $steps' : eyebrow,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [BoxShadow(color: palette.barShadow, blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Eyebrow(text: eyebrow, tryIt: tryIt),
                const SizedBox(height: 8),
                // Scrolls rather than overflowing when the bubble is squeezed
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        text,
                        style: TextStyle(fontSize: 16, height: 1.35, color: palette.text),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _Footer(
                  step: step,
                  steps: steps,
                  tryIt: tryIt,
                  nextLabel: nextLabel,
                  onNext: onNext,
                  onSkip: onSkip,
                  actions: actions,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  final String text;
  final bool tryIt;
  const _Eyebrow({required this.text, required this.tryIt});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final label = Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: tryIt ? AppPalette.onOrb : palette.accent,
      ),
    );
    if (!tryIt) return label;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: palette.orb, borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(CupertinoIcons.hand_point_right_fill, size: 13, color: AppPalette.onOrb),
          const SizedBox(width: 5),
          Flexible(child: label),
        ]),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final int step;
  final int steps;
  final bool tryIt;
  final String nextLabel;
  final VoidCallback? onNext;
  final VoidCallback? onSkip;
  final List<Widget>? actions;

  const _Footer({
    required this.step,
    required this.steps,
    required this.tryIt,
    required this.nextLabel,
    required this.onNext,
    required this.onSkip,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final quiet = TextButton.styleFrom(
      foregroundColor: palette.textSecondary,
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    );
    final actions = this.actions;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 4,
      spacing: 8,
      children: [
        if (actions == null && onSkip != null)
          TextButton(style: quiet, onPressed: onSkip, child: Text(tryIt ? 'Skip step' : 'Skip')),
        if (steps > 1) _Dots(step: step, steps: steps),
        if (actions != null) Row(mainAxisSize: MainAxisSize.min, children: actions),
        if (actions == null && !tryIt && onNext != null) TourNextButton(label: nextLabel, onPressed: onNext!),
      ],
    );
  }
}

/// The steps as dots, the current one longer and in the accent.
class _Dots extends StatelessWidget {
  final int step;
  final int steps;
  const _Dots({required this.step, required this.steps});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return ExcludeSemantics(
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < steps; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            width: i == step ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == step ? palette.accent : palette.track,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ]),
    );
  }
}

/// A tour's Next (or Done, Start): a compact orb pill.
class TourNextButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const TourNextButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Center(
            widthFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: palette.orb,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: palette.orbShadow, blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppPalette.onOrb),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown while a tour runs on example habits, so nobody mistakes them for
/// their own. With [onDone], a tap leaves them.
class ExampleHabitsPill extends StatelessWidget {
  final VoidCallback? onDone;

  const ExampleHabitsPill({super.key, this.onDone});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final pill = DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.accent.withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(color: palette.barShadow, blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(CupertinoIcons.sparkles, size: 14, color: palette.accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Example habits',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette.text),
            ),
          ),
          if (onDone != null) ...[
            Text(' · ', style: TextStyle(fontSize: 13, color: palette.textSecondary)),
            Text('Done', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: palette.accent)),
          ],
        ]),
      ),
    );
    final done = onDone;
    if (done == null) return pill;
    return Semantics(
      button: true,
      label: 'Example habits. Done',
      hint: 'Back to your own habits',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: done,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 44), child: Center(widthFactor: 1, child: pill)),
      ),
    );
  }
}
