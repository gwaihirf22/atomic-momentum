import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';

/// Momentum's mark, the ring and the bolt of the app icon, drawn in the
/// theme's colours: the bolt in the orb's amber, the ring from the text colour
/// into amber (charcoal on Light and Sepia, light on Charged), with a glow.
class MomentumMark extends StatelessWidget {
  final double size;

  const MomentumMark({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _MarkPainter(AppPalette.of(context))),
    );
  }
}

class _MarkPainter extends CustomPainter {
  final AppPalette palette;

  _MarkPainter(this.palette);

  // The icon's geometry, on a 1-wide square: the ring's centre, radius and
  // stroke, its two gaps (degrees, clockwise from three o'clock), and the bolt
  static const _centre = Offset(0.5, 0.493);
  static const _radius = 0.33;
  static const _stroke = 0.064;
  static const _gaps = [(-70.0, -54.0), (111.0, 128.0)];
  static const _bolt = [
    Offset(0.674, 0.200),
    Offset(0.359, 0.537),
    Offset(0.454, 0.537),
    Offset(0.317, 0.786),
    Offset(0.635, 0.464),
    Offset(0.535, 0.464),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final centre = _centre * s;
    final radius = _radius * s;
    final rect = Offset.zero & size;
    final ringShader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [palette.text, palette.text, palette.orbEnd],
      stops: const [0, 0.45, 1],
    ).createShader(rect);
    final boltShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [palette.orbStart, palette.orbEnd],
    ).createShader(rect);

    final bolt = Path()..addPolygon([for (final p in _bolt) p * s], true);
    final arcs = Path();
    final circle = Rect.fromCircle(center: centre, radius: radius);
    double rad(double degrees) => degrees * math.pi / 180;
    for (var i = 0; i < _gaps.length; i++) {
      final from = _gaps[i].$2;
      final to = _gaps[(i + 1) % _gaps.length].$1 + (i + 1 == _gaps.length ? 360 : 0);
      arcs.addArc(circle, rad(from), rad(to - from));
    }

    // A soft glow behind, in the accent
    final glow = Paint()
      ..color = palette.accent.withValues(alpha: 0.35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.05);
    canvas.drawPath(bolt, glow);
    canvas.drawPath(
        arcs,
        Paint()
          ..color = palette.accent.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke * s
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.04));

    canvas.drawPath(
        arcs,
        Paint()
          ..shader = ringShader
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke * s
          ..strokeCap = StrokeCap.butt);
    canvas.drawPath(bolt, Paint()..shader = boltShader);
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => oldDelegate.palette != palette;
}
