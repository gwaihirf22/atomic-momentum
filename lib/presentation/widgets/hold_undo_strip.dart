import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';

/// A change made by holding a habit's ring (finishing it, or clearing it),
/// still undoable for [HoldUndo.duration].
class HoldUndo {
  /// How long Undo stays offered before the change is final.
  static const duration = Duration(seconds: 4);

  /// "Marked done" or "Cleared".
  final String message;

  /// Finishing (true) or clearing (false).
  final bool finished;
  final DateTime started;
  final VoidCallback onUndo;

  HoldUndo({required this.message, required this.finished, required this.onUndo, DateTime? started})
      : started = started ?? clock.now();

  Duration get remaining {
    final left = duration - clock.now().difference(started);
    return left.isNegative ? Duration.zero : left;
  }
}

/// Covers a habit's card or row while a held change can be undone: what
/// happened, an Undo button, and a bar running down until it's final.
class HoldUndoStrip extends StatelessWidget {
  final HoldUndo undo;

  /// The habit's color, as drawn in this theme.
  final Color color;

  /// Read by VoiceOver with the message ("Drink Water marked done").
  final String habitName;
  final Key? undoKey;

  const HoldUndoStrip({super.key, required this.undo, required this.color, required this.habitName, this.undoKey});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final fraction = undo.remaining.inMilliseconds / HoldUndo.duration.inMilliseconds;
    return Semantics(
      liveRegion: true,
      container: true,
      child: GestureDetector(
        // Taps here never reach the card underneath (which opens Edit)
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Container(
          color: Color.alphaBlend(color.withValues(alpha: palette.theme == AppTheme.dark ? 0.24 : 0.14), palette.surface),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 8, 10),
                // Centered in the card, however tall it is
                child: Row(
                  children: [
                    Icon(
                      undo.finished ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.arrow_counterclockwise_circle_fill,
                      color: color,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Semantics(
                        label: '$habitName ${undo.message.toLowerCase()}',
                        excludeSemantics: true,
                        child: Text(
                          undo.message,
                          maxLines: 2,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: palette.text),
                        ),
                      ),
                    ),
                    TextButton(
                      key: undoKey,
                      onPressed: undo.onUndo,
                      style: TextButton.styleFrom(
                        foregroundColor: palette.text,
                        backgroundColor: palette.surface,
                        minimumSize: const Size(88, 44),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      child: const Text('Undo'),
                    ),
                  ],
                ),
              ),
              // Runs down until the change is final
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: fraction, end: 0),
                  duration: undo.remaining,
                  builder: (context, value, _) => Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      widthFactor: value,
                      child: Container(height: 4, color: color),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lays [HoldUndoStrip] over a whole card (put it last in the card's Stack),
/// fading in and out; nothing while [undo] is null.
class HoldUndoOverlay extends StatelessWidget {
  final HoldUndo? undo;
  final Color color;
  final String habitName;
  final Key? undoKey;

  const HoldUndoOverlay({super.key, required this.undo, required this.color, required this.habitName, this.undoKey});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        // Fill the card, not just the strip's own height
        layoutBuilder: (current, previous) =>
            Stack(fit: StackFit.expand, children: [...previous, if (current != null) current]),
        child: undo == null
            ? const SizedBox.shrink()
            : HoldUndoStrip(
                key: ValueKey(undo!.started),
                undo: undo!,
                color: color,
                habitName: habitName,
                undoKey: undoKey,
              ),
      ),
    );
  }
}
