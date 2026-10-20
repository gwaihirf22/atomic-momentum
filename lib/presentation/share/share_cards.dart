import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../../core/services/sharer.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/ios_theme.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/momentum.dart';
import '../../domain/services/achievements.dart';
import '../../domain/services/habit_stats.dart';
import '../../domain/services/insights.dart';
import '../../domain/services/weekly_review.dart';
import '../review/week_strip.dart';
import '../review/weekly_review_words.dart';
import '../widgets/achievement_widgets.dart';
import '../widgets/heatmap.dart';
import '../widgets/large_title_scaffold.dart';
import '../widgets/momentum_chart.dart';

/// How a share card looks: the app's three themes, or Ember (the orb's
/// amber gradient).
enum ShareStyle {
  charged('Charged'),
  light('Light'),
  sepia('Sepia'),
  ember('Ember');

  final String label;

  const ShareStyle(this.label);
}

/// A share card's colors for a [ShareStyle]. [palette] themes what's drawn
/// inside (medals, heatmaps, charts).
class ShareLook {
  final ShareStyle style;
  final AppPalette palette;
  final Color? background;
  final Gradient? gradient;
  final Color ink;
  final Color ink2;
  final Color accent;
  final Color good;

  const ShareLook._({
    required this.style,
    required this.palette,
    required this.ink,
    required this.ink2,
    required this.accent,
    required this.good,
    this.background,
    this.gradient,
  });

  bool get isEmber => style == ShareStyle.ember;

  factory ShareLook.of(ShareStyle style) {
    switch (style) {
      case ShareStyle.ember:
        const palette = AppPalette.light;
        return ShareLook._(
          style: style,
          palette: palette,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppPalette.dark.orbStart, AppPalette.dark.orbEnd],
          ),
          ink: AppPalette.onOrb,
          ink2: AppPalette.onOrb.withValues(alpha: 0.72),
          accent: AppPalette.onOrb,
          good: AppPalette.onOrb,
        );
      case ShareStyle.charged || ShareStyle.light || ShareStyle.sepia:
        final palette = switch (style) {
          ShareStyle.light => AppPalette.light,
          ShareStyle.sepia => AppPalette.sepia,
          _ => AppPalette.dark,
        };
        return ShareLook._(
          style: style,
          palette: palette,
          background: style == ShareStyle.light ? palette.surface : palette.background,
          ink: palette.text,
          ink2: palette.textSecondary,
          accent: palette.gauge,
          good: palette.good,
        );
    }
  }
}

/// Every share card: 360 × 450 points (1080 × 1350 pixels when shared, the
/// 4:5 portrait Instagram uses), with the app's mark in the bottom right.
class ShareCardFrame extends StatelessWidget {
  static const size = Size(360, 450);

  final ShareLook look;
  final Widget body;

  /// Bottom left, beside the mark ("Oct 17, 2026").
  final String caption;

  const ShareCardFrame({super.key, required this.look, required this.body, required this.caption});

  @override
  Widget build(BuildContext context) {
    final palette = look.palette;
    return MediaQuery.withNoTextScaling(
      child: Theme(
        data: IOSTheme.material(palette),
        child: DefaultTextStyle.merge(
          style: TextStyle(fontSize: 16, color: look.ink, decoration: TextDecoration.none),
          child: Container(
            width: size.width,
            height: size.height,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: look.background,
              gradient: look.gradient,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: body),
              const SizedBox(height: 14),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Text(caption, maxLines: 2, style: TextStyle(fontSize: 14, color: look.ink2)),
                ),
                const SizedBox(width: 10),
                _BrandMark(look: look),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The app icon and its name: "Momentum / on the App Store" (or "habit
/// tracker" before it's there).
class _BrandMark extends StatelessWidget {
  final ShareLook look;

  const _BrandMark({required this.look});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          color: look.isEmber ? AppPalette.onOrb : null,
          gradient: look.isEmber ? null : look.palette.orb,
        ),
        child: Icon(Icons.bolt, size: 20, color: look.isEmber ? look.palette.gauge : AppPalette.onOrb),
      ),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('Momentum', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: look.ink, height: 1.1)),
        Text(
          AppLinks.hasStore ? 'on the App Store' : 'habit tracker',
          style: TextStyle(fontSize: 12, color: look.ink2, height: 1.2),
        ),
      ]),
    ]);
  }
}

