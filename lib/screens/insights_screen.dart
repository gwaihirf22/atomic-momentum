import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/locale/week_start.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_style.dart';
import '../domain/entities/habit.dart';
import '../domain/entities/momentum.dart';
import '../domain/services/achievements.dart';
import '../domain/services/insights.dart';
import '../presentation/help/explainers.dart';
import '../presentation/providers/habit_provider.dart';
import '../presentation/providers/settings_provider.dart';
import '../presentation/providers/theme_provider.dart';
import '../presentation/widgets/achievement_widgets.dart';
import '../presentation/share/share_cards.dart';
import '../presentation/share/share_sheet.dart';
import '../presentation/widgets/adaptive.dart';
import '../presentation/widgets/break_wording.dart';
import '../presentation/widgets/heatmap.dart';
import '../presentation/widgets/info_button.dart';
import '../presentation/widgets/large_title_scaffold.dart';
import '../presentation/widgets/momentum_chart.dart';
import '../presentation/widgets/momentum_ring.dart';
import '../presentation/widgets/stat_card.dart';
import 'achievements_screen.dart';
import 'habit_detail_screen.dart';
import 'heatmap_screen.dart';
import 'weekly_review_screen.dart';
import '../presentation/tour/tour_events.dart';
import '../presentation/tour/tour_gate.dart';
import '../presentation/layout/habit_pages.dart';
import '../presentation/layout/card_columns.dart';

/// How far back the Insights cards look, in weeks (about six months).
const insightsWeeks = 26;

/// Statistics' home: momentum over the months, every day as a heatmap,
/// two-minute days, the strongest and hardest weekdays, and each habit.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  /// One habit on the heatmap, or null for all.
  String? _habitId;
  DateTime? _selected;

  _InsightsData? _data;

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild when the appearance changes
    final palette = AppPalette.of(context);
    final weekStart = context.watch<SettingsProvider>().firstDayOfWeek;
    final provider = context.watch<HabitProvider>();
    final habits = provider.habits.where((h) => h.schedule.isPeriodic).toList();
    if (_habitId != null && !habits.any((h) => h.id == _habitId)) _habitId = null;

    final now = clock.now();
    final data = _data = _InsightsData.of(
      habits: habits,
      now: now,
      habitId: _habitId,
      weekStart: weekStart,
      previous: _data,
    );
    final overall = provider.overallMomentum;
    final review = weeklyReviewFor(context, habits);

    return LargeTitleScaffold(
      title: 'Insights',
      backgroundColor: palette.background,
      header: const LargeTitleHeader(title: 'Insights', titleKey: Key('insightsTitle')),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppStyle.screenPadding, 8, AppStyle.screenPadding, 16),
          sliver: SliverList.list(
            children: overall == null
                ? [_EmptyState(palette: palette)]
                : [
                    // Two columns where there's room (iPad); one on a phone
                    CardColumns(children: [
                      // The latest week in review, until the next one
                      if (review != null)
                        WeekSummaryCard(
                          key: const Key('insightsWeeklyReview'),
                          review: review,
                          action: PillButton(
                            key: const Key('insightsSeeWeek'),
                            label: 'See your week',
                            icon: CupertinoIcons.chevron_right,
                            onPressed: () {
                              if (!TourGate.isFree) return;
                              Navigator.of(context)
                                  .push(CupertinoPageRoute<void>(builder: (_) => const WeeklyReviewScreen()));
                            },
                          ),
                        ),
                      _MomentumCard(overall: overall, data: data),
                    ]),
                    const SizedBox(height: 14),
                    // The heatmap takes the whole width
                    _DaysCard(
                      data: data,
                      habits: habits,
                      habitId: _habitId,
                      weekStart: weekStart,
                      selected: _selected,
                      onHabit: (id) => setState(() {
                        _habitId = id;
                        _selected = null;
                      }),
                      onSelect: (day) {
                        TourEvents.emit(const HeatmapDaySelected());
                        setState(() => _selected = day == _selected ? null : day);
                      },
                    ),
                    const SizedBox(height: 14),
                    CardColumns(children: [
                      _TwoMinuteCard(data: data, habits: habits),
                      _WeekCard(data: data, weekStart: weekStart),
                      _AchievementsCard(data: data),
                      _HabitsCard(habits: habits),
                    ]),
                  ],
          ),
        ),
      ],
    );
  }
}

