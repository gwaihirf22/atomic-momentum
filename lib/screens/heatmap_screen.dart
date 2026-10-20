import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_style.dart';
import '../domain/entities/habit.dart';
import '../domain/services/insights.dart';
import '../presentation/providers/habit_provider.dart';
import '../presentation/providers/settings_provider.dart';
import '../presentation/widgets/adaptive.dart';
import '../presentation/tour/tour_gate.dart';
import '../presentation/widgets/heatmap.dart';
import '../presentation/widgets/large_title_scaffold.dart';
import '../presentation/widgets/stat_card.dart';

/// Every day of the whole history as a heatmap: scroll back through it,
/// pinch (or − / +) to zoom, tap a day to see how it went.
class HeatmapScreen extends StatefulWidget {
  /// One habit, or null for all.
  final String? habitId;

  const HeatmapScreen({super.key, this.habitId});

  /// Always at least this much is shown, so a new habit isn't a sliver.
  static const minWeeks = 26;

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  final _zoom = GlobalKey<ZoomableHeatmapState>();
  late String? _habitId = widget.habitId;
  DateTime? _selected;
  bool _pinching = false;

  Future<void> _pickHabit(List<Habit> habits) async {
    const all = '';
    final picked = await chooseAdaptive<String>(
      context,
      title: 'Show',
      options: [
        const AdaptiveOption(all, 'All habits', key: Key('heatmapHabit_all')),
        for (final habit in habits) AdaptiveOption(habit.id, habit.name, key: Key('heatmapPick_${habit.id}')),
      ],
    );
    if (picked != null) setState(() => _habitId = picked == all ? null : picked);
  }

  /// The days shown, kept while the habits and the day stay the same: a tap
  /// on a day or a pinch doesn't work them out again (and keeps the grid's
  /// layout, so it isn't laid out again either).
  ({List<Habit> habits, DateTime from, DateTime today, List<DayRecord> days})? _days;

  List<DayRecord> _daysFor(List<Habit> habits, DateTime from, DateTime today, DateTime now) {
    final last = _days;
    if (last != null &&
        last.from == from &&
        last.today == today &&
        last.habits.length == habits.length &&
        [for (var i = 0; i < habits.length; i++) identical(last.habits[i], habits[i])].every((same) => same)) {
      return last.days;
    }
    final days = Insights.days(habits, from: from, to: today, now: now);
    _days = (habits: habits, from: from, today: today, days: days);
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final weekStart = context.watch<SettingsProvider>().firstDayOfWeek;
    final habits = context.watch<HabitProvider>().habits.where((h) => h.schedule.isPeriodic).toList();
    final chosen = _habitId == null ? habits : habits.where((h) => h.id == _habitId).toList();
    final name = chosen.length == 1 && _habitId != null ? chosen.single.name : 'All habits';

    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisWeek = DateTime(today.year, today.month, today.day - (today.weekday - weekStart + 7) % 7);
    var from = DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7 * (HeatmapScreen.minWeeks - 1));
    for (final habit in chosen) {
      if (habit.trackedFrom.isBefore(from)) from = habit.trackedFrom;
    }
    final days = _daysFor(chosen, from, today, now);
    final record = _selected == null ? null : days.where((d) => d.day == _selected).firstOrNull;
    final shades = Heatmap.shades(palette);

    Widget swatch(Color color, {bool outlined = false}) => Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: outlined ? Border.all(color: palette.text, width: 1.5) : null,
          ),
        );

    Widget zoomButton(IconData icon, String label, Key key, bool zoomIn) => Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          onTap: () => _zoom.currentState?.step(zoomIn: zoomIn),
          child: TextButton(
            key: key,
            onPressed: () => _zoom.currentState?.step(zoomIn: zoomIn),
            style: TextButton.styleFrom(
              foregroundColor: palette.text,
              backgroundColor: palette.raised,
              minimumSize: const Size(52, 44),
              shape: const StadiumBorder(),
            ),
            child: Icon(icon, size: 18),
          ),
        );

    return LargeTitleScaffold(
      title: 'Every day',
      backgroundColor: palette.background,
      physics: _pinching ? const NeverScrollableScrollPhysics() : null,
      header: const LargeTitleHeader(title: 'Every day', titleKey: Key('heatmapTitle')),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppStyle.screenPadding, 4, AppStyle.screenPadding, 24),
          sliver: SliverList.list(children: [
            Align(
              alignment: Alignment.centerLeft,
              child: PillButton(
                key: const Key('heatmapHabitPicker'),
                label: name,
                icon: CupertinoIcons.chevron_down,
                onPressed: () => _pickHabit(habits),
              ),
            ),
            const SizedBox(height: 12),
            StatCard(
              padding: const EdgeInsets.fromLTRB(12, 14, 0, 14),
              child: ZoomableHeatmap(
                key: _zoom,
                days: days,
                weekStart: weekStart,
                selected: _selected,
                onSelect: (day) => setState(() => _selected = day == _selected ? null : day),
                onPinching: (pinching) => setState(() => _pinching = pinching),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              record != null ? heatmapDaySummary(record) : 'Tap a day to see it. Pinch or use − and + to zoom.',
              key: const Key('heatmapDaySummary'),
              style: TextStyle(
                fontSize: record != null ? 15 : 13,
                fontWeight: record != null ? FontWeight.w600 : FontWeight.w400,
                color: record != null ? palette.text : palette.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Less ', style: TextStyle(fontSize: 13, color: palette.textSecondary)),
                  for (final color in shades) ...[swatch(color), const SizedBox(width: 3)],
                  Text('More', style: TextStyle(fontSize: 13, color: palette.textSecondary)),
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  swatch(shades.last, outlined: true),
                  const SizedBox(width: 5),
                  Text('Perfect day', style: TextStyle(fontSize: 13, color: palette.textSecondary)),
                ]),
              ],
            ),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              zoomButton(CupertinoIcons.minus, 'Zoom out', const Key('heatmapZoomOut'), false),
              const SizedBox(width: 12),
              zoomButton(CupertinoIcons.plus, 'Zoom in', const Key('heatmapZoomIn'), true),
            ]),
          ]),
        ),
      ],
    );
  }
}

/// Opens [HeatmapScreen] (for one habit, or all): the expand button beside
/// a heatmap card's heading.
class HeatmapExpandButton extends StatelessWidget {
  final String? habitId;

  const HeatmapExpandButton({super.key, this.habitId});

  @override
  Widget build(BuildContext context) {
    void open() {
      // Not while a tour's step is waiting for a day to be picked
      if (!TourGate.isFree) return;
      Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => HeatmapScreen(habitId: habitId)));
    }
    return Semantics(
      button: true,
      label: 'Show every day, full screen',
      excludeSemantics: true,
      onTap: open,
      child: GestureDetector(
        key: const Key('heatmapExpand'),
        behavior: HitTestBehavior.opaque,
        onTap: open,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            CupertinoIcons.arrow_up_left_arrow_down_right,
            size: 18,
            color: AppPalette.of(context).textSecondary,
          ),
        ),
      ),
    );
  }
}
