import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_style.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/momentum.dart';
import '../../domain/services/recent_periods.dart';
import 'habit_icons.dart';
import 'recent_periods_bar.dart';
import 'habit_progress_ring.dart';
import 'habit_stepper.dart';
import 'two_minute_button.dart';
import 'package:clock/clock.dart';

/// A compact habit row: the icon inside a progress ring (tap it to add one),
/// the name with progress and schedule, momentum and streak, the "2 min"
/// button for a two-minute version, and a -/+ stepper. Tap the card to edit; swipe left for Edit and Delete (also offered to
/// VoiceOver as actions).
class HabitCard extends StatelessWidget {
  /// Cards narrower than this (on a phone narrower than 390pt) use two rows.
  static const twoRowCardWidth = 358.0;

  /// Two rows for a card [cardWidth] wide: on narrow phones, or with large
  /// text, so names and details aren't cut off. Calendar rows use it too.
  static bool useTwoRows(BuildContext context, double cardWidth) =>
      cardWidth < twoRowCardWidth || MediaQuery.textScalerOf(context).scale(1) > 1.15;

  /// The area around the stepper catches every tap, so a near miss or a
  /// tap on a greyed-out button never opens Edit.
  static Widget guardStepper(Widget child) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: () {},
        child: child,
      );

  final Habit habit;
  final Category category;

  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<int> onSetProgress;

  /// Marks (true) or unmarks today's two-minute version.
  final ValueChanged<bool>? onSetTwoMinute;

  /// Briefly tinted in the habit's color, e.g. after tapping its notification.
  final bool highlighted;

  const HabitCard({
    Key? key,
    required this.habit,
    required this.category,
    required this.onEdit,
    required this.onDelete,
    required this.onSetProgress,
    this.onSetTwoMinute,
    this.highlighted = false,
  }) : super(key: key);

  // Never locked while saving: taps show at once and save in the background
  bool get _canAdd => habit.progress < habit.target;
  bool get _canRemove => habit.progress > 0;

  String get _progressText =>
      habit.units.isEmpty ? '${habit.progress}/${habit.target}' : '${habit.progress}/${habit.target} ${habit.units}';

  /// The "2 min" button shows while today is due and not yet complete, for a
  /// habit whose two-minute version is set to show on its card.
  static bool showsTwoMinuteButton(Habit habit, DateTime now) {
    final tiny = habit.twoMinute;
    return tiny != null &&
        tiny.showOnCard &&
        habit.schedule.isPeriodic &&
        habit.isDueOn(now) &&
        !habit.wasCompletedOnDate(now);
  }

  /// Momentum, streak and the "2 min" button; wraps onto another line rather
  /// than cutting off "Don't miss twice".
  Widget _stats(AppPalette palette, {required bool showStats, required bool showTwoMinute, required DateTime now}) {
    final color = palette.habitColor(habit.color.color);
    return Wrap(
      spacing: 10,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (showStats)
          _MomentumChip(key: Key('habitMomentum_${habit.id}'), momentum: habit.momentum, color: color),
        if (habit.streak.current > 0)
          _StreakBadge(
            key: Key('habitStreak_${habit.id}'),
            count: habit.streak.current,
            atRisk: habit.streak.atRisk,
            label: habit.schedule.streakLabel(habit.streak.current),
          ),
        if (habit.streak.current > 0 && habit.streak.atRisk)
          // Read out with the streak badge, so hidden from VoiceOver here
          ExcludeSemantics(
            child: Text(
              "Don't miss twice",
              key: Key('habitAtRisk_${habit.id}'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.warning),
            ),
          ),
        if (showStats)
          RecentPeriodsBar(
            key: Key('habitRecent_${habit.id}'),
            periods: recentPeriods(habit, now),
            color: color,
            unit: habit.resetFrequency.periodUnit,
          ),
        if (showTwoMinute)
          TwoMinuteButton(
            key: Key('twoMinute_${habit.id}'),
            description: habit.twoMinute!.description,
            color: color,
            done: habit.isTwoMinuteOn(now),
            // Reaching the two-minute amount counts by itself
            onChanged: onSetTwoMinute == null ||
                    (habit.twoMinuteReachedByAmountOn(now) && !habit.usedTwoMinuteButtonOn(now))
                ? null
                : onSetTwoMinute,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final color = palette.habitColor(habit.color.color);
    final now = clock.now();
    final isRestDay = !habit.isDueOn(now);
    final secondary = secondaryLabel(context);
    // Momentum and streak appear once there's something to show
    final showStats = habit.schedule.isPeriodic &&
        (habit.history.values.any((amount) => amount > 0) || habit.twoMinuteDays.isNotEmpty);
    final showTwoMinute = showsTwoMinuteButton(habit, now);
    final hasStatsRow = showStats || showTwoMinute;
    Widget stats() => _stats(palette, showStats: showStats, showTwoMinute: showTwoMinute, now: now);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppStyle.cardRadius),
        child: Slidable(
          key: ValueKey('slidable_${habit.id}'),
          groupTag: 'habits',
          endActionPane: ActionPane(
            motion: const BehindMotion(),
            extentRatio: 0.44,
            children: [
              SlidableAction(
                key: Key('editHabit_${habit.id}'),
                onPressed: (_) => onEdit(),
                backgroundColor: palette.textSecondary,
                foregroundColor: palette.surface,
                icon: CupertinoIcons.pencil,
                label: 'Edit',
              ),
              SlidableAction(
                key: Key('deleteHabit_${habit.id}'),
                onPressed: (_) => onDelete(),
                backgroundColor: palette.danger,
                foregroundColor: palette.onColor(palette.danger),
                icon: CupertinoIcons.trash,
                label: 'Delete',
              ),
            ],
          ),
          child: Semantics(
            // Swipe actions are hard to reach with VoiceOver; offer them as actions
            customSemanticsActions: {
              if (_canAdd) const CustomSemanticsAction(label: 'Mark done'): () => onSetProgress(habit.target),
              const CustomSemanticsAction(label: 'Edit'): onEdit,
              const CustomSemanticsAction(label: 'Delete'): onDelete,
              if (showTwoMinute && onSetTwoMinute != null && !habit.isTwoMinuteOn(now))
                const CustomSemanticsAction(label: 'Did the two-minute version'): () => onSetTwoMinute!(true),
            },
            child: Material(
              key: Key('habitCard_${habit.id}'),
              color: highlighted ? palette.tint(habit.color.color, alpha: 0.22) : palette.surface,
              // Fades in and out rather than flashing
              animationDuration: const Duration(milliseconds: 600),
              child: InkWell(
                onTap: onEdit,
                child: Padding(
                  // Right and vertical padding live inside the rows, so the
                  // stepper's tap guard reaches the card's edges
                  padding: const EdgeInsets.only(left: 12),
                  child: LayoutBuilder(builder: (context, constraints) {
                    final twoRows = useTwoRows(context, constraints.maxWidth + 12);
                    final ring = HabitProgressRing(
                      key: Key('habitIcon_${habit.id}'),
                      icon: habitIcon(habit, category),
                      color: color,
                      fraction: habit.progressPercentage,
                      isDone: habit.isCompleted,
                      dimmed: isRestDay,
                      semanticLabel: '${habit.name}, ${category.name}, $_progressText',
                      onTap: _canAdd ? () => onSetProgress(habit.progress + 1) : null,
                      onLongPress: _canAdd ? () => onSetProgress(habit.target) : null,
                    );
                    final details = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          habit.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, height: 1.2, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: _progressText,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: habit.isCompleted ? color : null,
                              ),
                            ),
                            // Only what's informative: the category shows in the
                            // icon and color, and every day is the default
                            if (!habit.schedule.isEveryDay) TextSpan(text: '  ·  ${habit.schedule.shortLabel}'),
                            if (isRestDay) const TextSpan(text: '  ·  Rest day'),
                          ]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, height: 1.2, color: secondary),
                        ),
                        if (hasStatsRow && !twoRows) ...[
                          const SizedBox(height: 2),
                          stats(),
                        ],
                      ],
                    );
                    final stepper = HabitStepper(
                      color: color,
                      removeKey: Key('decrementHabit_${habit.id}'),
                      addKey: Key('incrementHabit_${habit.id}'),
                      onRemove: _canRemove ? () => onSetProgress(habit.progress - 1) : null,
                      onAdd: _canAdd ? () => onSetProgress(habit.progress + 1) : null,
                    );

                    if (!twoRows) {
                      // The stepper's guard runs the card's full height on the right
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Center(child: ring)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Align(alignment: Alignment.centerLeft, child: details),
                              ),
                            ),
                            guardStepper(Padding(
                              padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
                              child: Center(child: stepper),
                            )),
                          ],
                        ),
                      );
                    }
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 10, right: 12),
                          child: Row(children: [ring, const SizedBox(width: 12), Expanded(child: details)]),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const SizedBox(width: HabitProgressRing.defaultSize + 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: hasStatsRow ? stats() : const SizedBox.shrink(),
                              ),
                            ),
                            guardStepper(Padding(
                              padding: const EdgeInsets.fromLTRB(8, 0, 12, 10),
                              child: stepper,
                            )),
                          ],
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Momentum score with a trend arrow, in the habit's color.
class _MomentumChip extends StatelessWidget {
  final Momentum momentum;
  final Color color;

  const _MomentumChip({Key? key, required this.momentum, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final trend = momentum.isRising
        ? ', rising'
        : momentum.isFalling
            ? ', falling'
            : '';
    return Semantics(
      label: 'Momentum ${momentum.rounded}$trend',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, size: 16, color: color),
          Text(
            '${momentum.rounded}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
          ),
          if (momentum.isRising || momentum.isFalling) ...[
            const SizedBox(width: 1),
            Icon(
              momentum.isRising ? CupertinoIcons.arrow_up : CupertinoIcons.arrow_down,
              size: 11,
              color: color,
            ),
          ],
        ],
      ),
    );
  }
}

/// Flat flame with the streak count, matching the Settings streak icon.
/// After a miss it turns to an amber outline ("Don't miss twice" follows it).
class _StreakBadge extends StatelessWidget {
  final int count;
  final bool atRisk;
  final String label;

  const _StreakBadge({
    Key? key,
    required this.count,
    required this.atRisk,
    required this.label,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final color = atRisk ? palette.warning : palette.flame;
    return Semantics(
      label: atRisk ? "$label, missed once, don't miss twice" : label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            atRisk ? Icons.local_fire_department_outlined : Icons.local_fire_department,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            '$count',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
