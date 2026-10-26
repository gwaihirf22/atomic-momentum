import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_style.dart';
import '../domain/services/achievements.dart';
import '../presentation/providers/habit_provider.dart';
import '../presentation/providers/settings_provider.dart';
import '../presentation/widgets/achievement_widgets.dart';
import '../presentation/widgets/large_title_scaffold.dart';

/// Every achievement earned, newest first, and the ones coming up.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final habits = context.watch<HabitProvider>().habits;
    final weekStart = context.watch<SettingsProvider>().firstDayOfWeek;
    final now = clock.now();
    final earned = Achievements.earned(habits, now, weekStart: weekStart).where((a) => a.onShelf).toList().reversed.toList();
    final next = Achievements.next(habits, now);

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10, top: 6),
          child: Semantics(
            header: true,
            child: Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: palette.text)),
          ),
        );

    return LargeTitleScaffold(
      maxContentWidth: 900,
      title: 'Achievements',
      backgroundColor: palette.background,
      header: const LargeTitleHeader(title: 'Achievements', titleKey: Key('achievementsTitle')),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppStyle.screenPadding, 8, AppStyle.screenPadding, 24),
          sliver: SliverList.list(children: [
            heading(earned.isEmpty ? 'Nothing earned yet' : '${earned.length} earned'),
            if (earned.isEmpty)
              Text(
                'Keep going: the first is a week in a row.',
                style: TextStyle(fontSize: 15, color: palette.textSecondary),
              )
            else
              _Grid(tiles: [
                for (final a in earned)
                  (width) => AchievementTile.earned(
                        a,
                        width: width,
                        onTap: () => showAchievementSheet(
                          context,
                          a,
                          next: next.where((p) => p.habitName != null && p.habitName == a.habitName).firstOrNull,
                        ),
                      ),
              ]),
            if (next.isNotEmpty) ...[
              const SizedBox(height: 20),
              heading('Up next'),
              _Grid(tiles: [for (final p in next) (width) => AchievementTile.next(p, width: width)]),
            ],
          ]),
        ),
      ],
    );
  }
}

/// Tiles in columns that fill the width (three on most phones).
class _Grid extends StatelessWidget {
  final List<Widget Function(double width)> tiles;

  const _Grid({required this.tiles});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        const gap = 10.0;
        final columns = (constraints.maxWidth / 112).floor().clamp(2, 4);
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(spacing: gap, runSpacing: gap, children: [for (final tile in tiles) tile(width)]);
      });
}