/// What the page shows, worked out once for a set of habits, day, range
/// and choice of habit (kept while none of them change).
class _InsightsData {
  final List<Habit> habits;
  final DateTime today;
  final String? habitId;
  final int weekStart;

  final List<DayRecord> days;
  final List<MonthMomentum> months;
  final KeptSummary kept;
  final WeekdayPattern weekdays;
  final int perfectDays;
  final int timesKept;
  final int longestStreak;
  final int formed;

  /// Earned (for the shelf), newest first, and what's coming next.
  final List<Achievement> achievements;
  final List<AchievementProgress> next;

  _InsightsData._({
    required this.habits,
    required this.today,
    required this.habitId,
    required this.weekStart,
    required this.days,
    required this.months,
    required this.kept,
    required this.weekdays,
    required this.perfectDays,
    required this.timesKept,
    required this.longestStreak,
    required this.formed,
    required this.achievements,
    required this.next,
  });

  static _InsightsData of({
    required List<Habit> habits,
    required DateTime now,
    required String? habitId,
    required int weekStart,
    _InsightsData? previous,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    if (previous != null &&
        previous.today == today &&
        previous.habitId == habitId &&
        previous.weekStart == weekStart &&
        previous.habits.length == habits.length &&
        [for (var i = 0; i < habits.length; i++) identical(previous.habits[i], habits[i])].every((same) => same)) {
      return previous;
    }

    final thisWeek = DateTime(today.year, today.month, today.day - (today.weekday - weekStart + 7) % 7);
    final from = DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7 * (insightsWeeks - 1));
    final chosen = habitId == null ? habits : habits.where((h) => h.id == habitId).toList();
    final days = Insights.days(chosen, from: from, to: today, now: now);
    final allKept = Insights.kept(habits, from: from, now: now);
    final chosenKept = habitId == null ? allKept : Insights.kept(chosen, from: from, now: now);
    return _InsightsData._(
      habits: habits,
      today: today,
      habitId: habitId,
      weekStart: weekStart,
      days: days,
      months: Insights.momentumByMonth(habits, now),
      kept: allKept,
      weekdays: Insights.weekdays(habits, from: from, now: now),
      perfectDays: days.where((d) => d.perfect).length,
      timesKept: chosenKept.kept,
      longestStreak: Insights.longestStreak(chosen),
      formed: Insights.formed(habits),
      achievements:
          Achievements.earned(habits, now, weekStart: weekStart).where((a) => a.onShelf).toList().reversed.toList(),
      next: Achievements.next(habits, now),
    );
  }
}

/// A card's heading with an (i) at the end.
class _Heading extends StatelessWidget {
  final String text;
  final InfoTopic? info;
  final double? momentum;

  /// Shares what the card shows.
  final VoidCallback? onShare;
  final String shareLabel;

  const _Heading(this.text, {this.info, this.momentum, this.onShare, this.shareLabel = 'Share'});

  /// A 44pt button that overhangs the heading rather than pushing the card down.
  static Widget _overhang(Widget button) => SizedBox(
        width: 44,
        height: 24,
        child: OverflowBox(minWidth: 44, maxWidth: 44, minHeight: 44, maxHeight: 44, child: button),
      );

  @override
  Widget build(BuildContext context) {
    final heading = StatCardHeading(text);
    if (info == null && onShare == null) return heading;
    return Row(children: [
      Expanded(child: heading),
      Transform.translate(
        offset: const Offset(10, 0),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (onShare != null) _overhang(ShareIconButton(key: Key('share_$text'), label: shareLabel, onPressed: onShare!)),
          if (info != null) _overhang(InfoButton(topic: info!, momentum: momentum)),
        ]),
      ),
    ]);
  }
}

class _EmptyState extends StatelessWidget {
  final AppPalette palette;

  const _EmptyState({required this.palette});

