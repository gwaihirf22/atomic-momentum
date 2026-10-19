import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../../core/locale/week_start.dart';
import '../../core/theme/app_palette.dart';
import '../../domain/services/insights.dart';

/// What a day on the heatmap says: "Tue, Oct 6: 4 of 4 kept · perfect day".
String heatmapDaySummary(DayRecord record) {
  final date = DateFormat.MMMEd().format(record.day);
  final frozen = record.frozen == 0 ? null : '${record.frozen} frozen';
  if (record.isEmpty) return frozen == null ? '$date: nothing due' : '$date: $frozen';
  final kept = record.done + record.twoMinute;
  return [
    '$date: $kept of ${record.due} kept',
    if (record.perfect) 'perfect day',
    if (record.twoMinute > 0) '${record.twoMinute} with 2 min',
    if (frozen != null) frozen,
  ].join(' · ');
}

/// Where days sit on a heatmap: a column per week (starting on [weekStart]),
/// a row per weekday, squares [Heatmap.gap] apart.
class _Layout {
  final List<DayRecord> days;
  final int weekStart;
  final DateTime first;
  final DateTime last;
  final DateTime firstColumn;
  final int columns;

  _Layout._(this.days, this.weekStart, this.first, this.last, this.firstColumn, this.columns);

  factory _Layout(List<DayRecord> days, int weekStart) {
    final first = days.first.day;
    final last = days.last.day;
    final firstColumn = DateTime(first.year, first.month, first.day - (first.weekday - weekStart + 7) % 7);
    final columns = _daysBetween(firstColumn, last) ~/ 7 + 1;
    return _Layout._(days, weekStart, first, last, firstColumn, columns);
  }

  int row(DateTime day) => (day.weekday - weekStart + 7) % 7;
  int column(DateTime day) => _daysBetween(firstColumn, day) ~/ 7;
  DateTime weekOf(int column) => DateTime(firstColumn.year, firstColumn.month, firstColumn.day + column * 7);

  double width(double cell) => columns * cell + (columns - 1) * Heatmap.gap;
  static double height(double cell) => 7 * cell + 6 * Heatmap.gap;

  DateTime? dayAt(Offset position, double cell) {
    final column = (position.dx / (cell + Heatmap.gap)).floor();
    final row = (position.dy / (cell + Heatmap.gap)).floor();
    if (column < 0 || column >= columns || row < 0 || row > 6) return null;
    final day = DateTime(firstColumn.year, firstColumn.month, firstColumn.day + column * 7 + row);
    return day.isBefore(first) || day.isAfter(last) ? null : day;
  }

  /// The column each month starts in (the week holding its 1st, or the
  /// first column for the month already under way), with the month.
  /// Worked out once per layout: labels and year lines read it on every frame.
  late final List<(int, DateTime)> _monthStarts = _findMonthStarts();

  List<(int, DateTime)> monthStarts() => _monthStarts;

  List<(int, DateTime)> _findMonthStarts() {
    final starts = <(int, DateTime)>[(0, DateTime(first.year, first.month))];
    for (var c = 0; c < columns; c++) {
      final week = weekOf(c);
      for (var d = 0; d < 7; d++) {
        final day = DateTime(week.year, week.month, week.day + d);
        if (day.day == 1 && day.isAfter(first) && !day.isAfter(last)) starts.add((c, DateTime(day.year, day.month)));
      }
    }
    return starts;
  }

  static int _daysBetween(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}

/// Days as a grid of small squares, a column per week, darker for more
/// done; a perfect day is outlined. Days to come in the last week show as
/// empty outlines. Fits its width; tapping a day reports it.
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
    final layout = _Layout(days, weekStart);

