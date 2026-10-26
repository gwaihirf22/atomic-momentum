import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/app_style.dart';
import '../domain/entities/habit.dart';
import '../domain/services/weekly_review.dart';
import '../presentation/providers/category_provider.dart';
import '../presentation/providers/habit_provider.dart';
import '../presentation/providers/settings_provider.dart';
import '../presentation/review/week_strip.dart';
import '../presentation/review/weekly_review_words.dart';
import '../presentation/share/share_cards.dart';
import '../presentation/share/share_sheet.dart';
import '../presentation/widgets/achievement_widgets.dart';
import '../presentation/widgets/habit_icons.dart';
import '../presentation/widgets/large_title_scaffold.dart';
import '../presentation/widgets/orb_button.dart';
import '../presentation/widgets/stat_card.dart';
import '../presentation/layout/app_layout.dart';

/// The latest week in review for [habits] and the person's settings.
WeeklyReview? weeklyReviewFor(BuildContext context, List<Habit> habits) {
  final settings = context.watch<SettingsProvider>();
  final time = settings.weeklyReviewTime;
  return WeeklyReview.of(
    habits.where((h) => h.schedule.isPeriodic).toList(),
    now: clock.now(),
    weekStart: settings.firstDayOfWeek,
    reviewTime: (hour: time.hour, minute: time.minute),
  );
}

/// The week in review (Insights, or the notification on the week's last
/// evening): how it went, the wins, the times a habit didn't miss twice,
/// and a picture of it to share.
class WeeklyReviewScreen extends StatelessWidget {
  const WeeklyReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final review = weeklyReviewFor(context, context.watch<HabitProvider>().habits);

    return LargeTitleScaffold(
      maxContentWidth: AppLayout.readableMax,
      title: 'Your week',
      backgroundColor: palette.background,
      header: LargeTitleHeader(
        eyebrow: review == null ? null : WeeklyReviewWords.dates(review).toUpperCase(),
        title: 'Your week',
        titleKey: const Key('weeklyReviewTitle'),
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppStyle.screenPadding, 8, AppStyle.screenPadding, 24),
          sliver: SliverList.list(
            children: review == null
                ? [
                    StatCard(
                      child: Text(
                        "Your first week isn't in yet. On its last evening I'll sum it up here.",
                        style: TextStyle(fontSize: 15, height: 1.4, color: palette.textSecondary),
                      ),
                    ),
                  ]
                : [
                    WeekSummaryCard(review: review),
                    const SizedBox(height: 14),
                    _WinsCard(review: review),
                    const SizedBox(height: 14),
                    _ComebacksCard(review: review),
                    const SizedBox(height: 20),
                    Center(
                      child: OrbButton(
                        key: const Key('weeklyReviewShare'),
                        label: 'Share your week',
                        onPressed: () => showShareSheet(
                          context,
                          card: (look, hideName) => WeekShareCard(review: review, look: look, hideName: hideName),
                          fileName: 'momentum-week.png',
                          canHideName: review.wins(max: 3).isNotEmpty,
                          hideNameByDefault: review.keptEveryTime.any((k) => k.habit.isBreak),
                        ),
                      ),
                    ),
                  ],
          ),
        ),
      ],
    );
  }
}

/// How the week went: kept, perfect and two-minute days, momentum, and the
/// seven days. Also the Insights card's body.
class WeekSummaryCard extends StatelessWidget {
  final WeeklyReview review;

  /// Below it, on Insights: "See your week".
  final Widget? action;

