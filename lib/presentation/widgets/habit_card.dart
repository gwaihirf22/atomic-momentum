import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/habit.dart';
import 'habit_icons.dart';

/// A compact, one-row habit: the icon inside a progress ring (tap it to add
/// one), the name with progress, schedule and streak, and a -/+ stepper.
/// Tap the card to edit; swipe left for Edit and Delete (also offered to
/// VoiceOver as actions).
class HabitCard extends StatelessWidget {
  static const flameColor = Colors.deepOrange;

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

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      _ProgressRing(
                        key: Key('habitIcon_${habit.id}'),
                        icon: habitIcon(habit, category),
                        color: color,
                        fraction: habit.progressPercentage,
                        isDone: habit.isCompleted,
                        dimmed: isRestDay,
                        semanticLabel: '${habit.name}, $_progressText',
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
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                // Truncates (category last) rather than overflowing
                                Flexible(
                                  child: Text.rich(
                                    TextSpan(children: [
                                      TextSpan(
                                        text: _progressText,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: habit.isCompleted ? color : null,
                                        ),
                                      ),
                                      TextSpan(text: '  ·  ${habit.schedule.shortLabel}'),
                                      if (isRestDay) const TextSpan(text: '  ·  Rest day'),
                                      TextSpan(text: '  ·  ${category.name}'),
                                    ]),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 13, color: secondary),
                                  ),
                                ),
                                if (habit.streak.current > 0) ...[
                                  const SizedBox(width: 8),
                                  _StreakBadge(
                                    key: Key('habitStreak_${habit.id}'),
                                    count: habit.streak.current,
                                    label: habit.schedule.streakLabel(habit.streak.current),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _Stepper(
                        habitId: habit.id,
                        color: color,
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

/// Flat flame with the streak count, matching the Settings streak icon.
class _StreakBadge extends StatelessWidget {
  final int count;
  final String label;

  const _StreakBadge({Key? key, required this.count, required this.label}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department, size: 16, color: HabitCard.flameColor),
          const SizedBox(width: 2),
          Text(
            '$count',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: HabitCard.flameColor),
          ),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  static const double _size = 52;
  static const double _stroke = 4.5;

  final IconData icon;
  final Color color;
  final double fraction;
  final bool isDone;
  final bool dimmed;
  final String semanticLabel;
  final VoidCallback? onTap;

  const _ProgressRing({
    Key? key,
    required this.icon,
    required this.color,
    required this.fraction,
    required this.isDone,
    required this.dimmed,
    required this.semanticLabel,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: isDone ? '$semanticLabel, done' : semanticLabel,
      hint: onTap != null ? 'Adds one' : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          // Rest days: logging is allowed but doesn't affect the streak
          opacity: dimmed ? 0.45 : 1,
          child: SizedBox(
            width: _size,
            height: _size,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: fraction),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => CustomPaint(
                painter: _RingPainter(fraction: value, color: color, stroke: _stroke),
                child: child,
              ),
              child: Center(
                child: Container(
                  width: _size - 14,
                  height: _size - 14,
                  decoration: BoxDecoration(
                    color: isDone ? color : color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(isDone ? Icons.check : icon, size: 20, color: isDone ? Colors.white : color),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double fraction;
  final Color color;
  final double stroke;

  _RingPainter({required this.fraction, required this.color, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, paint..color = color.withOpacity(0.18));
    if (fraction > 0) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2,
          2 * math.pi * fraction.clamp(0.0, 1.0), false, paint..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.color != color;
}

/// A compact -/+ control in the habit's color, with 44pt tap targets.
class _Stepper extends StatelessWidget {
  final String habitId;
  final Color color;
  final VoidCallback? onRemove;
  final VoidCallback? onAdd;

  const _Stepper({required this.habitId, required this.color, this.onRemove, this.onAdd});

  @override
  Widget build(BuildContext context) {
    Widget button(Key key, IconData icon, String tooltip, VoidCallback? onPressed) => IconButton(
          key: key,
          icon: Icon(icon, size: 18),
          tooltip: tooltip,
          color: color,
          disabledColor: color.withOpacity(0.3),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          padding: EdgeInsets.zero,
          onPressed: onPressed,
        );

    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Key('decrementHabit_$habitId'), CupertinoIcons.minus, 'Remove one', onRemove),
          Container(width: 1, height: 20, color: color.withOpacity(0.25)),
          button(Key('incrementHabit_$habitId'), CupertinoIcons.plus, 'Add one', onAdd),
        ],
      ),
    );
  }
}