    return MediaQuery.withNoTextScaling(
      // Labels sit beside squares a few points tall
      child: LayoutBuilder(builder: (context, constraints) {
        final cell = math.min(maxCell, (constraints.maxWidth - labelWidth - gap * layout.columns) / layout.columns);
        final gridWidth = layout.width(cell);
        final gridHeight = _Layout.height(cell);
        final labelStyle = TextStyle(fontSize: 10, height: 1, color: palette.textSecondary);

        return Semantics(
          label: semanticLabel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _WeekdayLabels(weekStart: weekStart, cell: cell, width: labelWidth, top: 0),
                GestureDetector(
                  key: const Key('heatmapGrid'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: onSelect == null
                      ? null
                      : (details) {
                          final day = layout.dayAt(details.localPosition, cell);
                          if (day != null) onSelect!(day);
                        },
                  child: CustomPaint(
                    size: Size(gridWidth, gridHeight),
                    painter: _HeatmapPainter(layout: layout, cell: cell, palette: palette, selected: selected),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              SizedBox(
                height: 12,
                width: labelWidth + gridWidth,
                child: Stack(clipBehavior: Clip.none, children: [
                  for (final (x, text) in _monthLabels(layout, cell, (month, _) => DateFormat.MMM().format(month)))
                    Positioned(
                      left: labelWidth + x,
                      top: 0,
                      child: ExcludeSemantics(child: Text(text, style: labelStyle)),
                    ),
                ]),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// Month names at the column each month starts in, leaving out any that
/// would crowd the one before.
List<(double, String)> _monthLabels(
  _Layout layout,
  double cell,
  String Function(DateTime month, bool first) name, {
  double charWidth = 6,
}) {
  final labels = <(double, String)>[];
  var nextFree = -1.0;
  for (final (column, month) in layout.monthStarts()) {
    final x = column * (cell + Heatmap.gap);
    final text = name(month, labels.isEmpty);
    if (x < nextFree) continue;
    labels.add((x, text));
    nextFree = x + text.length * charWidth + 6;
  }
  return labels;
}

/// The weekday letters beside the grid, one per row when rows are tall
/// enough, else every other row (from the week's first day). Sized to the
/// rows, so none is cut off whatever the zoom.
class _WeekdayLabels extends StatelessWidget {
  final int weekStart;
  final double cell;
  final double width;

  /// Space above the first row (for month labels).
  final double top;

  const _WeekdayLabels({required this.weekStart, required this.cell, required this.width, required this.top});

  @override
  Widget build(BuildContext context) {
    final letters = [for (final weekday in weekdaysStartingOn(weekStart)) 'MTWTFSS'[weekday - 1]];
    final every = cell >= 9 ? 1 : 2;
    // Fits the rows it labels: one row, or two when every other is shown
    final size = math.min(11.0, every * (cell + Heatmap.gap) - 1);
    final style = TextStyle(fontSize: size, height: 1, color: AppPalette.of(context).textSecondary);
    return SizedBox(
      width: width,
      height: top + _Layout.height(cell),
      child: Stack(clipBehavior: Clip.none, children: [
        for (var row = 0; row < 7; row += every)
          Positioned(
            // Centered on its row, but never above the first or below the last
            top: top + (row * (cell + Heatmap.gap) + (cell - size) / 2).clamp(0.0, _Layout.height(cell) - size),
            left: 0,
            child: ExcludeSemantics(child: Text(letters[row], key: Key('heatmapWeekday_$row'), style: style)),
          ),
      ]),
    );
  }
}

/// The whole history as a heatmap to scroll through sideways and pinch to
/// zoom (from more than a year on screen down to about ten weeks), with
/// − / + buttons for the same. Opens at today.
class ZoomableHeatmap extends StatefulWidget {
  final List<DayRecord> days;
  final int weekStart;
  final DateTime? selected;
  final ValueChanged<DateTime>? onSelect;

  /// Called when a two-finger pinch starts and ends, so a page around it
  /// can stop scrolling meanwhile.
  final ValueChanged<bool>? onPinching;

  const ZoomableHeatmap({
    super.key,
    required this.days,
    required this.weekStart,
    this.selected,
    this.onSelect,
    this.onPinching,
  });

  static const minCell = 5.0;
  static const maxCell = 30.0;
  static const startCell = 14.0;
  static const labelWidth = 18.0;
  static const monthHeight = 18.0;

  @override
  State<ZoomableHeatmap> createState() => ZoomableHeatmapState();
}

class ZoomableHeatmapState extends State<ZoomableHeatmap> {
  final _scroll = ScrollController();
  double _cell = ZoomableHeatmap.startCell;

  /// The square's size now.
  double get cell => _cell;

  final _pointers = <int, Offset>{};
  double? _pinchStartSpan;
  double _pinchStartCell = 0;

  /// The column under the pinch, kept under the fingers as the zoom changes.
  double _anchorColumn = 0;
  double _anchorX = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool get _pinching => _pinchStartSpan != null;

  void _zoomAround(double cell, double column, double anchorX) {
    setState(() => _cell = cell.clamp(ZoomableHeatmap.minCell, ZoomableHeatmap.maxCell));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final target = column * (_cell + Heatmap.gap) - anchorX;
      _scroll.jumpTo(target.clamp(0.0, _scroll.position.maxScrollExtent));
    });
  }

  /// One step in or out with the buttons, around the middle of the view.
  void step({required bool zoomIn}) {
    final viewport = _scroll.hasClients ? _scroll.position.viewportDimension : 0.0;
    final offset = _scroll.hasClients ? _scroll.offset : 0.0;
    final anchorX = viewport / 2;
    _zoomAround(_cell * (zoomIn ? 1.5 : 1 / 1.5), (offset + anchorX) / (_cell + Heatmap.gap), anchorX);
  }

  double _span() {
    final points = _pointers.values.toList();
    return (points[0] - points[1]).distance;
  }

  void _down(PointerDownEvent event) {
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length == 2) {
      _pinchStartSpan = math.max(1, _span());
      _pinchStartCell = _cell;
      final focal = (_pointers.values.first + _pointers.values.last) / 2;
      _anchorX = focal.dx - ZoomableHeatmap.labelWidth;
      _anchorColumn = ((_scroll.hasClients ? _scroll.offset : 0) + _anchorX) / (_cell + Heatmap.gap);
      widget.onPinching?.call(true);
      setState(() {}); // stops the scroll view dragging
    }
  }

  void _move(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.localPosition;
    if (_pinching && _pointers.length == 2) {
      _zoomAround(_pinchStartCell * _span() / _pinchStartSpan!, _anchorColumn, _anchorX);
    }
  }

  void _up(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pinching && _pointers.length < 2) {
      _pinchStartSpan = null;
      widget.onPinching?.call(false);
      setState(() {});
    }
  }

  /// The layout and VoiceOver's month summaries, worked out once per set of
  /// days (not on every pinch move).
  _Layout? _layout;
  List<({int fromColumn, int toColumn, String label})> _months = const [];

  _Layout _layoutFor(List<DayRecord> days, int weekStart) {
    final layout = _layout;
    if (layout != null && identical(layout.days, days) && layout.weekStart == weekStart) return layout;
    _months = _monthSummaries(_layout = _Layout(days, weekStart));
    return _layout!;
  }

  static final _monthFull = DateFormat.MMMM();
  static final _monthShort = DateFormat.MMM();
  static final _monthAndYear = DateFormat.yMMMM();

  @override
  Widget build(BuildContext context) {
    if (widget.days.isEmpty) return const SizedBox.shrink();
    final palette = AppPalette.of(context);
    final layout = _layoutFor(widget.days, widget.weekStart);
    final cell = _cell;
    final gridHeight = _Layout.height(cell);
    const monthHeight = ZoomableHeatmap.monthHeight;
    final labelStyle = TextStyle(fontSize: 11, height: 1, color: palette.textSecondary);
    // Full month names when there's room, and the year where it starts
    String monthName(DateTime month, bool first) {
      final name = cell >= 12 ? _monthFull.format(month) : _monthShort.format(month);
      return first || month.month == 1 ? '$name ${month.year}' : name;
    }

    final labels = _monthLabels(layout, cell, monthName, charWidth: 6.5);
    final months = _months;

    return MediaQuery.withNoTextScaling(
      child: Listener(
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _WeekdayLabels(weekStart: widget.weekStart, cell: cell, width: ZoomableHeatmap.labelWidth, top: monthHeight),
          Expanded(
            child: SingleChildScrollView(
              key: const Key('heatmapScroll'),
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              physics: _pinching ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
              child: SizedBox(
                width: layout.width(cell),
                height: monthHeight + gridHeight,
                child: Stack(clipBehavior: Clip.none, children: [
                  for (final (x, text) in labels)
                    Positioned(
                      left: x,
                      top: 0,
                      child: ExcludeSemantics(child: Text(text, key: Key('heatmapMonth_$text'), style: labelStyle)),
                    ),
                  Positioned(
                    left: 0,
                    top: monthHeight,
                    child: GestureDetector(
                      key: const Key('heatmapGrid'),
                      behavior: HitTestBehavior.opaque,
                      onTapUp: widget.onSelect == null
                          ? null
                          : (details) {
                              final day = layout.dayAt(details.localPosition, cell);
                              if (day != null) widget.onSelect!(day);
                            },
                      // Its own layer: scrolling moves it rather than painting every square again
                      child: RepaintBoundary(
                        child: ExcludeSemantics(
                          child: CustomPaint(
                            size: Size(layout.width(cell), gridHeight),
                            painter: _HeatmapPainter(
                              layout: layout,
                              cell: cell,
                              palette: palette,
                              selected: widget.selected,
                              yearLines: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // VoiceOver reads it a month at a time
                  for (final m in months)
                    Positioned(
                      left: m.fromColumn * (cell + Heatmap.gap),
                      width: math.max(1, (m.toColumn - m.fromColumn + 1) * (cell + Heatmap.gap) - Heatmap.gap),
                      top: monthHeight,
                      height: gridHeight,
                      child: IgnorePointer(child: Semantics(container: true, label: m.label)),
                    ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  static List<({int fromColumn, int toColumn, String label})> _monthSummaries(_Layout layout) {
    final byMonth = <DateTime, List<DayRecord>>{};
    for (final record in layout.days) {
      (byMonth[DateTime(record.day.year, record.day.month)] ??= []).add(record);
    }
    return [
      for (final MapEntry(key: month, value: records) in byMonth.entries)
        (
          fromColumn: layout.column(records.first.day),
          toColumn: layout.column(records.last.day),
          label: _monthLabel(month, records),
        ),
    ];
  }

  static String _monthLabel(DateTime month, List<DayRecord> records) {
    final counted = records.where((r) => !r.isEmpty).length;
    final kept = records.where((r) => !r.isEmpty && r.level > 0).length;
    final perfect = records.where((r) => r.perfect).length;
    return '${_monthAndYear.format(month)}: '
        '${counted == 0 ? 'nothing due' : 'something kept on $kept of $counted days, $perfect perfect'}';
  }
}

class _HeatmapPainter extends CustomPainter {
  final _Layout layout;
  final double cell;
  final AppPalette palette;
  final DateTime? selected;

  /// A faint line where each year begins.
  final bool yearLines;

  _HeatmapPainter({
    required this.layout,
    required this.cell,
    required this.palette,
    this.selected,
    this.yearLines = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shades = Heatmap.shades(palette);
    final radius = Radius.circular(math.max(1.5, cell / 4));
    Rect rectFor(DateTime day) => Rect.fromLTWH(
          layout.column(day) * (cell + Heatmap.gap),
          layout.row(day) * (cell + Heatmap.gap),
          cell,
          cell,
        );

    if (yearLines) {
      final line = Paint()
        ..color = palette.textSecondary.withValues(alpha: 0.35)
        ..strokeWidth = 1;
      for (final (column, month) in layout.monthStarts()) {
        if (month.month != 1 || column == 0) continue;
        final x = column * (cell + Heatmap.gap) - Heatmap.gap / 2;
        canvas.drawLine(Offset(x, -4), Offset(x, size.height + 2), line);
      }
    }

    final fill = Paint();
    final stroke = Paint()..style = PaintingStyle.stroke;
    for (final record in layout.days) {
      final rect = RRect.fromRectAndRadius(rectFor(record.day), radius);
      fill.color = record.isEmpty ? shades[0].withValues(alpha: 0.5) : shades[Heatmap.shadeOf(record)];
      canvas.drawRRect(rect, fill);
      // Only frozen (or on vacation) that day: an icy outline, not a miss
      if (record.isEmpty && record.frozen > 0) {
        canvas.drawRRect(
          rect.deflate(0.75),
          stroke
            ..color = palette.ice
            ..strokeWidth = 1.5,
        );
      }
      if (record.perfect) {
        canvas.drawRRect(
          rect.deflate(0.5),
          stroke
            ..color = palette.text.withValues(alpha: 0.85)
            ..strokeWidth = 1,
        );
      }
    }

    // The rest of this week, still to come
    final last = layout.last;
    for (var day = DateTime(last.year, last.month, last.day + 1);
        layout.row(day) != 0;
        day = DateTime(day.year, day.month, day.day + 1)) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rectFor(day).deflate(0.5), radius),
        stroke
          ..color = palette.track
          ..strokeWidth = 1,
      );
    }

    final chosen = selected;
    if (chosen != null && !chosen.isBefore(layout.first) && !chosen.isAfter(last)) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rectFor(chosen).inflate(1.5), radius),
        stroke
          ..color = palette.text
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) =>
      old.layout.days != layout.days || old.cell != cell || old.selected != selected || old.palette != palette;
}