TextStyle _display(ShareLook look, double size, {Color? color}) => TextStyle(
      fontFamily: LargeTitleHeader.fontFamily,
      fontSize: size,
      height: 1.05,
      fontWeight: FontWeight.w700,
      color: color ?? look.ink,
    );

/// What an achievement's card says when the habit's name is hidden: "30 days
/// without smoking" becomes "30 days clean".
String achievementShareTitle(Achievement a, {required bool hideName}) {
  if (!hideName || a.habitName == null) return a.title;
  if (a.kind == AchievementKind.clean) return '${a.badge} ${a.unit.toLowerCase()} clean';
  return a.title.toLowerCase().contains(a.habitName!.toLowerCase()) ? a.title.replaceAll(a.habitName!, 'a habit') : a.title;
}

class AchievementShareCard extends StatelessWidget {
  final Achievement achievement;
  final ShareLook look;
  final bool hideName;

  const AchievementShareCard({super.key, required this.achievement, required this.look, this.hideName = false});

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final title = achievementShareTitle(a, hideName: hideName);
    final showName = !hideName && a.habitName != null && !title.toLowerCase().contains(a.habitName!.toLowerCase());
    return ShareCardFrame(
      key: const Key('shareCard_achievement'),
      look: look,
      caption: DateFormat.yMMMd().format(a.earnedOn),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Spacer(),
        if (look.isEmber)
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: look.ink, width: 4)),
            child: FittedBox(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(a.badge, style: _display(look, 36)),
              ),
            ),
          )
        else
          AchievementMedal(badge: a.badge, unit: a.unit, kind: a.kind, size: 96),
        const SizedBox(height: 18),
        Text(title, maxLines: 3, style: _display(look, 38)),
        if (showName) ...[
          const SizedBox(height: 6),
          Text(a.habitName!, maxLines: 2, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: look.ink2)),
        ],
        const Spacer(),
        Text(a.message, maxLines: 4, style: TextStyle(fontSize: 17, height: 1.35, color: look.ink2)),
      ]),
    );
  }
}

/// A habit's current streak, big, with its last eight weeks (or months).
class StreakShareCard extends StatelessWidget {
  final Habit habit;
  final ShareLook look;
  final bool hideName;
  final DateTime now;

  const StreakShareCard({super.key, required this.habit, required this.look, required this.now, this.hideName = false});

  /// "day streak", "days clean", "in a row".
  static String label(Habit habit, int streak) {
    final unit = habit.resetFrequency.periodUnit;
    if (habit.isBreak) return '${streak == 1 ? unit : '${unit}s'} clean';
    final plain = habit.resetInterval == 1 && !habit.schedule.hasRestDays;
    return plain ? '$unit streak' : 'in a row';
  }

  @override
  Widget build(BuildContext context) {
    final stats = HabitStats.of(habit, now);
    final bars = stats.bars;
    return ShareCardFrame(
      key: const Key('shareCard_streak'),
      look: look,
      caption: '${stats.barsLabel.isEmpty ? '' : '${stats.barsLabel} · '}${DateFormat.MMMd().format(now)}',
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Spacer(),
        if (!hideName)
          Text(habit.name, maxLines: 2, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: look.ink2)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('${stats.streak}', style: _display(look, 108)),
        ),
        Text(label(habit, stats.streak), style: _display(look, 32)),
        const Spacer(),
        if (bars.isNotEmpty)
          SizedBox(
            height: 64,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < bars.length; i++) ...[
                if (i > 0) const SizedBox(width: 7),
                Expanded(
                  child: Container(
                    height: 6 + 58 * bars[i].fraction.clamp(0.0, 1.0),
                    decoration: BoxDecoration(
                      color: look.accent.withValues(alpha: bars[i].fraction > 0 ? 1 : 0.25),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ],
            ]),
          ),
      ]),
    );
  }
}

