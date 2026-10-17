import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_style.dart';
import '../../domain/entities/momentum.dart';

/// Overall momentum as a ring in the palette's orb gradient (amber to
/// orange), with the score inside and a small "momentum" caption.
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

    return Semantics(
      label: 'Overall momentum ${momentum.rounded}$trend',
      excludeSemantics: true,
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
              Text('momentum', style: TextStyle(fontSize: 11, color: secondaryLabel(context))),
              if (momentum.isRising || momentum.isFalling)
                Icon(
                  momentum.isRising ? CupertinoIcons.arrow_up : CupertinoIcons.arrow_down,
                  size: 10,
                  color: secondaryLabel(context),
                ),
            ],
          ),
        ],
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
    if (fraction <= 0) return;
    paint.shader = SweepGradient(
      startAngle: 0,
      endAngle: 2 * math.pi,
      colors: [palette.orbStart, palette.gauge, palette.orbEnd],
      transform: const GradientRotation(-math.pi / 2),
    ).createShader(rect);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2,
        2 * math.pi * fraction.clamp(0.0, 1.0), false, paint);
  }

  @override
  bool shouldRepaint(_GradientRingPainter old) => old.fraction != fraction || old.palette != palette;
}
