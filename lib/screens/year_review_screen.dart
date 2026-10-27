import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/app_style.dart';
import '../domain/entities/habit.dart';
import '../domain/services/year_review.dart';
import '../presentation/layout/app_layout.dart';
import '../presentation/providers/habit_provider.dart';
import '../presentation/providers/settings_provider.dart';
import '../presentation/review/year_review_words.dart';
import '../presentation/share/share_cards.dart';
import '../presentation/share/share_sheet.dart';
import '../presentation/widgets/heatmap.dart';
import '../presentation/widgets/large_title_scaffold.dart';
import '../presentation/widgets/orb_button.dart';
import '../presentation/widgets/stat_card.dart';

/// The year in review for [habits] today (the year [YearReview.yearFor] picks).
YearReview? yearReviewFor(BuildContext context, List<Habit> habits) {
  final now = clock.now();
  return YearReview.of(
    habits.where((h) => h.schedule.isPeriodic).toList(),
    year: YearReview.yearFor(now),
    now: now,
    weekStart: context.watch<SettingsProvider>().firstDayOfWeek,
  );
}

/// The year in review (Momentum Plus): how the year went, every day of it,
/// its highlights, and a picture of it to share. From Insights.
class YearReviewScreen extends StatelessWidget {
  const YearReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final review = yearReviewFor(context, context.watch<HabitProvider>().habits);
    final weekStart = context.watch<SettingsProvider>().firstDayOfWeek;
    final title = review == null ? 'Your year' : YearReviewWords.title(review);

    return LargeTitleScaffold(
      maxContentWidth: AppLayout.readableMax,
      title: title,
      backgroundColor: palette.background,
      header: LargeTitleHeader(title: title, titleKey: const Key('yearReviewTitle')),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppStyle.screenPadding, 8, AppStyle.screenPadding, 24),
          sliver: SliverList.list(
            children: review == null
                ? [
                    StatCard(
                      child: Text(
                        "A week of the year tracked, and I'll start summing it up here.",
                        style: TextStyle(fontSize: 15, height: 1.4, color: palette.textSecondary),
                      ),
                    ),
                  ]
                : [
                    YearSummaryCard(review: review),
                    const SizedBox(height: 14),
                    StatCard(
                      key: const Key('yearHeatmap'),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        const StatCardHeading('Every day'),
                        const SizedBox(height: 12),
                        Heatmap(days: review.days, weekStart: weekStart, semanticLabel: 'Every day of ${review.year}'),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    _HighlightsCard(review: review),
                    const SizedBox(height: 20),
                    Center(
                      child: OrbButton(
                        key: const Key('yearReviewShare'),
                        label: 'Share your year',
                        onPressed: () => showShareSheet(
                          context,
                          card: (look, hideName) =>
                              YearShareCard(review: review, weekStart: weekStart, look: look, hideName: hideName),
                          fileName: 'momentum-year.png',
                          // A heatmap: the looks with room for it
                          styles: const [ShareStyle.charged, ShareStyle.light, ShareStyle.sepia],
                          canHideName: YearReviewWords.highlights(review).isNotEmpty,
                          hideNameByDefault: review.bestStreak?.habit.isBreak ?? false,
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

/// How the year went: kept, perfect and two-minute days, momentum. Also the
/// Insights card's body.
class YearSummaryCard extends StatelessWidget {
  final YearReview review;

  /// Below it, on Insights: "See your year".
  final Widget? action;

  const YearSummaryCard({super.key, required this.review, this.action});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final days = YearReviewWords.days(review);
    final momentum = YearReviewWords.momentum(review);
    return StatCard(
      key: const Key('yearReviewSummary'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        StatCardHeading(action == null ? 'How it went' : YearReviewWords.title(review)),
        const SizedBox(height: 12),
        Row(children: [
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: review.keptRate,
                  strokeWidth: 8,
                  strokeCap: StrokeCap.round,
                  color: palette.gauge,
                  backgroundColor: palette.track,
                ),
              ),
              MediaQuery.withNoTextScaling(
                child: Text(
                  YearReviewWords.keptShare(review),
                  style: TextStyle(
                    fontFamily: LargeTitleHeader.fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                YearReviewWords.kept(review),
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
            ]),
          ),
        ]),
        if (action != null) ...[const SizedBox(height: 12), Align(alignment: Alignment.centerLeft, child: action!)],
      ]),
    );
  }
}

class _HighlightsCard extends StatelessWidget {
  final YearReview review;

  const _HighlightsCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final highlights = YearReviewWords.highlights(review);
    return StatCard(
      key: const Key('yearHighlights'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const StatCardHeading('Highlights'),
        const SizedBox(height: 10),
        if (highlights.isEmpty)
          Text(YearReviewWords.noHighlights(review), style: TextStyle(fontSize: 15, color: palette.textSecondary)),
        for (final (title, detail) in highlights)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(CupertinoIcons.star_fill, size: 18, color: palette.gauge),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: palette.text)),
                  Text(detail, style: TextStyle(fontSize: 14, height: 1.35, color: palette.textSecondary)),
                ]),
              ),
            ]),
          ),
      ]),
    );
  }
}
