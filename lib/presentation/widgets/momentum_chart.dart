import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../../core/theme/app_palette.dart';
import '../../domain/entities/momentum.dart';
import '../../domain/services/insights.dart';

/// Overall momentum month by month, on a 0–100 scale with a dotted line at
/// 80 (habit formed). Months before anything was tracked are left out.
class MomentumChart extends StatelessWidget {
  final List<MonthMomentum> months;
  final double height;

  const MomentumChart({super.key, required this.months, this.height = 96});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final label = months
        .where((m) => m.score != null)
        .map((m) => '${DateFormat.MMMM().format(m.month)} ${m.score!.round()}')
        .join(', ');
    return Semantics(
      label: 'Overall momentum by month: $label',
      excludeSemantics: true,
      child: Column(children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _ChartPainter(
              scores: [for (final m in months) m.score],
              line: palette.gauge,
              guide: palette.textSecondary,
              surface: palette.surface,
              guideLabel: TextSpan(
                text: '${Momentum.habitFormed} · habit formed',
                style: DefaultTextStyle.of(context).style.copyWith(fontSize: 10, color: palette.textSecondary),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: Row(children: [
            for (var i = 0; i < months.length; i++)
              Expanded(
                child: Text(
                  DateFormat.MMM().format(months[i].month),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: i == months.length - 1 ? FontWeight.w700 : FontWeight.w400,
                    color: i == months.length - 1 ? palette.text : palette.textSecondary,
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double?> scores;
  final Color line;
  final Color guide;
  final Color surface;
  final TextSpan guideLabel;

  _ChartPainter({
    required this.scores,
    required this.line,
    required this.guide,
    required this.surface,
    required this.guideLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const top = 18.0, bottom = 6.0;
    double y(double score) => top + (size.height - top - bottom) * (1 - score / 100);
    // Each month sits in the middle of its column, as its label does
    double x(int i) => size.width * (i + 0.5) / scores.length;

    // The dotted line at 80
    final guideY = y(Momentum.habitFormed.toDouble());
    final dash = Paint()
      ..color = guide.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (var dx = 0.0; dx < size.width; dx += 7) {
      canvas.drawLine(Offset(dx, guideY), Offset(dx + 3, guideY), dash);
    }
    // At the start of the line, where momentum is usually still lower
    final text = TextPainter(text: guideLabel, textDirection: TextDirection.ltr)..layout();
    text.paint(canvas, Offset(0, guideY - text.height - 2));

    final points = [
      for (var i = 0; i < scores.length; i++)
        if (scores[i] != null) Offset(x(i), y(scores[i]!)),
    ];
    if (points.isEmpty) return;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    final area = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [line.withValues(alpha: 0.28), line.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(points.last, 5, Paint()..color = line);
    canvas.drawCircle(
      points.last,
      5,
      Paint()
        ..color = surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.scores != scores || old.line != line || old.guide != guide;
}
