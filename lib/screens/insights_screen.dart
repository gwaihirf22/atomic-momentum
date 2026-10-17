import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_style.dart';
import '../presentation/widgets/large_title_scaffold.dart';

/// Statistics' home. Until statistics is built, it says what's coming.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  static const _coming = [
    (CupertinoIcons.square_grid_4x3_fill, 'Year heatmap', 'Every day of the year at a glance'),
    (CupertinoIcons.calendar_today, 'Weekly review', 'What went well, and what to adjust'),
    (CupertinoIcons.timer, 'Two-minute days', 'How often the small version kept you going'),
    (CupertinoIcons.gift_fill, 'Rewards', 'Earn freeze and break days by keeping streaks'),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return LargeTitleScaffold(
      title: 'Insights',
      backgroundColor: palette.background,
      header: const LargeTitleHeader(title: 'Insights', titleKey: Key('insightsTitle')),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppStyle.screenPadding, 8, AppStyle.screenPadding, 16),
          sliver: SliverList.list(
            children: [
              Text(
                'Coming next',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: palette.textSecondary),
              ),
              const SizedBox(height: 8),
              DecoratedBox(
                key: const Key('insightsComingSoon'),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(AppStyle.cardRadius),
                ),
                child: Column(
                  children: [
                    for (final (icon, title, subtitle) in _coming)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: palette.goldTint,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(icon, size: 19, color: palette.gold),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title,
                                      style:
                                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: palette.text)),
                                  Text(subtitle, style: TextStyle(fontSize: 13, color: palette.textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