  @override
  Widget build(BuildContext context) => StatCard(
        key: const Key('insightsEmpty'),
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Icon(CupertinoIcons.chart_bar_alt_fill, size: 44, color: palette.gauge),
          const SizedBox(height: 12),
          Text(
            'Your insights start here',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: LargeTitleHeader.fontFamily,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: palette.text),
          ),
          const SizedBox(height: 6),
          Text(
            'Log a few days of a habit, and your momentum, every day at a glance and your strongest days show here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.4, color: palette.textSecondary),
          ),
        ]),
      );
}

class _MomentumCard extends StatelessWidget {
  final Momentum overall;
  final _InsightsData data;

  const _MomentumCard({required this.overall, required this.data});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final months = data.months;
    final current = months.last;
    final before = months.length > 1 ? months[months.length - 2] : null;
    final change =
        current.score != null && before?.score != null ? (current.score!.round() - before!.score!.round()) : null;
    final lastMonth = before == null ? '' : DateFormat.MMMM().format(before.month);

    final comparison = switch (change) {
      null => 'Your first month of momentum.',
      0 => 'The same as in $lastMonth.',
      > 0 => 'Up from ${before!.score!.round()} in $lastMonth.',
      _ => 'Down from ${before!.score!.round()} in $lastMonth.',
    };
    final formed = switch (data.formed) {
      0 => '80 is the mark where a habit has formed.',
      1 => '1 habit is past 80, the mark where a habit has formed.',
      final n => '$n habits are past 80, the mark where a habit has formed.',
    };

    return StatCard(
      key: const Key('insightsMomentum'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Heading(
          'Momentum',
          info: InfoTopic.momentum,
          momentum: overall.score,
          shareLabel: "Share this month's momentum",
          onShare: () => showShareSheet(
            context,
            card: (look, _) => MomentumShareCard(months: months, overall: overall, look: look),
            fileName: 'momentum.png',
            styles: const [ShareStyle.charged, ShareStyle.light, ShareStyle.sepia],
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          MomentumRing(momentum: overall, size: 84),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(DateFormat.MMMM().format(current.month),
                  style: TextStyle(fontSize: 13, color: palette.textSecondary)),
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: '${overall.rounded}',
                    style: TextStyle(
                        fontFamily: LargeTitleHeader.fontFamily,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: palette.text),
                  ),
                  if (change != null && change != 0)
                    TextSpan(
                      text: ' ${change > 0 ? '+' : ''}$change',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: change > 0 ? palette.good : palette.textSecondary,
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 4),
              Text(
                '$comparison $formed',
                key: const Key('insightsMonthCompare'),
                style: TextStyle(fontSize: 13, height: 1.35, color: palette.textSecondary),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        MomentumChart(key: const Key('insightsMomentumChart'), months: months),
      ]),
    );
  }
}

class _DaysCard extends StatelessWidget {
  final _InsightsData data;
  final List<Habit> habits;
  final String? habitId;
  final int weekStart;
  final DateTime? selected;
  final ValueChanged<String?> onHabit;
  final ValueChanged<DateTime> onSelect;

  const _DaysCard({
    required this.data,
    required this.habits,
    required this.habitId,
    required this.weekStart,
    required this.selected,
    required this.onHabit,
    required this.onSelect,
  });

  Future<void> _pickHabit(BuildContext context) async {
    const all = '';
    final picked = await chooseAdaptive<String>(
      context,
      title: 'Show',
      options: [
        const AdaptiveOption(all, 'All habits', key: Key('insightsHabit_all')),
        for (final habit in habits) AdaptiveOption(habit.id, habit.name, key: Key('insightsPick_${habit.id}')),
      ],
    );
    if (picked != null) onHabit(picked == all ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final chosen = habitId == null ? null : habits.firstWhere((h) => h.id == habitId);
    final shades = Heatmap.shades(palette);
    final record = selected == null ? null : data.days.where((d) => d.day == selected).firstOrNull;
    final kept = data.days.where((d) => !d.isEmpty && d.level > 0).length;

    Widget swatch(Color color, {bool outlined = false}) => Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: outlined ? Border.all(color: palette.text, width: 1.5) : null,
          ),
        );

