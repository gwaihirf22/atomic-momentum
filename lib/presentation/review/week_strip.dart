import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_palette.dart';
import '../../domain/services/insights.dart';
import '../widgets/heatmap.dart';

/// A week's seven days as squares shaded like the heatmap, each with its
/// weekday's letter under it.
class WeekStrip extends StatelessWidget {
  final List<DayRecord> days;

  /// Another palette than the screen's (a share card's).
  final AppPalette? palette;
  final Color? labelColor;
  final double maxSquare;

  const WeekStrip({super.key, required this.days, this.palette, this.labelColor, this.maxSquare = 40});

  @override
  Widget build(BuildContext context) {
    final palette = this.palette ?? AppPalette.of(context);
    final shades = Heatmap.shades(palette);
    return Semantics(
      label: [
        for (final d in days)
          '${DateFormat.EEEE().format(d.day)}: ${d.isEmpty ? 'nothing due' : '${d.done + d.twoMinute} of ${d.due}'}',
      ].join(', '),
      excludeSemantics: true,
      child: LayoutBuilder(builder: (context, constraints) {
        const gap = 6.0;
        final square = ((constraints.maxWidth - gap * (days.length - 1)) / days.length).clamp(12.0, maxSquare);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final d in days)
              Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: square,
                  height: square,
                  decoration: BoxDecoration(
                    color: d.isEmpty ? Colors.transparent : shades[Heatmap.shadeOf(d)],
                    borderRadius: BorderRadius.circular(square / 4),
                    border: d.isEmpty ? Border.all(color: palette.track, width: 1.5) : null,
                  ),
                ),
                const SizedBox(height: 4),
                // A letter under a square: never scaled up past its width
                MediaQuery.withNoTextScaling(
                  child: Text(
                    DateFormat.EEEEE().format(d.day),
                    style: TextStyle(fontSize: 11, color: labelColor ?? palette.textSecondary),
                  ),
                ),
              ]),
          ],
        );
      }),
    );
  }
}
