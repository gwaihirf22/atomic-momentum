import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter_slidable/flutter_slidable.dart';
import '../tour/tour_anchor.dart';
import '../tour/tour_events.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_style.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/momentum.dart';
import '../../domain/services/recent_periods.dart';
import '../../domain/services/step_size.dart';
import 'freeze_time_left.dart';
import 'habit_icons.dart';
import 'break_wording.dart';
import 'hold_undo_strip.dart';
import 'recent_periods_bar.dart';
import 'habit_progress_ring.dart';
import 'habit_stepper.dart';
import 'two_minute_button.dart';
import 'package:clock/clock.dart';

/// A compact habit row: the icon inside a progress ring (tap it to add one),
/// the name with progress and schedule, momentum and streak, the "2 min"
/// button for a two-minute version, and a -/+ stepper. Tap the card for the
/// habit's page; swipe left for Edit and Delete (also offered to VoiceOver as
/// actions).
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

  /// Tapping the card: the habit's page. Edit is in the swipe actions.
  final VoidCallback? onOpen;
  final ValueChanged<int> onSetProgress;

  /// Marks (true) or unmarks today's two-minute version.
  final ValueChanged<bool>? onSetTwoMinute;

  /// Briefly tinted in the habit's color, e.g. after tapping its notification.
  final bool highlighted;

  /// Holding the ring: finishes the habit, or clears it when it's done.
  final VoidCallback? onHold;

  /// A held change that can still be undone: covers the card with Undo.
  final HoldUndo? holdUndo;

  /// Freezes (or unfreezes) today, from the swipe actions; null: no Freeze.
  final VoidCallback? onFreeze;

  const HabitCard({
    Key? key,
    required this.habit,
    required this.category,
    required this.onEdit,
    required this.onDelete,
    this.onOpen,
    required this.onSetProgress,
    this.onSetTwoMinute,
    this.highlighted = false,
    this.onHold,
    this.holdUndo,
    this.onFreeze,
  }) : super(key: key);

  // Never locked while saving: taps show at once and save in the background
  /// + adds one up to the target; for a habit being broken it logs a slip,
  /// with room well past the limit.
  bool get _canAdd => habit.isBreak ? habit.progress < habit.maxPeriodTotal : habit.progress < habit.target;

  /// Holding a done habit's ring clears its period; one that never resets
  /// has no period to clear.
  bool get _canClear => !habit.isBreak && habit.isCompleted && habit.resetFrequency.isPeriodic;

  /// Holding the ring finishes or clears a habit being built; a habit being
  /// broken has nothing to finish, and a stray hold shouldn't log slips.
  bool get _canHold => !habit.isBreak && (_canAdd || _canClear);
  bool get _canRemove => habit.progress > 0;

  String get _progressText {
    if (habit.isBreak) return BreakWording.status(habit, clock.now());
    return habit.units.isEmpty ? '${habit.progress}/${habit.target}' : '${habit.progress}/${habit.target} ${habit.units}';
  }

  /// The "2 min" button shows while today is due and not yet complete, for a
  /// habit whose two-minute version is set to show on its card.
  /// Closes every card left swiped open (a tour moving on).
  static void closeSwipes() {
    for (final card in _SwipeReporterState._all) {
      if (card.mounted && card._pane?.value != ActionPaneType.none) Slidable.of(card.context)?.close();
    }
  }

  static bool showsTwoMinuteButton(Habit habit, DateTime now) {
    final tiny = habit.twoMinute;
    return tiny != null &&
        tiny.showOnCard &&
        habit.schedule.isPeriodic &&
        habit.isDueOn(now) &&
        !habit.wasCompletedOnDate(now) &&
        // Frozen or on vacation: held as it is
        !habit.skipsPeriod(habit.schedule.periodStart(now));
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
        if (habit.isFrozenOn(now) || habit.isOnVacationOn(now))
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(CupertinoIcons.snow, size: 12, color: palette.ice),
            const SizedBox(width: 3),
            Flexible(
              child: habit.isFrozenOn(now)
                  // Counts down to the end of the frozen day (or week, or month)
                  ? FreezeTimeLeft(
                      key: Key('habitFrozen_${habit.id}'),
                      ends: habit.schedule.nextPeriodStart(now),
                      format: (left) => 'Frozen · $left',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.ice),
                    )
                  : Text(
                      'On vacation',
                      key: Key('habitFrozen_${habit.id}'),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.ice),
                    ),
            ),
          ]),
        if (showStats)
          _MomentumChip(key: Key('habitMomentum_${habit.id}'), momentum: habit.momentum, color: color),
        if (habit.streak.current > 0)
          _StreakBadge(
            key: Key('habitStreak_${habit.id}'),
            count: habit.streak.current,
            atRisk: habit.streak.atRisk,
            label: habit.isBreak
                ? BreakWording.streak(habit, habit.streak.current)
                : habit.schedule.streakLabel(habit.streak.current),
          ),
        if (habit.streak.current > 0 && habit.streak.atRisk)
          // Read out with the streak badge, so hidden from VoiceOver here
          ExcludeSemantics(
            child: Text(
              habit.isBreak ? "Don't slip twice" : "Don't miss twice",
              key: Key('habitAtRisk_${habit.id}'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.warning),
            ),
          ),
        if (showStats)
          RecentPeriodsBar(
            key: Key('habitRecent_${habit.id}'),
            periods: recentPeriods(habit, now),
            color: color,
            missedColor: habit.isBreak ? palette.warning : null,
            unit: habit.resetFrequency.periodUnit,
          ),
        if (showTwoMinute)
          TourAnchor(
            id: TourAnchorId.habitTwoMinute,
            tag: habit.id,
            child: TwoMinuteButton(
              key: Key('twoMinute_${habit.id}'),
              description: habit.twoMinute!.description,
              color: color,
              done: habit.isTwoMinuteOn(now),
              // Reaching the two-minute amount counts by itself
              onChanged: onSetTwoMinute == null ||
                      (habit.twoMinuteReachedByAmountOn(now) && !habit.usedTwoMinuteButtonOn(now))
                  ? null
                  : (done) {
                      if (done) TourEvents.emit(TwoMinuteTapped(habit.id));
                      onSetTwoMinute!(done);
                    },
            ),
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
    // Momentum and streak appear once there's something to show; a habit
    // being broken is kept by logging nothing, so its clean run shows too
    final logged = habit.history.values.any((amount) => amount > 0) || habit.twoMinuteDays.isNotEmpty;
    final showStats = habit.schedule.isPeriodic && (logged || (habit.isBreak && habit.streak.current > 0));
    final showTwoMinute = showsTwoMinuteButton(habit, now);
    // A frozen day (or vacation) says so even before anything is logged
    final hasStatsRow = showStats || showTwoMinute || habit.isFrozenOn(now) || habit.isOnVacationOn(now);
    Widget stats() => _stats(palette, showStats: showStats, showTwoMinute: showTwoMinute, now: now);
    // Today can be frozen (or already is)
    final canFreeze = onFreeze != null && (habit.isFrozenOn(now) || habit.whyNoFreeze(now, now) == null);
    // Frozen (or on vacation) and not kept: the card looks frozen
    final paused = habit.skipsPeriod(habit.schedule.periodStart(now));

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TourAnchor(
        id: TourAnchorId.habitCard,
        tag: habit.id,
        child: ClipRRect(
        borderRadius: BorderRadius.circular(AppStyle.cardRadius),
        child: Slidable(
          key: ValueKey('slidable_${habit.id}'),
          groupTag: 'habits',
          // Swipe right: freeze today (or take the freeze back)
          startActionPane: canFreeze
              ? ActionPane(
                  motion: const BehindMotion(),
                  extentRatio: 0.26,
                  children: [
                    SlidableAction(
                      key: Key('freezeHabit_${habit.id}'),
                      onPressed: (_) {
                        TourEvents.emit(FreezeTapped(habit.id));
                        onFreeze!();
                      },
                      backgroundColor: palette.ice,
                      foregroundColor: palette.onColor(palette.ice),
                      icon: CupertinoIcons.snow,
                      label: habit.isFrozenOn(now) ? 'Unfreeze' : 'Freeze',
                    ),
                  ],
                )
              : null,
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
          child: _SwipeReporter(
            habitId: habit.id,
            child: Semantics(
            // Swipe actions are hard to reach with VoiceOver; offer them as actions
            customSemanticsActions: {
              if (onHold != null && _canHold && _canAdd) const CustomSemanticsAction(label: 'Mark done'): onHold!,
              if (onHold != null && _canHold && _canClear) const CustomSemanticsAction(label: 'Clear'): onHold!,
              const CustomSemanticsAction(label: 'Edit'): onEdit,
              const CustomSemanticsAction(label: 'Delete'): onDelete,
              if (canFreeze)
                CustomSemanticsAction(label: habit.isFrozenOn(now) ? 'Unfreeze today' : 'Freeze today'): onFreeze!,
              if (showTwoMinute && onSetTwoMinute != null && !habit.isTwoMinuteOn(now))
                const CustomSemanticsAction(label: 'Did the two-minute version'): () => onSetTwoMinute!(true),
            },
            child: Material(
              key: Key('habitCard_${habit.id}'),
              color: highlighted
                  ? palette.tint(habit.color.color, alpha: 0.22)
                  : paused
                      ? palette.tint(palette.ice, alpha: 0.16)
                      : palette.surface,
              shape: paused
                  ? RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppStyle.cardRadius),
                      side: BorderSide(color: palette.ice.withValues(alpha: 0.6), width: 1.2),
                    )
                  : null,
              // Fades in and out rather than flashing
              animationDuration: const Duration(milliseconds: 600),
              child: Stack(children: [
                InkWell(
                onTap: onOpen ?? onEdit,
                child: Padding(
                  // Right and vertical padding live inside the rows, so the
                  // stepper's tap guard reaches the card's edges
                  padding: const EdgeInsets.only(left: 12),
                  child: LayoutBuilder(builder: (context, constraints) {
                    final twoRows = useTwoRows(context, constraints.maxWidth + 12);
                    final ring = TourAnchor(id: TourAnchorId.habitRing, tag: habit.id, child: HabitProgressRing(
                      key: Key('habitIcon_${habit.id}'),
                      icon: paused ? CupertinoIcons.snow : habitIcon(habit, category),
                      color: paused ? palette.ice : color,
                      // A habit being broken shows the room left, not a check
                      fraction: habit.isBreak ? habit.roomLeftOn(now) : habit.progressPercentage,
                      isDone: !habit.isBreak && habit.isCompleted,
                      dimmed: isRestDay,
                      semanticLabel: '${habit.name}, ${category.name}, $_progressText',
                      // A tap on the ring never logs a slip by accident
                      onTap: _canAdd && !habit.isBreak ? () => onSetProgress(StepSize.up(habit.progress, habit.target)) : null,
                      onLongPress: _canHold
                          ? () {
                              TourEvents.emit(HoldFinished(habit.id));
                              onHold!();
                            }
                          : null,
                      longPressHint: _canAdd ? 'Finish' : 'Clear',
                    ));
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
                                color: habit.isBreak
                                    ? (habit.isCompleted ? null : palette.warning)
                                    : (habit.isCompleted ? color : null),
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
                    final stepper = TourAnchor(id: TourAnchorId.habitPlus, tag: habit.id, child: HabitStepper(
                      color: paused ? palette.ice : color,
                      removeKey: Key('decrementHabit_${habit.id}'),
                      addKey: Key('incrementHabit_${habit.id}'),
                      removeTooltip: habit.isBreak ? 'Remove a slip' : stepTooltip(habit, adding: false, one: 'Remove one'),
                      addTooltip: habit.isBreak ? 'Log a slip' : stepTooltip(habit, adding: true, one: 'Add one'),
                      onRemove: _canRemove ? () => onSetProgress(StepSize.down(habit.progress, habit.target)) : null,
                      onAdd: _canAdd
                          ? () {
                              TourEvents.emit(PlusTapped(habit.id));
                              onSetProgress(StepSize.up(habit.progress, habit.target));
                            }
                          : null,
                    ));

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
                // Holding the ring changed it: undo for a few seconds
                HoldUndoOverlay(undo: holdUndo, color: color, habitName: habit.name, undoKey: Key('undoHold_${habit.id}')),
              ]),
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

/// Tells a tour when the card is swiped open ("Swipe right to freeze a day").
class _SwipeReporter extends StatefulWidget {
  final String habitId;
  final Widget child;

  const _SwipeReporter({required this.habitId, required this.child});

  @override
  State<_SwipeReporter> createState() => _SwipeReporterState();
}

class _SwipeReporterState extends State<_SwipeReporter> {
  ValueListenable<ActionPaneType>? _pane;

  /// Every card showing, so a tour can close any it left swiped open.
  static final _all = <_SwipeReporterState>{};

  @override
  void initState() {
    super.initState();
    _all.add(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pane = Slidable.of(context)?.actionPaneType;
    if (pane != _pane) {
      _pane?.removeListener(_changed);
      _pane = pane?..addListener(_changed);
    }
  }

  @override
  void dispose() {
    _all.remove(this);
    _pane?.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final type = _pane?.value;
    if (type == ActionPaneType.start) TourEvents.emit(CardSwiped(widget.habitId, freeze: true));
    if (type == ActionPaneType.end) TourEvents.emit(CardSwiped(widget.habitId, freeze: false));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