    Widget stat(String value, String label, Key key) => Expanded(
          child: Semantics(
            label: '$value $label',
            excludeSemantics: true,
            child: Column(key: key, children: [
              Text(value,
                  style: TextStyle(
                      fontFamily: LargeTitleHeader.fontFamily,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: palette.text)),
              Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: palette.textSecondary)),
            ]),
          ),
        );

    return StatCard(
      key: const Key('insightsDays'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        StatCardHeading(
          'Every day',
          action: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
              child: PillButton(
                key: const Key('insightsHabitPicker'),
                label: chosen?.name ?? 'All habits',
                icon: CupertinoIcons.chevron_down,
                // Not while a tour waits for a day to be picked
                onPressed: () => TourGate.isFree ? _pickHabit(context) : null,
              ),
            ),
            ShareIconButton(
              key: const Key('share_Every day'),
              label: 'Share the last 6 months',
              onPressed: () => !TourGate.isFree ? null : showShareSheet(
                context,
                card: (look, hideName) => HeatmapShareCard(
                  days: data.days,
                  weekStart: weekStart,
                  look: look,
                  title: 'Last 6 months',
                  subtitle: '${data.timesKept} times kept · ${data.perfectDays} perfect days',
                  caption: chosen == null ? 'All habits' : (hideName ? 'One habit' : chosen.name),
                ),
                fileName: 'momentum-every-day.png',
                styles: const [ShareStyle.charged, ShareStyle.light, ShareStyle.sepia],
                canHideName: chosen != null,
                hideNameByDefault: chosen?.isBreak ?? false,
              ),
            ),
            HeatmapExpandButton(habitId: habitId),
          ]),
        ),
        Text('Last 6 months', style: TextStyle(fontSize: 12, color: palette.textSecondary)),
        const SizedBox(height: 12),
        Heatmap(
          key: const Key('insightsHeatmap'),
          days: data.days,
          weekStart: weekStart,
          selected: selected,
          onSelect: onSelect,
          semanticLabel:
              '${chosen?.name ?? 'All habits'}, last 6 months: '
              'something kept on $kept days, ${data.perfectDays} perfect days',
        ),
        const SizedBox(height: 8),
        if (record != null)
          Text(
            heatmapDaySummary(record),
            key: const Key('heatmapDaySummary'),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: palette.text),
          )
        else
          Text('Tap a day to see it.', style: TextStyle(fontSize: 13, color: palette.textSecondary)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Less ', style: TextStyle(fontSize: 12, color: palette.textSecondary)),
              for (final color in shades) ...[swatch(color), const SizedBox(width: 3)],
              Text('More', style: TextStyle(fontSize: 12, color: palette.textSecondary)),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              swatch(shades.last, outlined: true),
              const SizedBox(width: 5),
              Text('Perfect day', style: TextStyle(fontSize: 12, color: palette.textSecondary)),
            ]),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Divider(height: 0.5, thickness: 0.5, color: palette.separator),
        ),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          stat('${data.timesKept}', 'times kept', const Key('insightsTimesKept')),
          stat('${data.perfectDays}', 'perfect days', const Key('insightsPerfectDays')),
          stat('${data.longestStreak}', 'longest streak', const Key('insightsLongestStreak')),
        ]),
      ]),
    );
  }

}

class _TwoMinuteCard extends StatelessWidget {
  final _InsightsData data;
  final List<Habit> habits;

  const _TwoMinuteCard({required this.data, required this.habits});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final kept = data.kept;
    final anyTiny = habits.any((h) => h.twoMinute != null && !h.isBreak);

