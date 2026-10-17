import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';

/// A habit's icon inside a ring that fills with its progress, the app's core
/// visual (habit cards and Calendar rows). Done: filled with the habit color
/// and a check. Tapping it (when [onTap] is set) adds one; holding it (when
/// [onLongPress] is set) finishes it.
class HabitProgressRing extends StatelessWidget {
  static const double defaultSize = 52;
  static const double _stroke = 4.5;

  final IconData icon;
  final Color color;
  final double fraction;
  final bool isDone;

  /// Faded, e.g. on a rest day.
  final bool dimmed;
  final String semanticLabel;
  final VoidCallback? onTap;

  /// Holding the ring (finishing it, or clearing it once done).
  final VoidCallback? onLongPress;

  /// What holding does, for VoiceOver.
  final String longPressHint;
  final double size;

  /// Key for the check shown when done (tests look for it).
  final Key? checkKey;

  const HabitProgressRing({
    super.key,
    required this.icon,
    required this.color,
    required this.fraction,
    required this.isDone,
    this.dimmed = false,
    required this.semanticLabel,
    this.onTap,
    this.onLongPress,
    this.longPressHint = 'Finish',
    this.size = defaultSize,
    this.checkKey,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: isDone ? '$semanticLabel, done' : semanticLabel,
      hint: onTap != null ? 'Adds one' : null,
      onLongPressHint: onLongPress != null ? longPressHint : null,
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: onLongPress,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Opacity(
          opacity: dimmed ? 0.45 : 1,
          child: SizedBox(
            width: size,
            height: size,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: fraction),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => CustomPaint(
                painter: RingPainter(fraction: value, color: color, stroke: _stroke),
                child: child,
              ),
              child: Center(
                child: Container(
                  width: size - 14,
                  height: size - 14,
                  decoration: BoxDecoration(
                    color: isDone ? color : color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: isDone
                      ? Icon(Icons.check, key: checkKey, size: 20, color: AppPalette.of(context).onColor(color))
                      : Icon(icon, size: 20, color: color),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A progress ring: a faint full circle with an arc from 12 o'clock.
class RingPainter extends CustomPainter {
  final double fraction;
  final Color color;
  final double stroke;

  /// Opacity of the unfilled track.
  final double trackOpacity;

  RingPainter({required this.fraction, required this.color, required this.stroke, this.trackOpacity = 0.18});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, paint..color = color.withOpacity(trackOpacity));
    if (fraction > 0) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2,
          2 * math.pi * fraction.clamp(0.0, 1.0), false, paint..color = color);
    }
  }

  @override
  bool shouldRepaint(RingPainter old) =>
      old.fraction != fraction || old.color != color || old.stroke != stroke || old.trackOpacity != trackOpacity;
}
