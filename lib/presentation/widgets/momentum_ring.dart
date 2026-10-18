import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';
import '../../domain/entities/momentum.dart';
import '../help/explainers.dart';
import 'info_button.dart';

/// Overall momentum as a ring in the palette's orb gradient (amber to
/// orange), with the score inside, a mark at 80 (a habit formed) and its
/// level underneath ("Strong ↑"). Tapping it explains momentum.
class MomentumRing extends StatelessWidget {
  final Momentum momentum;
  final double size;

  const MomentumRing({super.key, required this.momentum, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final trend = momentum.isRising
        ? ', rising'
        : momentum.isFalling
            ? ', falling'
            : '';
    final palette = AppPalette.of(context);
    // Grows with the text size so the score always fits inside
    final ringSize = size * math.max(1.0, MediaQuery.textScalerOf(context).scale(1));

    void explain() => showInfoSheet(context, InfoTopic.momentum, momentum: momentum.score);

    return Semantics(
      label: 'Overall momentum ${momentum.rounded}, ${momentum.level.label}$trend',
      hint: InfoTopic.momentum.buttonLabel,
      button: true,
      onTap: explain,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: explain,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: ringSize,
              height: ringSize,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: momentum.score / 100),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => CustomPaint(
                  painter: _GradientRingPainter(fraction: value, palette: palette),
                  child: child,
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt, size: 14, color: palette.gauge),
                      Text(
                        '${momentum.rounded}',
                        style: TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: palette.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  momentum.level.label,
                  key: const Key('momentumLevel'),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: palette.gauge),
                ),
                if (momentum.isRising || momentum.isFalling)
                  Icon(
                    momentum.isRising ? CupertinoIcons.arrow_up : CupertinoIcons.arrow_down,
                    size: 10,
                    color: palette.gauge,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientRingPainter extends CustomPainter {
  final double fraction;
  final AppPalette palette;

  _GradientRingPainter({required this.fraction, required this.palette});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
    final rect = Offset.zero & size;
    final radius = (size.shortestSide - stroke) / 2;
    final center = rect.center;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, paint..color = palette.track);
    if (fraction > 0) _paintArc(canvas, rect, center, radius, paint);
    _paintFormedMark(canvas, center, radius, stroke);
  }

  void _paintArc(Canvas canvas, Rect rect, Offset center, double radius, Paint paint) {
    paint.shader = SweepGradient(
      startAngle: 0,
      endAngle: 2 * math.pi,
      colors: [palette.orbStart, palette.gauge, palette.orbEnd],
      transform: const GradientRotation(-math.pi / 2),
    ).createShader(rect);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2,
        2 * math.pi * fraction.clamp(0.0, 1.0), false, paint);
  }

  /// A short mark across the track at 80, where a habit has formed.
  void _paintFormedMark(Canvas canvas, Offset center, double radius, double stroke) {
    final angle = -math.pi / 2 + 2 * math.pi * Momentum.habitFormed / 100;
    final direction = Offset(math.cos(angle), math.sin(angle));
    canvas.drawLine(
      center + direction * (radius - stroke),
      center + direction * (radius + stroke),
      Paint()
        ..color = palette.text
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GradientRingPainter old) => old.fraction != fraction || old.palette != palette;
}