    Widget box(String value, String label, Color background, Color valueColor, Key key) => Expanded(
          child: Container(
            key: key,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: TextStyle(
                      fontFamily: LargeTitleHeader.fontFamily,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: valueColor)),
              Text(label, style: TextStyle(fontSize: 13, height: 1.3, color: palette.text)),
            ]),
          ),
        );

    final share = kept.total == 0 ? null : (full: kept.full / kept.total, tiny: kept.twoMinute / kept.total);
    String percent(double value) => '${(value * 100).round()}%';

    return StatCard(
      key: const Key('insightsTwoMinute'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const _Heading('Two-minute days', info: InfoTopic.twoMinute),
        Text('Last 6 months', style: TextStyle(fontSize: 12, color: palette.textSecondary)),
        const SizedBox(height: 12),
        if (!anyTiny && kept.twoMinute == 0)
          Text(
            "Give a habit a two-minute version for hard days, and the days it keeps you going are counted here.",
            key: const Key('insightsTwoMinuteHint'),
            style: TextStyle(fontSize: 14, height: 1.4, color: palette.textSecondary),
          )
        else ...[
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              box('${kept.twoMinute}', 'hard days you still showed up', palette.raised, palette.text,
                  const Key('insightsTwoMinuteDays')),
              const SizedBox(width: 10),
              box('${kept.streaksSaved}', kept.streaksSaved == 1 ? 'streak they saved' : 'streaks they saved',
                  palette.goldTint, palette.gold, const Key('insightsStreaksSaved')),
            ]),
          ),
          if (share != null) ...[
            const SizedBox(height: 12),
            Semantics(
              label: 'Full days ${percent(share.full)}, two-minute ${percent(share.tiny)}, '
                  'missed ${percent(1 - share.full - share.tiny)}',
              excludeSemantics: true,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 12,
                    child: Row(children: [
                      if (kept.full > 0) Expanded(flex: kept.full, child: ColoredBox(color: palette.gauge)),
                      if (kept.twoMinute > 0)
                        Expanded(
                            flex: kept.twoMinute, child: ColoredBox(color: palette.tint(palette.gauge, alpha: 0.5))),
                      if (kept.missed > 0) Expanded(flex: kept.missed, child: ColoredBox(color: palette.track)),
                    ]),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(spacing: 14, runSpacing: 4, children: [
                  _Legend(palette.gauge, 'Full days ${percent(share.full)}'),
                  _Legend(palette.tint(palette.gauge, alpha: 0.5), 'Two-minute ${percent(share.tiny)}'),
                  _Legend(palette.track, 'Missed ${percent(1 - share.full - share.tiny)}'),
                ]),
              ]),
            ),
          ],
        ],
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String text;

  const _Legend(this.color, this.text);

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(fontSize: 12, color: AppPalette.of(context).textSecondary)),
      ]);
}

class _WeekCard extends StatelessWidget {
  final _InsightsData data;
  final int weekStart;

  const _WeekCard({required this.data, required this.weekStart});

  /// A weekday's bar from 0 to 1. Rates are usually close together, so the
  /// bars start a little below the lowest; the percentages say the rest.
  static double _scaled(WeekdayPattern pattern, int day) {
    final rates = pattern.rates.values;
    final floor = (rates.reduce((a, b) => a < b ? a : b) - 0.15).clamp(0.0, 1.0);
    return floor >= 1 ? 1 : ((pattern.rates[day]! - floor) / (1 - floor)).clamp(0.0, 1.0);
  }

  /// "Tuesdays".
  static String plural(int weekday) => '${DateFormat.EEEE().format(DateTime(2024, 1, weekday))}s';

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final pattern = data.weekdays;
    final best = pattern.best;
    final hardest = pattern.hardest;

    return StatCard(
      key: const Key('insightsWeek'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const StatCardHeading('Your week'),
        const SizedBox(height: 12),
        if (pattern.isEmpty)
          Text(
            'After a few weeks of daily habits, your strongest and hardest days show here.',
            key: const Key('insightsWeekHint'),
            style: TextStyle(fontSize: 14, height: 1.4, color: palette.textSecondary),
          )
        else ...[
          Semantics(
            label: [
              for (final day in weekdaysStartingOn(weekStart))
                '${DateFormat.EEEE().format(DateTime(2024, 1, day))} ${(pattern.rates[day]! * 100).round()}%',
            ].join(', '),
            excludeSemantics: true,
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: SizedBox(
                // The tallest bar and both labels, at the clamped 130% text
                height: 114,
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (final day in weekdaysStartingOn(weekStart))
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                          Text(
                            '${(pattern.rates[day]! * 100).round()}%',
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: day == best ? palette.text : palette.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 8 + 54 * _scaled(pattern, day),
                            decoration: BoxDecoration(
                              color: day == best
                                  ? palette.gauge
                                  : day == hardest
                                      ? palette.tint(palette.gauge, alpha: 0.3)
                                      : palette.raised,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'MTWTFSS'[day - 1],
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: palette.textSecondary),
                          ),
                        ]),
                      ),
                    ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            best == hardest
                ? 'Every day of the week goes about the same.'
                : '${plural(best!)} are your strongest day. ${plural(hardest!)} are the hardest'
                    '${pattern.rates[hardest]! < 0.7 ? ': a two-minute version could help there.' : '.'}',
            key: const Key('insightsWeekSummary'),
            style: TextStyle(fontSize: 13, height: 1.4, color: palette.textSecondary),
          ),
        ],
      ]),
    );
  }
}

