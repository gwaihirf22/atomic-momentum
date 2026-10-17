import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_style.dart';
import '../../domain/entities/momentum.dart';

/// Overall momentum as a ring in the logo's electric blue, with the score
/// inside and a small "momentum" caption.
class MomentumRing extends StatelessWidget {
  /// The logo's gradient, cyan to blue.
  static const gradient = [Color(0xFF7DF3FF), Color(0xFF2F7BFF), Color(0xFF5B5BFF)];

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
    final label = CupertinoDynamicColor.resolve(CupertinoColors.label, context);

    return Semantics(
      label: 'Overall momentum ${momentum.rounded}$trend',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: momentum.score / 100),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => CustomPaint(
                painter: _GradientRingPainter(fraction: value),
                child: child,
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt, size: 14, color: Color(0xFF2F7BFF)),
                    Text(
                      '${momentum.rounded}',
                      style: TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: label,
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

  _GradientRingPainter({required this.fraction});

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

    canvas.drawCircle(center, radius, paint..color = MomentumRing.gradient[1].withOpacity(0.15));
    if (fraction <= 0) return;
    paint.shader = SweepGradient(
      startAngle: 0,
      endAngle: 2 * math.pi,
      colors: MomentumRing.gradient,
      transform: const GradientRotation(-math.pi / 2),
    ).createShader(rect);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2,
        2 * math.pi * fraction.clamp(0.0, 1.0), false, paint);
  }

  @override
  bool shouldRepaint(_GradientRingPainter old) => old.fraction != fraction;
}
