import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';

/// The "2 min" button: logs a habit's two-minute version for a hard day.
/// Outlined until done, then filled with a check; tap again to undo. When
/// the two-minute amount was reached by logging, it shows done and isn't a
/// toggle.
class TwoMinuteButton extends StatelessWidget {
  /// Shortest tap area, taller than the capsule it draws.
  static const minTapHeight = 32.0;

  final String description;
  final Color color;
  final bool done;

  /// Null when it can't be toggled (the amount already counts).
  final ValueChanged<bool>? onChanged;

  const TwoMinuteButton({
    super.key,
    required this.description,
    required this.color,
    required this.done,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final onColor = AppPalette.of(context).onColor(color);
    final label = Text(
      '2 min',
      style: TextStyle(
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: done ? onColor : color,
      ),
    );

    return Semantics(
      button: onChanged != null,
      toggled: done,
      label: 'Two-minute version: $description',
      hint: onChanged == null ? null : (done ? 'Double tap to undo' : 'Double tap if you did it'),
      excludeSemantics: true,
      child: GestureDetector(
        // Opaque, so a tap here never reaches the card (which opens Edit)
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!done),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minTapHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Align(
              widthFactor: 1,
              heightFactor: 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: done ? color : Colors.transparent,
                  border: Border.all(color: color, width: 1.5),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    label,
                    if (done) ...[
                      const SizedBox(width: 3),
                      Icon(CupertinoIcons.checkmark_alt, size: 13, color: onColor),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
