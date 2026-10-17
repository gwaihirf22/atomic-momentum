import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';
import 'large_title_scaffold.dart';

/// The main call to action on a screen ("Add habit", "Next: how often"): a
/// full-width pill in the orb's amber gradient.
class OrbButton extends StatelessWidget {
  final String label;

  /// Null disables it.
  final VoidCallback? onPressed;

  /// Shows a spinner instead of the label (while saving).
  final bool busy;

  /// An arrow after the label, for steps that lead on.
  final bool showArrow;

  /// Looks greyed out but still answers taps (for a first tap that does
  /// something else, such as scrolling to what's not been seen yet).
  final bool dimmed;

  /// What a tap does, for VoiceOver, when it isn't obvious from [label].
  final String? hint;

  const OrbButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.showArrow = false,
    this.dimmed = false,
    this.hint,
  });

  static const height = 56.0;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final shape = BorderRadius.circular(height / 2);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      hint: hint,
      excludeSemantics: true,
      onTap: enabled ? onPressed : null,
      child: Opacity(
        opacity: (enabled && !dimmed) || busy ? 1 : 0.45,
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: AppPalette.of(context).orb, borderRadius: shape),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: shape,
              onTap: enabled ? onPressed : null,
              child: ConstrainedBox(
                // Grows with large text rather than clipping the label
                constraints: const BoxConstraints(minHeight: height),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Center(
                    child: busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: AppPalette.onOrb),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: LargeTitleHeader.fontFamily,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: AppPalette.onOrb,
                                  ),
                                ),
                              ),
                              if (showArrow) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded, size: 20, color: AppPalette.onOrb),
                              ],
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
