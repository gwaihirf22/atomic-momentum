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

/// A compact habit row: the icon inside a progress ring (tap it to add one),
/// the name with progress and schedule, momentum and streak, and a -/+ stepper.
/// Tap the card to edit; swipe left for Edit and Delete (also offered to
/// VoiceOver as actions).
class HabitCard extends StatelessWidget {
  static const flameColor = Colors.deepOrange;

  /// The streak survived one miss; another would end it.
  static final atRiskColor = Colors.amber.shade800;

  final Habit habit;
  final Category category;

  /// True while a progress change is being saved.
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<int> onSetProgress;

  const HabitCard({
    Key? key,
    required this.habit,
    required this.category,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
    required this.onSetProgress,
  }) : super(key: key);

  bool get _canAdd => !busy && habit.progress < habit.target;
  bool get _canRemove => !busy && habit.progress > 0;

  String get _progressText => habit.units.isEmpty
      ? '${habit.progress}/${habit.target}'
      : '${habit.progress}/${habit.target} ${habit.units}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = habit.color.color;
    final isRestDay = !habit.isDueOn(DateTime.now());
    final secondary = theme.textTheme.bodySmall?.color ?? Colors.grey;
    // Momentum and streak appear once there's something to show
    final showStats = habit.schedule.isPeriodic && habit.history.values.any((amount) => amount > 0);

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
            },
            child: Material(
              key: Key('habitCard_${habit.id}'),
              color: theme.cardColor,
              child: InkWell(
                onTap: onEdit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      HabitProgressRing(
                        key: Key('habitIcon_${habit.id}'),
                        icon: habitIcon(habit, category),
                        color: color,
                        fraction: habit.progressPercentage,
                        isDone: habit.isCompleted,
                        dimmed: isRestDay,
                        semanticLabel: '${habit.name}, ${category.name}, $_progressText',
                        onTap: _canAdd ? () => onSetProgress(habit.progress + 1) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              habit.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 16, height: 1.2, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            // Truncates rather than overflowing
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
                                if (!habit.schedule.isEveryDay)
                                  TextSpan(text: '  ·  ${habit.schedule.shortLabel}'),
                                if (isRestDay) const TextSpan(text: '  ·  Rest day'),
                              ]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, height: 1.2, color: secondary),
                            ),
                            if (showStats) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  _MomentumChip(
                                    key: Key('habitMomentum_${habit.id}'),
                                    momentum: habit.momentum,
                                    color: color,
                                  ),
                                  if (habit.streak.current > 0) ...[
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: _StreakBadge(
                                        key: Key('habitStreak_${habit.id}'),
                                        habitId: habit.id,
                                        count: habit.streak.current,
                                        atRisk: habit.streak.atRisk,
                                        label: habit.schedule.streakLabel(habit.streak.current),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      HabitStepper(
                        color: color,
                        removeKey: Key('decrementHabit_${habit.id}'),
                        addKey: Key('incrementHabit_${habit.id}'),
                        onRemove: _canRemove ? () => onSetProgress(habit.progress - 1) : null,
                        onAdd: _canAdd ? () => onSetProgress(habit.progress + 1) : null,
                      ),
                    ],
                  ),
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
/// After a miss it turns to an amber outline with "Don't miss twice".
class _StreakBadge extends StatelessWidget {
  final String habitId;
  final int count;
  final bool atRisk;
  final String label;

  const _StreakBadge({
    Key? key,
    required this.habitId,
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
          if (atRisk) ...[
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                "Don't miss twice",
                key: Key('habitAtRisk_$habitId'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