/// Every day of the last six months (all habits, or one).
class HeatmapShareCard extends StatelessWidget {
  final List<DayRecord> days;
  final int weekStart;
  final ShareLook look;
  final String title;
  final String subtitle;
  final String caption;

  const HeatmapShareCard({
    super.key,
    required this.days,
    required this.weekStart,
    required this.look,
    required this.title,
    required this.subtitle,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return ShareCardFrame(
      key: const Key('shareCard_heatmap'),
      look: look,
      caption: caption,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 8),
        Text(title, maxLines: 2, style: _display(look, 36)),
        const SizedBox(height: 6),
        Text(subtitle, maxLines: 2, style: TextStyle(fontSize: 17, color: look.ink2)),
        const Spacer(),
        Heatmap(days: days, weekStart: weekStart, semanticLabel: title),
        const Spacer(),
      ]),
    );
  }
}

/// This month's overall momentum against last month's, with the months
/// before it.
class MomentumShareCard extends StatelessWidget {
  final List<MonthMomentum> months;
  final Momentum overall;
  final ShareLook look;

  const MomentumShareCard({super.key, required this.months, required this.overall, required this.look});

  @override
  Widget build(BuildContext context) {
    final current = months.last;
    final before = months.length > 1 ? months[months.length - 2] : null;
    final change = before?.score == null ? null : overall.rounded - before!.score!.round();
    final lastMonth = before == null ? '' : DateFormat.MMMM().format(before.month);
    final line = switch (change) {
      null => 'First month of momentum',
      0 => 'Same as $lastMonth',
      > 0 => '+$change from $lastMonth',
      _ => '$change from $lastMonth',
    };
    return ShareCardFrame(
      key: const Key('shareCard_momentum'),
      look: look,
      caption: 'Overall · ${overall.level.label}',
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Spacer(),
        Text(DateFormat.MMMM().format(current.month),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: look.ink2)),
        Text('${overall.rounded}', style: _display(look, 108)),
        Text(line, style: _display(look, 26, color: (change ?? 0) > 0 ? look.good : look.ink2)),
        const Spacer(),
        MomentumChart(months: months, height: 80),
      ]),
    );
  }
}

/// The week in review: how much was kept, the seven days, and the top wins.
class WeekShareCard extends StatelessWidget {
  final WeeklyReview review;
  final ShareLook look;

  /// Habit names left out of the wins ("A habit").
  final bool hideName;

  const WeekShareCard({super.key, required this.review, required this.look, this.hideName = false});

  String _title(WeekWin win) {
    final words = WeeklyReviewWords.win(win);
    return switch (win) {
      EarnedWin(:final achievement) => achievementShareTitle(achievement, hideName: hideName),
      KeptEveryTimeWin() when hideName => 'A habit, every time',
      StreakWin(:final habit, :final length) when hideName => 'A ${habit.schedule.streakLabel(length)}',
      _ => words.title,
    };
  }

  @override
  Widget build(BuildContext context) {
    final wins = review.wins(max: 2);
    return ShareCardFrame(
      key: const Key('shareCard_week'),
      look: look,
      caption: WeeklyReviewWords.momentum(review) == null ? 'My week' : 'Momentum ${WeeklyReviewWords.momentum(review)}',
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('My week', style: _display(look, 30)),
        Text(WeeklyReviewWords.dates(review), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: look.ink2)),
        const Spacer(),
        Text(WeeklyReviewWords.keptShare(review), style: _display(look, 64)),
        Text(WeeklyReviewWords.kept(review), style: _display(look, 20, color: look.ink2)),
        const SizedBox(height: 12),
        WeekStrip(days: review.days, palette: look.palette, labelColor: look.ink2, maxSquare: 30),
        const Spacer(),
        for (final win in wins)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('✦ ${_title(win)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: look.ink)),
          ),
      ]),
    );
  }
}

/// The colors a [ShareStyle] swatch shows in the picker.
BoxDecoration shareSwatch(ShareStyle style) {
  final look = ShareLook.of(style);
  return BoxDecoration(shape: BoxShape.circle, color: look.background, gradient: look.gradient);
}
