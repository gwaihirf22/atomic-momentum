import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/locale/week_start.dart';
import '../../core/theme/app_palette.dart';
import '../../domain/services/insights.dart';

/// Days as a grid of small squares, a column per week, darker for more
/// done; a perfect day is outlined. Days to come in the last week show as
/// empty outlines. Tapping a day reports it.
class Heatmap extends StatelessWidget {
  /// Consecutive days, oldest first, ending today.
  final List<DayRecord> days;

  /// The first day of the user's week (DateTime.monday..sunday).
  final int weekStart;

  final DateTime? selected;
  final ValueChanged<DateTime>? onSelect;

  /// A label for VoiceOver, saying what the grid shows overall.
  final String semanticLabel;

  const Heatmap({
    super.key,
    required this.days,
    required this.weekStart,
    required this.semanticLabel,
    this.selected,
    this.onSelect,
  });

  static const gap = 2.0;
  static const maxCell = 12.0;
  static const labelWidth = 14.0;

  /// How full a day looks, 0 to 4 (0: something due, nothing done).
  static int shadeOf(DayRecord record) {
    final level = record.level;
    if (record.isEmpty || level <= 0) return 0;
    if (level >= 1) return 4;
    if (level > 0.5) return 3;
    if (level > 0.25) return 2;
    return 1;
  }

  /// The colors for shades 0 to 4.
  static List<Color> shades(AppPalette palette) => [
        palette.raised,
        palette.tint(palette.gauge, alpha: 0.3),
        palette.tint(palette.gauge, alpha: 0.5),
        palette.tint(palette.gauge, alpha: 0.75),
        palette.gauge,
      ];

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    final palette = AppPalette.of(context);
    final first = days.first.day;
    final firstColumn = DateTime(first.year, first.month, first.day - _row(first));
    final last = days.last.day;
    final columns = _daysBetween(firstColumn, last) ~/ 7 + 1;
    final letters = [for (final weekday in weekdaysStartingOn(weekStart)) 'MTWTFSS'[weekday - 1]];
    final labelStyle = TextStyle(fontSize: 9, height: 1, color: palette.textSecondary);

    return MediaQuery.withClampedTextScaling(
      // Labels sit beside squares a few points tall
      maxScaleFactor: 1.2,
      child: LayoutBuilder(builder: (context, constraints) {
        final cell = math.min(maxCell, (constraints.maxWidth - labelWidth - gap * columns) / columns);
        final gridWidth = columns * cell + (columns - 1) * gap;
        final gridHeight = 7 * cell + 6 * gap;
        final monthLabels = _monthLabels(firstColumn, columns, cell);

        DateTime? dayAt(Offset position) {
          final column = (position.dx / (cell + gap)).floor();
          final row = (position.dy / (cell + gap)).floor();
          if (column < 0 || column >= columns || row < 0 || row > 6) return null;
          final day = DateTime(firstColumn.year, firstColumn.month, firstColumn.day + column * 7 + row);
          return day.isBefore(first) || day.isAfter(last) ? null : day;
        }

        return Semantics(
          label: semanticLabel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: labelWidth,
                  height: gridHeight,
                  child: Stack(children: [
                    for (var row = 0; row < 7; row += 2)
                      Positioned(
                        top: row * (cell + gap) + (cell - 9) / 2,
                        left: 0,
                        child: ExcludeSemantics(child: Text(letters[row], style: labelStyle)),
                      ),
                  ]),
                ),
                GestureDetector(
                  key: const Key('heatmapGrid'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: onSelect == null
                      ? null
                      : (details) {
                          final day = dayAt(details.localPosition);
                          if (day != null) onSelect!(day);
                        },
                  child: CustomPaint(
                    size: Size(gridWidth, gridHeight),
                    painter: _HeatmapPainter(
                      days: days,
                      firstColumn: firstColumn,
                      cell: cell,
                      shades: shades(palette),
                      outline: palette.text,
                      upcoming: palette.track,
                      selected: selected,
                      row: _row,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              SizedBox(
                height: 12,
                width: labelWidth + gridWidth,
                child: Stack(clipBehavior: Clip.none, children: [
                  for (final (x, text) in monthLabels)
                    Positioned(
                      left: labelWidth + x,
                      top: 0,
                      child: ExcludeSemantics(child: Text(text, style: labelStyle.copyWith(fontSize: 10))),
                    ),
                ]),
              ),
            ],
          ),
        );
      }),
    );
  }

  /// The day's row: 0 for the first day of the week.
  int _row(DateTime day) => (day.weekday - weekStart + 7) % 7;

  /// Month names under the week each month starts in, leaving out any that
  /// would crowd the one before.
  List<(double, String)> _monthLabels(DateTime firstColumn, int columns, double cell) {
    final labels = <(double, String)>[];
    var lastX = -100.0;
    for (var column = 0; column < columns; column++) {
      final weekStartDay = DateTime(firstColumn.year, firstColumn.month, firstColumn.day + column * 7);
      final weekEnd = DateTime(weekStartDay.year, weekStartDay.month, weekStartDay.day + 6);
      final startsMonth =
          column == 0 ? weekStartDay.day <= 7 : weekEnd.month != weekStartDay.month || weekStartDay.day == 1;
      if (!startsMonth) continue;
      final month = column == 0 || weekStartDay.day == 1 ? weekStartDay : DateTime(weekEnd.year, weekEnd.month);
      final x = column * (cell + Heatmap.gap);
      if (x - lastX < 26) continue;
      labels.add((x, DateFormat.MMM().format(month)));
      lastX = x;
    }
    return labels;
  }

  static int _daysBetween(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}

class _HeatmapPainter extends CustomPainter {
  final List<DayRecord> days;
  final DateTime firstColumn;
  final double cell;
  final List<Color> shades;
  final Color outline;
  final Color upcoming;
  final DateTime? selected;
  final int Function(DateTime) row;

  _HeatmapPainter({
    required this.days,
    required this.firstColumn,
    required this.cell,
    required this.shades,
    required this.outline,
    required this.upcoming,
    required this.selected,
    required this.row,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(math.max(1.5, cell / 4));
    Rect rectFor(DateTime day) {
      final column = Heatmap._daysBetween(firstColumn, day) ~/ 7;
      return Rect.fromLTWH(column * (cell + Heatmap.gap), row(day) * (cell + Heatmap.gap), cell, cell);
    }

    final fill = Paint();
    final stroke = Paint()..style = PaintingStyle.stroke;
    for (final record in days) {
      final rect = RRect.fromRectAndRadius(rectFor(record.day), radius);
      final empty = record.isEmpty;
      fill.color = empty ? shades[0].withValues(alpha: 0.5) : shades[Heatmap.shadeOf(record)];
      canvas.drawRRect(rect, fill);
      if (record.perfect) {
        canvas.drawRRect(
          rect.deflate(0.5),
          stroke
            ..color = outline.withValues(alpha: 0.85)
            ..strokeWidth = 1,
        );
      }
    }

    // The rest of this week, still to come
    final last = days.last.day;
    for (var day = DateTime(last.year, last.month, last.day + 1);
        row(day) != 0;
        day = DateTime(day.year, day.month, day.day + 1)) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rectFor(day).deflate(0.5), radius),
        stroke
          ..color = upcoming
          ..strokeWidth = 1,
      );
    }

    if (selected != null && !selected!.isBefore(days.first.day) && !selected!.isAfter(last)) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rectFor(selected!).inflate(1.5), radius),
        stroke
          ..color = outline
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) =>
      old.days != days ||
      old.cell != cell ||
      old.selected != selected ||
      old.shades != shades ||
      old.outline != outline;
}