class _AchievementsCard extends StatelessWidget {
  final _InsightsData data;

  const _AchievementsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final earned = data.achievements;
    final next = data.next;
    return StatCard(
      key: const Key('insightsAchievements'),
      padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: StatCardHeading(
            'Achievements',
            action: PillButton(
              key: const Key('insightsSeeAllAchievements'),
              label: earned.isEmpty ? 'See what\'s ahead' : 'See all ${earned.length}',
              onPressed: () => Navigator.of(context)
                  .push(CupertinoPageRoute<void>(builder: (_) => const AchievementsScreen())),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (earned.isEmpty && next.isEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text('Keep going: the first is a week in a row.',
                style: TextStyle(fontSize: 14, color: palette.textSecondary)),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final a in earned.take(8)) ...[
                AchievementTile.earned(
                  a,
                  onTap: () => showAchievementSheet(
                    context,
                    a,
                    next: next.where((p) => p.habitName != null && p.habitName == a.habitName).firstOrNull,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              for (final p in next.take(3)) ...[
                AchievementTile.next(p),
                const SizedBox(width: 10),
              ],
            ]),
          ),
      ]),
    );
  }
}

class _HabitsCard extends StatelessWidget {
  final List<Habit> habits;

  const _HabitsCard({required this.habits});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final sorted = [...habits]..sort((a, b) => b.momentum.score.compareTo(a.momentum.score));

    return StatCard(
      key: const Key('insightsHabits'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const StatCardHeading('Habits'),
        const SizedBox(height: 6),
        for (final habit in sorted) _HabitRow(habit: habit, palette: palette),
      ]),
    );
  }
}

class _HabitRow extends StatelessWidget {
  final Habit habit;
  final AppPalette palette;

  const _HabitRow({required this.habit, required this.palette});

  @override
  Widget build(BuildContext context) {
    final color = palette.habitColor(habit.color.color);
    final streak = habit.streak.current;
    final sub = streak == 0
        ? 'No streak right now'
        : habit.isBreak
            ? BreakWording.streak(habit, streak)
            : habit.schedule.streakLabel(streak);
    final momentum = habit.momentum;

    return Semantics(
      button: true,
      label: '${habit.name}, $sub, momentum ${momentum.rounded}, ${momentum.level.label}',
      excludeSemantics: true,
      onTap: () => _open(context),
      child: InkWell(
        key: Key('insightsHabit_${habit.id}'),
        onTap: () => _open(context),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: palette.separator, width: 0.5))),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration:
                  BoxDecoration(color: palette.tint(habit.color.color), borderRadius: BorderRadius.circular(11)),
              alignment: Alignment.center,
              child: Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  habit.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: palette.text),
                ),
                Text(sub, style: TextStyle(fontSize: 12, color: palette.textSecondary)),
              ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${momentum.rounded}',
                  style: TextStyle(
                      fontFamily: LargeTitleHeader.fontFamily,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: palette.text)),
              Text(momentum.level.label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: palette.gauge)),
            ]),
            const SizedBox(width: 6),
            Icon(CupertinoIcons.chevron_right, size: 14, color: palette.textSecondary),
          ]),
        ),
      ),
    );
  }

  void _open(BuildContext context) => HabitPages.open(context, habit.id);
}