  const WeekSummaryCard({super.key, required this.review, this.action});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final days = WeeklyReviewWords.days(review);
    final momentum = WeeklyReviewWords.momentum(review);
    final share = review.kept.total == 0 ? 0.0 : review.kept.kept / review.kept.total;
    return StatCard(
      key: const Key('weeklyReviewSummary'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        StatCardHeading(action == null ? 'How it went' : 'Your week · ${WeeklyReviewWords.dates(review)}'),
        const SizedBox(height: 12),
        Row(children: [
          _KeptRing(share: share, label: WeeklyReviewWords.keptShare(review)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                WeeklyReviewWords.kept(review),
                style: TextStyle(
                  fontFamily: LargeTitleHeader.fontFamily,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                ),
              ),
              if (days != null) Text(days, style: TextStyle(fontSize: 14, color: palette.textSecondary)),
              if (momentum != null)
                Text.rich(
                  TextSpan(children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Icon(CupertinoIcons.bolt_fill, size: 14, color: palette.gauge),
                    ),
                    TextSpan(text: ' $momentum'),
                  ]),
                  style: TextStyle(fontSize: 14, color: palette.textSecondary),
                ),
              if (review.underWay)
                Text(WeeklyReviewWords.tonight, style: TextStyle(fontSize: 13, color: palette.textSecondary)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        WeekStrip(days: review.days),
        if (action != null) ...[const SizedBox(height: 12), Align(alignment: Alignment.centerLeft, child: action!)],
      ]),
    );
  }
}

/// The share of the week's periods kept, as a ring with its percentage.
class _KeptRing extends StatelessWidget {
  final double share;
  final String label;

  const _KeptRing({required this.share, required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox.expand(
          child: CircularProgressIndicator(
            value: share,
            strokeWidth: 8,
            strokeCap: StrokeCap.round,
            color: palette.gauge,
            backgroundColor: palette.track,
          ),
        ),
        MediaQuery.withNoTextScaling(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: LargeTitleHeader.fontFamily,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: palette.text,
            ),
          ),
        ),
      ]),
    );
  }
}

class _WinsCard extends StatelessWidget {
  final WeeklyReview review;

  const _WinsCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final categories = context.read<CategoryProvider>();
    final wins = review.wins();
    return StatCard(
      key: const Key('weeklyReviewWins'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const StatCardHeading('Wins'),
        const SizedBox(height: 8),
        if (wins.isEmpty)
          Text(WeeklyReviewWords.noWins(review), style: TextStyle(fontSize: 15, height: 1.4, color: palette.textSecondary)),
        for (final win in wins)
          _Row(
            leading: switch (win) {
              EarnedWin(:final achievement) =>
                AchievementMedal(badge: achievement.badge, unit: achievement.unit, kind: achievement.kind, size: 40),
              KeptEveryTimeWin(:final habit) || StreakWin(:final habit) =>
                _Badge(icon: habitIcon(habit, categories.resolve(habit.categoryId)), color: palette.habitColor(habit.color.color)),
              PerfectWeekWin() => _Badge(icon: CupertinoIcons.star_fill, color: palette.gold),
              LevelWin() => _Badge(icon: CupertinoIcons.bolt_fill, color: palette.gauge),
            },
            title: WeeklyReviewWords.win(win).title,
            line: WeeklyReviewWords.win(win).line,
          ),
      ]),
    );
  }
}

class _ComebacksCard extends StatelessWidget {
  final WeeklyReview review;

  const _ComebacksCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final categories = context.read<CategoryProvider>();
    return StatCard(
      key: const Key('weeklyReviewComebacks'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const StatCardHeading("Didn't miss twice"),
        const SizedBox(height: 8),
        if (review.comebacks.isEmpty)
          Text(WeeklyReviewWords.noComebacks(review),
              style: TextStyle(fontSize: 15, height: 1.4, color: palette.textSecondary)),
        for (final c in review.comebacks)
          _Row(
            leading: _Badge(
              icon: habitIcon(c.habit, categories.resolve(c.habit.categoryId)),
              color: palette.habitColor(c.habit.color.color),
            ),
            title: c.habit.name,
            line: WeeklyReviewWords.comeback(c),
          ),
      ]),
    );
  }
}

/// A habit's (or a win's) icon on a tint of its colour.
class _Badge extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _Badge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: AppPalette.of(context).tint(color, alpha: 0.18), shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: color),
      );
}

class _Row extends StatelessWidget {
  final Widget leading;
  final String title;
  final String line;

  const _Row({required this.leading, required this.title, required this.line});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        leading,
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: palette.text)),
            Text(line, style: TextStyle(fontSize: 14, height: 1.35, color: palette.textSecondary)),
          ]),
        ),
      ]),
    );
  }
}
