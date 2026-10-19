import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';
import '../../domain/services/recent_periods.dart';

/// A habit's last seven days (or weeks, or months) as small bars: full when
/// done, half for the two-minute version, as tall as what was done for a
/// partial one, flat when missed, an outline for the one under way, and a
/// dot for a rest day. Periods before the habit was tracked aren't drawn,
/// so a new habit shows only the days it has had.
class RecentPeriodsBar extends StatelessWidget {
  static const barWidth = 6.0;
  static const barHeight = 16.0;
  static const gap = 3.0;

  final List<RecentPeriod> periods;

  /// The habit's color, as drawn in this theme.
  final Color color;

  /// "day", "week" or "month", for VoiceOver.
  final String unit;

  /// A missed period's color: a slip on a habit being broken shows in the
  /// warning color, taller than the flat track of a plain miss.
  final Color? missedColor;

  const RecentPeriodsBar({super.key, required this.periods, required this.color, required this.unit, this.missedColor});

  /// What VoiceOver reads: "Last 7 days: 5 done, 1 two-minute, 1 missed".
  static String describe(List<RecentPeriod> periods, String unit) {
    int count(PeriodMark mark) => periods.where((p) => p.mark == mark).length;
    final parts = [
      if (count(PeriodMark.done) > 0) '${count(PeriodMark.done)} done',
      if (count(PeriodMark.twoMinute) > 0) '${count(PeriodMark.twoMinute)} two-minute',
      if (count(PeriodMark.partial) > 0) '${count(PeriodMark.partial)} partly done',
      if (count(PeriodMark.missed) > 0) '${count(PeriodMark.missed)} missed',
      if (count(PeriodMark.rest) > 0) '${count(PeriodMark.rest)} rest',
      if (count(PeriodMark.frozen) > 0) '${count(PeriodMark.frozen)} frozen',
    ];
    final tracked = periods.where((p) => p.mark != PeriodMark.untracked).length;
    final span = tracked == 1 ? 'This $unit' : 'Last $tracked ${unit}s';
    return '$span: ${parts.isEmpty ? 'nothing yet' : parts.join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final shown = periods.where((p) => p.mark != PeriodMark.untracked).toList();
    return Semantics(
      label: describe(periods, unit),
      excludeSemantics: true,
      child: SizedBox(
        height: barHeight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              _bar(shown[i], palette),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bar(RecentPeriod period, AppPalette palette) {
    const radius = BorderRadius.all(Radius.circular(2));
    Widget filled(double height, {Color? fill}) => Container(
          width: barWidth,
          height: height,
          decoration: BoxDecoration(color: fill ?? color, borderRadius: radius),
        );

    switch (period.mark) {
      case PeriodMark.untracked:
        return const SizedBox.shrink();
      case PeriodMark.rest:
        return Padding(
          padding: const EdgeInsets.only(bottom: 1),
          child: Container(
            width: barWidth,
            height: 3,
            decoration: BoxDecoration(color: palette.textSecondary.withValues(alpha: 0.35), shape: BoxShape.circle),
          ),
        );
      case PeriodMark.frozen:
        // Held as it was: an icy bar, neither kept nor missed
        return Container(
          width: barWidth,
          height: barHeight,
          decoration: BoxDecoration(
            color: palette.ice.withValues(alpha: 0.25),
            border: Border.all(color: palette.ice, width: 1),
            borderRadius: radius,
          ),
        );
      case PeriodMark.missed:
        return missedColor == null ? filled(3, fill: palette.track) : filled(6, fill: missedColor);
      case PeriodMark.done:
        return filled(barHeight);
      case PeriodMark.twoMinute:
      case PeriodMark.partial:
        return Stack(
          alignment: Alignment.bottomCenter,
          children: [
            filled(barHeight, fill: palette.track),
            filled(_heightFor(period.fraction)),
          ],
        );
      case PeriodMark.current:
        // Under way: an outline, filling with what's done so far
        return Container(
          width: barWidth,
          height: barHeight,
          alignment: Alignment.bottomCenter,
          decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: 0.6), width: 1), borderRadius: radius),
          child: period.fraction > 0
              ? FractionallySizedBox(heightFactor: period.fraction, widthFactor: 1, child: ColoredBox(color: color))
              : null,
        );
    }
  }

  static double _heightFor(double fraction) => (barHeight * fraction).clamp(3.0, barHeight);
}
