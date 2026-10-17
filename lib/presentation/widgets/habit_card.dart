import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../core/theme/app_style.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/momentum.dart';
import 'habit_icons.dart';
import 'habit_progress_ring.dart';
import 'habit_stepper.dart';
import 'two_minute_button.dart';

/// A compact habit row: the icon inside a progress ring (tap it to add one),
/// the name with progress and schedule, momentum and streak, the "2 min"
/// button for a two-minute version, and a -/+ stepper. Tap the card to edit; swipe left for Edit and Delete (also offered to
/// VoiceOver as actions).
class HabitCard extends StatelessWidget {
  static const flameColor = Colors.deepOrange;

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

  /// The streak survived one miss; another would end it.
  static final atRiskColor = Colors.amber.shade800;

  final Habit habit;
  final Category category;

  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<int> onSetProgress;

  /// Marks (true) or unmarks today's two-minute version.
  final ValueChanged<bool>? onSetTwoMinute;

  const HabitCard({
    Key? key,
    required this.habit,
    required this.category,
    required this.onEdit,
    required this.onDelete,
    required this.onSetProgress,
    this.onSetTwoMinute,
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
  Widget _stats({required bool showStats, required bool showTwoMinute, required DateTime now}) {
    return Wrap(
      spacing: 10,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (showStats)
          _MomentumChip(key: Key('habitMomentum_${habit.id}'), momentum: habit.momentum, color: habit.color.color),
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
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: atRiskColor),
            ),
          ),
        if (showTwoMinute)
          TwoMinuteButton(
            key: Key('twoMinute_${habit.id}'),
            description: habit.twoMinute!.description,
            color: habit.color.color,
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
    final theme = Theme.of(context);
    final color = habit.color.color;
    final now = DateTime.now();
    final isRestDay = !habit.isDueOn(now);
    final secondary = secondaryLabel(context);
    // Momentum and streak appear once there's something to show
    final showStats = habit.schedule.isPeriodic &&
        (habit.history.values.any((amount) => amount > 0) || habit.twoMinuteDays.isNotEmpty);
    final showTwoMinute = showsTwoMinuteButton(habit, now);
    final hasStatsRow = showStats || showTwoMinute;
    Widget stats() => _stats(showStats: showStats, showTwoMinute: showTwoMinute, now: now);

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
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
                icon: CupertinoIcons.pencil,
                label: 'Edit',
              ),
              SlidableAction(
                key: Key('deleteHabit_${habit.id}'),
                onPressed: (_) => onDelete(),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                icon: CupertinoIcons.trash,
                label: 'Delete',
              ),
            ],
          ),
          child: Semantics(
            // Swipe actions are hard to reach with VoiceOver; offer them as actions
            customSemanticsActions: {
              const CustomSemanticsAction(label: 'Edit'): onEdit,
              const CustomSemanticsAction(label: 'Delete'): onDelete,
              if (showTwoMinute && onSetTwoMinute != null && !habit.isTwoMinuteOn(now))
                const CustomSemanticsAction(label: 'Did the two-minute version'): () => onSetTwoMinute!(true),
            },
            child: Material(
              key: Key('habitCard_${habit.id}'),
              color: theme.cardColor,
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
    final color = atRisk ? HabitCard.atRiskColor : HabitCard.flameColor;
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
