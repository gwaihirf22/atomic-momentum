import 'dart:async';
import 'dart:math' as math;
import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/feedback/haptics.dart';
import '../core/locale/week_start.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_style.dart';
import '../domain/entities/category.dart';
import '../domain/entities/habit.dart';
import '../domain/entities/reset_frequency.dart';
import '../domain/services/habit_stats.dart';
import '../domain/services/achievements.dart';
import '../domain/services/insights.dart';
import '../presentation/habit_form/sentence.dart';
import '../presentation/help/explainers.dart';
import '../presentation/providers/category_provider.dart';
import '../presentation/providers/habit_provider.dart';
import '../presentation/providers/settings_provider.dart';
import '../presentation/widgets/achievement_widgets.dart';
import '../presentation/widgets/habit_icons.dart';
import '../presentation/widgets/heatmap.dart';
import '../presentation/widgets/break_wording.dart';
import '../presentation/widgets/habit_progress_ring.dart';
import '../presentation/widgets/hold_undo_strip.dart';
import '../presentation/widgets/info_button.dart';
import '../presentation/widgets/large_title_scaffold.dart';
import '../presentation/widgets/orb_button.dart';
import '../presentation/widgets/stat_card.dart';
import '../presentation/widgets/two_minute_button.dart';
import 'habit_editor_screen.dart';

/// Everything about one habit: the chosen day's amount (tap the number to
/// type it), its week or month, how it's going, why it matters, and notes.
/// It doesn't change the habit's basics; that's Edit (swipe a card).
class HabitDetailScreen extends StatefulWidget {
  final String habitId;

  /// The day to open on (Calendar opens on its selected day); today if null.
  final DateTime? day;

  const HabitDetailScreen({super.key, required this.habitId, this.day});

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  late DateTime _day;
  bool _showMonth = false;
  late DateTime _month;
  HoldUndo? _holdUndo;
  Timer? _holdTimer;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime get _today => _dateOnly(clock.now());

  @override
  void initState() {
    super.initState();
    final start = widget.day == null ? _today : _dateOnly(widget.day!);
    _day = start.isAfter(_today) ? _today : start;
    _month = DateTime(_day.year, _day.month);
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _select(DateTime day) {
    if (day.isAfter(_today)) return;
    Haptics.selection();
    setState(() {
      _day = day;
      _month = DateTime(day.year, day.month);
    });
  }

  // ------------------------------------------------------------ changes

  HabitProvider get _habits => context.read<HabitProvider>();

  Future<void> _saveDay(Habit habit, int amount) async {
    final periodTotal = habit.progressForPeriodContaining(_day);
    final logged = habit.getProgressForDate(_day);
    Haptics.progressChanged(from: periodTotal, to: periodTotal - logged + amount, target: habit.target);
    if (!await _habits.setDays(habit.id, {_day: amount}) && mounted) _showError(habit);
  }

  void _showError(Habit habit) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text("Couldn't update ${habit.name}. Please try again.")));

  /// Typing the number: the period's total, which may go past the target.
  Future<void> _typeAmount(Habit habit) async {
    final periodTotal = habit.progressForPeriodContaining(_day);
    final logged = habit.getProgressForDate(_day);
    final otherDays = periodTotal - logged;
    final typed = await showTextSheet(
      context,
      title: _amountTitle(habit),
      initial: '$periodTotal',
      fieldKey: const Key('amountField'),
      doneKey: const Key('amountDone'),
      numeric: true,
      helper: otherDays > 0 ? '$otherDays logged on other days of this ${habit.resetFrequency.periodUnit}' : null,
      validate: (text) {
        final value = int.tryParse(text.trim());
        if (value == null || value < 0) return 'Enter a number';
        if (value > habit.maxPeriodTotal) return 'That is more than ${habit.maxPeriodTotal}';
        if (value < otherDays) return 'Other days already have $otherDays';
        return null;
      },
    );
    if (typed == null || !mounted) return;
    final value = int.parse(typed.trim());
    if (value != periodTotal) await _saveDay(habit, value - otherDays);
  }

  String _amountTitle(Habit habit) {
    final what = habit.isBreak && habit.units.isEmpty
        ? 'Slips'
        : habit.units.isEmpty
            ? 'Amount'
            : habit.units[0].toUpperCase() + habit.units.substring(1);
    return _day == _today ? '$what today' : '$what on ${DateFormat.MMMEd().format(_day)}';
  }

  Future<void> _setTwoMinute(Habit habit) async {
    final done = !habit.isTwoMinuteOn(_day);
    done ? Haptics.twoMinute() : Haptics.selection();
    if (!await _habits.setTwoMinute(habit.id, done, date: _day) && mounted) _showError(habit);
  }

  /// Holding the ring: finish the day's period, or clear it once done, with
  /// a few seconds to undo, as on the habit cards.
  Future<void> _hold(Habit habit) async {
    final day = _day;
    final before = habit.periodDays(day);
    final finishing = !habit.wasCompletedOnDate(day);
    Haptics.held();
    final saving = finishing
        ? _habits.setDays(habit.id, {day: habit.getProgressForDate(day) + habit.target - habit.progressForPeriodContaining(day)})
        : _habits.setDays(habit.id, {for (final d in before.keys) d: 0});
    _holdTimer?.cancel();
    setState(() => _holdUndo = HoldUndo(
          message: finishing ? 'Marked done' : 'Cleared',
          finished: finishing,
          onUndo: () {
            _endUndo();
            Haptics.selection();
            _habits.setDays(habit.id, before);
          },
        ));
    _holdTimer = Timer(HoldUndo.duration, _endUndo);
    if (await saving || !mounted) return;
    _endUndo();
    _showError(habit);
  }

  void _endUndo() {
    _holdTimer?.cancel();
    if (mounted && _holdUndo != null) setState(() => _holdUndo = null);
  }

  Future<void> _editWhy(Habit habit) async {
    final text = await showTextSheet(
      context,
      title: 'Why I do this',
      initial: habit.why,
      fieldKey: const Key('whyField'),
      doneKey: const Key('whyDone'),
      hint: 'More energy in the afternoon',
      maxLength: Habit.maxWhyLength,
      lines: 4,
    );
    if (text != null && mounted && !await _habits.setWhy(habit.id, text) && mounted) _showError(habit);
  }

  Future<void> _editNote(Habit habit, DateTime day) async {
    if (day != _day) _select(day);
    final text = await showTextSheet(
      context,
      title: day == _today ? 'Note for today' : 'Note for ${DateFormat.MMMEd().format(day)}',
      initial: habit.dayNotes[day] ?? '',
      fieldKey: const Key('noteField'),
      doneKey: const Key('noteDone'),
      hint: 'How did it go?',
      maxLength: Habit.maxDayNoteLength,
      lines: 3,
    );
    if (text != null && mounted && !await _habits.setDayNote(habit.id, day, text) && mounted) _showError(habit);
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final habit = context.watch<HabitProvider>().habits.where((h) => h.id == widget.habitId).firstOrNull;
    final palette = AppPalette.of(context);
    if (habit == null) {
      // Deleted while open
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return ColoredBox(color: palette.background);
    }
    final category = context.watch<CategoryProvider>().resolve(habit.categoryId);
    final weekStart = context.watch<SettingsProvider>().firstDayOfWeek;
    final color = palette.habitColor(habit.color.color);
    final stats = HabitStats.of(habit, clock.now(), weekStart: weekStart);

    return LargeTitleScaffold(
      title: habit.name,
      backgroundColor: palette.background,
      header: _Header(habit: habit, category: category, color: color),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppStyle.screenPadding, 4, AppStyle.screenPadding, 24),
          sliver: SliverList.list(children: [
            _DayCard(
              habit: habit,
              day: _day,
              isToday: _day == _today,
              color: color,
              holdUndo: _holdUndo,
              onType: () => _typeAmount(habit),
              onSet: (amount) => _saveDay(habit, amount),
              onTwoMinute: () => _setTwoMinute(habit),
              onHold: () => _hold(habit),
            ),
            const SizedBox(height: 14),
            _DaysCard(
              habit: habit,
              selected: _day,
              today: _today,
              weekStart: weekStart,
              color: color,
              showMonth: _showMonth,
              month: _month,
              onSelect: _select,
              onToggle: () => setState(() {
                _showMonth = !_showMonth;
                _month = DateTime(_day.year, _day.month);
              }),
              onMonth: (month) => setState(() => _month = month),
            ),
            const SizedBox(height: 14),
            _StatsGrid(habit: habit, stats: stats, color: color),
            if (stats.bars.isNotEmpty) ...[
              const SizedBox(height: 14),
              _TrendCard(habit: habit, stats: stats, color: color),
              const SizedBox(height: 14),
              _HeatmapCard(habit: habit, weekStart: weekStart, selected: _day, onSelect: _select),
              const SizedBox(height: 14),
              _AchievementsCard(habit: habit, weekStart: weekStart),
            ],
            const SizedBox(height: 14),
            _WhyCard(why: habit.why, onTap: () => _editWhy(habit)),
            const SizedBox(height: 14),
            _NotesCard(
              habit: habit,
              selected: _day,
              today: _today,
              onAdd: () => _editNote(habit, _day),
              onOpen: (day) => _editNote(habit, day),
            ),
            const SizedBox(height: 18),
            // The habit's basics and its notifications live in the editor
            Center(
              child: PillButton(
                key: const Key('detailEdit'),
                label: 'Edit habit & notifications',
                icon: CupertinoIcons.chevron_right,
                onPressed: () => Navigator.of(context, rootNavigator: true).push(
                  CupertinoPageRoute<void>(builder: (_) => HabitEditorScreen(editHabit: habit)),
                ),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}


class _Header extends StatelessWidget {
  final Habit habit;
  final Category category;
  final Color color;

  const _Header({required this.habit, required this.category, required this.color});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final howOften = habit.resetFrequency.isPeriodic
        ? '${HabitSentence.amount(habit.target, habit.units)} ${HabitSentence.schedule(habit.schedule)}'
        : '${HabitSentence.amount(habit.target, habit.units)} in total';
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppStyle.screenPadding, 4, AppStyle.screenPadding, 14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: palette.tint(habit.color.color), borderRadius: BorderRadius.circular(14)),
            child: Icon(habitIcon(habit, category), color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    habit.name,
                    key: const Key('detailTitle'),
                    style: TextStyle(
                      fontFamily: LargeTitleHeader.fontFamily,
                      fontSize: 26,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      color: palette.text,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${howOften[0].toUpperCase()}${howOften.substring(1)} · ${category.name}',
                  style: TextStyle(fontSize: 14, color: palette.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The chosen day: a big ring with the number (tap it to type), −, the
/// two-minute version and +. Holding the ring finishes or clears it.
class _DayCard extends StatelessWidget {
  final Habit habit;
  final DateTime day;
  final bool isToday;
  final Color color;
  final HoldUndo? holdUndo;
  final VoidCallback onType;
  final ValueChanged<int> onSet;
  final VoidCallback onTwoMinute;
  final VoidCallback onHold;

  const _DayCard({
    required this.habit,
    required this.day,
    required this.isToday,
    required this.color,
    required this.holdUndo,
    required this.onType,
    required this.onSet,
    required this.onTwoMinute,
    required this.onHold,
  });

  static const ringSize = 168.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final periodTotal = habit.progressForPeriodContaining(day);
    final logged = habit.getProgressForDate(day);
    final isDone = habit.wasCompletedOnDate(day);
    // For a habit being broken, + logs a slip, and holding does nothing
    final canAdd = periodTotal < (habit.isBreak ? habit.maxPeriodTotal : habit.target);
    final canClear = isDone && habit.resetFrequency.isPeriodic && !habit.isBreak;
    final canHold = !habit.isBreak && (canAdd || canClear);
    final units = habit.units.isEmpty ? '' : ' ${habit.units}';
    final everyDay = habit.resetFrequency == ResetFrequency.daily && habit.resetInterval == 1;
    final of = habit.isBreak
        ? BreakWording.underNumber(habit, periodTotal)
        : 'of ${habit.target}$units${everyDay ? '' : ' ${habit.schedule.periodLabel}'}';
    final showTwoMinute = habit.twoMinute != null && habit.resetFrequency.isPeriodic && !isDone;
    // Scales with text size, within the card
    final ring = ringSize * math.min(1.25, MediaQuery.textScalerOf(context).scale(1));

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      // Full width (a Stack would size the card to its content)
      child: Stack(fit: StackFit.passthrough, children: [
        StatCard(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            children: [
              Text(
                isToday ? 'TODAY' : DateFormat.MMMEd().format(day).toUpperCase(),
                key: const Key('detailDayLabel'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: palette.textSecondary),
              ),
              const SizedBox(height: 12),
              Semantics(
                onLongPressHint: !canHold ? null : canAdd ? 'Finish' : 'Clear',
                onLongPress: canHold ? onHold : null,
                child: GestureDetector(
                  key: const Key('detailRing'),
                  onLongPress: canHold ? onHold : null,
                  child: SizedBox(
                    width: ring,
                    height: ring,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: habit.isBreak ? habit.roomLeftOn(day) : habit.fractionDoneOn(day)),
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) => CustomPaint(
                        painter: RingPainter(
                          fraction: value,
                          // A slipped day shows in the warning color
                          color: habit.isBreak && !isDone ? palette.warning : color,
                          stroke: 12,
                        ),
                        child: child,
                      ),
                      child: Center(
                        child: Semantics(
                          button: true,
                          label: '$periodTotal $of',
                          hint: 'Type an amount',
                          excludeSemantics: true,
                          onTap: onType,
                          child: GestureDetector(
                            key: const Key('detailNumber'),
                            behavior: HitTestBehavior.opaque,
                            onTap: onType,
                            child: SizedBox(
                              width: ring - 48,
                              height: ring - 48,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Dashed underline: a quiet hint that it can be tapped
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    decoration: BoxDecoration(
                                      border: Border(bottom: BorderSide(color: palette.track, width: 2)),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '$periodTotal',
                                        style: TextStyle(
                                          fontFamily: LargeTitleHeader.fontFamily,
                                          fontSize: 46,
                                          height: 1.1,
                                          fontWeight: FontWeight.w700,
                                          color: palette.text,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Flexible(
                                    child: Text(
                                      of,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      style: TextStyle(fontSize: 13, color: palette.textSecondary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  _RoundButton(
                    key: const Key('detailMinus'),
                    icon: Icons.remove_rounded,
                    label: 'Remove one',
                    color: color,
                    filled: false,
                    onPressed: logged > 0 ? () => onSet(logged - 1) : null,
                  ),
                  if (showTwoMinute)
                    // The "2 min" button with its (i), kept together when the row wraps
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      TwoMinuteButton(
                        key: const Key('detailTwoMinute'),
                        description: habit.twoMinute!.description,
                        color: color,
                        done: habit.isTwoMinuteOn(day),
                        onChanged: habit.twoMinuteReachedByAmountOn(day) && !habit.usedTwoMinuteButtonOn(day)
                            ? null
                            : (_) => onTwoMinute(),
                      ),
                      InfoButton(
                        topic: InfoTopic.twoMinute,
                        example: (usual: '${habit.name}${_amount(habit)}', tiny: habit.twoMinute!.description),
                      ),
                    ]),
                  _RoundButton(
                    key: const Key('detailPlus'),
                    icon: Icons.add_rounded,
                    label: 'Add one',
                    color: color,
                    filled: true,
                    onPressed: canAdd ? () => onSet(logged + 1) : null,
                  ),
                ],
              ),
            ],
          ),
        ),
        HoldUndoOverlay(undo: holdUndo, color: color, habitName: habit.name, undoKey: const Key('detailUndo')),
      ]),
    );
  }
}

/// " 10 pages" after a habit's name, for its two-minute example.
String _amount(Habit habit) => habit.target == 1 && habit.units.isEmpty
    ? ''
    : ' ${habit.target}${habit.units.isEmpty ? '' : ' ${habit.units}'}';

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback? onPressed;

  const _RoundButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.filled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final fill = filled ? color : palette.tint(color);
    final ink = filled ? palette.onColor(color) : color;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Opacity(
        opacity: onPressed == null ? 0.4 : 1,
        child: Material(
          color: fill,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: SizedBox(width: 60, height: 48, child: Icon(icon, color: ink, size: 24)),
          ),
        ),
      ),
    );
  }
}

/// The chosen day's week, or its month: each day a small ring, a dot for a
/// note; tap one to choose it.
class _DaysCard extends StatelessWidget {
  final Habit habit;
  final DateTime selected;
  final DateTime today;
  final int weekStart;
  final Color color;
  final bool showMonth;
  final DateTime month;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onToggle;
  final ValueChanged<DateTime> onMonth;

  const _DaysCard({
    required this.habit,
    required this.selected,
    required this.today,
    required this.weekStart,
    required this.color,
    required this.showMonth,
    required this.month,
    required this.onSelect,
    required this.onToggle,
    required this.onMonth,
  });

  DateTime _weekStartOf(DateTime day) => DateTime(day.year, day.month, day.day - (day.weekday - weekStart + 7) % 7);

  Widget _cell(DateTime day, {bool showLetter = false}) => _DayCell(
        key: Key('detailDay_${day.year}-${day.month}-${day.day}'),
        day: day,
        habit: habit,
        color: color,
        selected: day == selected,
        isToday: day == today,
        enabled: !day.isAfter(today),
        showLetter: showLetter,
        onTap: () => onSelect(day),
      );

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final weekOf = _weekStartOf(selected);
    final thisWeek = _weekStartOf(today) == weekOf;
    final heading = showMonth
        ? DateFormat.yMMMM().format(month)
        : thisWeek
            ? 'This week'
            : 'Week of ${DateFormat.MMMd().format(weekOf)}';

    return StatCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: StatCardHeading(
              heading,
              action: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (showMonth) ...[
                  IconButton(
                    key: const Key('detailPrevMonth'),
                    tooltip: 'Previous month',
                    icon: Icon(CupertinoIcons.chevron_left, size: 18, color: palette.accent),
                    onPressed: () => onMonth(DateTime(month.year, month.month - 1)),
                  ),
                  IconButton(
                    key: const Key('detailNextMonth'),
                    tooltip: 'Next month',
                    icon: Icon(CupertinoIcons.chevron_right, size: 18, color: palette.accent),
                    onPressed: month.year == today.year && month.month == today.month
                        ? null
                        : () => onMonth(DateTime(month.year, month.month + 1)),
                  ),
                ],
                PillButton(
                  key: const Key('detailMonthToggle'),
                  label: showMonth ? 'Show week' : 'Show month',
                  icon: showMonth ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                  onPressed: onToggle,
                ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          if (!showMonth)
            Row(children: [
              for (var i = 0; i < 7; i++)
                Expanded(child: _cell(DateTime(weekOf.year, weekOf.month, weekOf.day + i), showLetter: true)),
            ])
          else
            _monthGrid(palette),
        ],
      ),
    );
  }

  Widget _monthGrid(AppPalette palette) {
    final first = DateTime(month.year, month.month);
    final lead = (first.weekday - weekStart + 7) % 7;
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final rows = ((lead + days) / 7).ceil();
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Column(children: [
      Row(children: [
        for (final weekday in weekdaysStartingOn(weekStart))
          Expanded(
            child: ExcludeSemantics(
              child: Text(letters[weekday - 1],
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: palette.textSecondary)),
            ),
          ),
      ]),
      const SizedBox(height: 4),
      for (var r = 0; r < rows; r++)
        Row(children: [
          for (var c = 0; c < 7; c++)
            Expanded(
              child: () {
                final n = r * 7 + c - lead + 1;
                return n < 1 || n > days ? const SizedBox(height: 56) : _cell(DateTime(month.year, month.month, n));
              }(),
            ),
        ]),
    ]);
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final Habit habit;
  final Color color;
  final bool selected;
  final bool isToday;
  final bool enabled;
  final bool showLetter;
  final VoidCallback onTap;

  const _DayCell({
    super.key,
    required this.day,
    required this.habit,
    required this.color,
    required this.selected,
    required this.isToday,
    required this.enabled,
    required this.showLetter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final hasNote = habit.dayNotes.containsKey(day);
    final due = habit.isDueOn(day);
    final fraction = enabled ? habit.fractionDoneOn(day) : 0.0;
    final total = habit.progressForPeriodContaining(day);
    final label = StringBuffer(DateFormat.MMMMEEEEd().format(day))
      ..write(enabled ? ', $total of ${habit.target}' : '')
      ..write(!due ? ', rest day' : '')
      ..write(hasNote ? ', has a note' : '');

    return Semantics(
      button: enabled,
      selected: selected,
      label: label.toString(),
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: !enabled ? 0.35 : due ? 1 : 0.55,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: selected ? palette.tint(habit.color.color) : null,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showLetter) ...[
                  Text(DateFormat.E().format(day)[0],
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: palette.textSecondary)),
                  const SizedBox(height: 4),
                ],
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CustomPaint(
                    painter: RingPainter(fraction: fraction, color: color, stroke: 3.5),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isToday || selected ? FontWeight.w800 : FontWeight.w600,
                            color: isToday ? palette.accent : palette.text,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: hasNote ? palette.textSecondary : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Streak, best, momentum (with its last 30 days) and how many recent
/// periods were kept. A habit that never resets shows its total instead.
class _StatsGrid extends StatelessWidget {
  final Habit habit;
  final HabitStats stats;
  final Color color;

  const _StatsGrid({required this.habit, required this.stats, required this.color});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    if (!habit.resetFrequency.isPeriodic) {
      return _Tile(
        key: const Key('detailTotal'),
        label: 'So far',
        value: '${stats.total}',
        unit: 'of ${habit.target}${habit.units.isEmpty ? '' : ' ${habit.units}'}',
      );
    }
    final unit = habit.resetFrequency.periodUnit;
    String plural(int n) => n == 1 ? unit : '${unit}s';
    final change = stats.momentumChange.round();

    Widget pair(Widget a, Widget b) => IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: a),
            const SizedBox(width: 10),
            Expanded(child: b),
          ]),
        );

    return Column(children: [
      pair(
        _Tile(
          key: const Key('detailStreak'),
          icon: Icons.local_fire_department,
          iconColor: palette.flame,
          label: habit.isBreak ? 'Clean streak' : 'Streak',
          value: '${stats.streak}',
          unit: plural(stats.streak),
        ),
        _Tile(
          key: const Key('detailBest'),
          icon: Icons.emoji_events,
          iconColor: palette.gold,
          label: 'Best',
          value: '${stats.best}',
          unit: plural(stats.best),
        ),
      ),
      const SizedBox(height: 10),
      pair(
        _Tile(
          key: const Key('detailMomentum'),
          icon: Icons.bolt,
          iconColor: palette.gauge,
          label: 'Momentum · ${stats.momentum.level.label}',
          value: '${stats.momentum.rounded}',
          unit: change == 0 ? '' : (change > 0 ? '+$change' : '$change'),
          unitColor: change > 0 ? palette.good : palette.textSecondary,
          semanticsExtra:
              change == 0 ? '' : ', ${change > 0 ? 'up' : 'down'} ${change.abs()} in ${HabitStats.trendDays} days',
          info: InfoTopic.momentum,
          infoScore: stats.momentum.score,
          below: SizedBox(
            width: double.infinity,
            height: 28,
            child: CustomPaint(painter: _SparklinePainter(stats.momentumTrend, palette.gauge)),
          ),
        ),
        _Tile(
          key: const Key('detailKept'),
          label: stats.recentLabel,
          value: stats.due == 0 ? '–' : '${(stats.keptShare * 100).round()}%',
          below: Text(
            stats.due == 0
                ? 'Nothing due yet'
                : '${stats.kept} of ${stats.due} ${habit.isBreak ? 'on track' : 'kept'}'
                    '${stats.keptWithTwoMinute > 0 ? ' · ${stats.keptWithTwoMinute} with 2 min' : ''}',
            style: TextStyle(fontSize: 13, color: palette.textSecondary),
          ),
        ),
      ),
    ]);
  }
}

class _Tile extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final String label;
  final String value;
  final String unit;
  final Color? unitColor;
  final String semanticsExtra;
  final Widget? below;

  /// Tapping the tile explains this, marked by a small (i).
  final InfoTopic? info;
  final double? infoScore;

  const _Tile({
    super.key,
    this.icon,
    this.iconColor,
    required this.label,
    required this.value,
    this.unit = '',
    this.unitColor,
    this.semanticsExtra = '',
    this.below,
    this.info,
    this.infoScore,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    void explain() => showInfoSheet(context, info!, momentum: infoScore);
    final tile = Semantics(
      container: true,
      label: '$label: $value $unit$semanticsExtra',
      button: info != null,
      hint: info?.buttonLabel,
      onTap: info == null ? null : explain,
      excludeSemantics: true,
      child: StatCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (icon != null) ...[
                Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 15, color: iconColor)),
                const SizedBox(width: 4),
              ],
              Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: palette.textSecondary))),
              if (info != null) Icon(CupertinoIcons.info_circle, size: 16, color: palette.textSecondary),
            ]),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontFamily: LargeTitleHeader.fontFamily,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: unitColor ?? palette.textSecondary),
                  ),
              ]),
            ),
            if (below != null) ...[const SizedBox(height: 6), below!],
          ],
        ),
      ),
    );
    if (info == null) return tile;
    return GestureDetector(key: Key('info_${info!.name}_tile'), behavior: HitTestBehavior.opaque, onTap: explain, child: tile);
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _SparklinePainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final low = values.reduce(math.min);
    final high = values.reduce(math.max);
    final span = math.max(high - low, 10.0);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - 2 - (size.height - 4) * (values[i] - low) / span;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.values != values || old.color != color;
}

/// This habit's achievements, newest first, and the next one.
class _AchievementsCard extends StatelessWidget {
  final Habit habit;
  final int weekStart;

  const _AchievementsCard({required this.habit, required this.weekStart});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final now = clock.now();
    final earned = Achievements.earned([habit], now, weekStart: weekStart)
        .where((a) => a.onShelf && a.habitId == habit.id)
        .toList()
        .reversed
        .toList();
    final next = Achievements.next([habit], now).where((p) => p.habitName == habit.name).firstOrNull;
    return StatCard(
      key: const Key('detailAchievements'),
      padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const StatCardHeading('Achievements'),
        const SizedBox(height: 12),
        if (earned.isEmpty && next == null)
          Text('Achievements for this habit show here.', style: TextStyle(fontSize: 14, color: palette.textSecondary))
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (next != null) ...[AchievementTile.next(next), const SizedBox(width: 10)],
              for (final a in earned) ...[
                AchievementTile.earned(a, onTap: () => showAchievementSheet(context, a, next: next)),
                const SizedBox(width: 10),
              ],
            ]),
          ),
      ]),
    );
  }
}

/// The last six months of this habit, day by day; tapping a day shows it.
class _HeatmapCard extends StatelessWidget {
  final Habit habit;
  final int weekStart;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  const _HeatmapCard({required this.habit, required this.weekStart, required this.selected, required this.onSelect});

  static const weeks = 26;

  @override
  Widget build(BuildContext context) {
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisWeek = DateTime(today.year, today.month, today.day - (today.weekday - weekStart + 7) % 7);
    final from = DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7 * (weeks - 1));
    final days = Insights.days([habit], from: from, to: today, now: now);
    final kept = days.where((d) => !d.isEmpty && d.level > 0).length;
    return StatCard(
      key: const Key('detailHeatmap'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const StatCardHeading('Last 6 months'),
        const SizedBox(height: 12),
        Heatmap(
          days: days,
          weekStart: weekStart,
          selected: selected,
          onSelect: onSelect,
          semanticLabel: '${habit.name}, last 6 months: something done on $kept days',
        ),
      ]),
    );
  }
}

/// The last 8 weeks (or months) as bars.
class _TrendCard extends StatelessWidget {
  final Habit habit;
  final HabitStats stats;
  final Color color;

  const _TrendCard({required this.habit, required this.stats, required this.color});

  static const barArea = 84.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final daily = stats.bars.any((b) => b.label.isNotEmpty);
    final monthly = habit.resetFrequency == ResetFrequency.monthly;
    final kept = stats.bars.where((b) => b.fraction > 0).length;
    return Semantics(
      container: true,
      label: daily
          ? '${stats.barsLabel}: ${stats.bars.map((b) => b.label).join(', ')} days kept'
          : '${stats.barsLabel}: $kept of ${stats.bars.length} with progress',
      excludeSemantics: true,
      child: StatCard(
        key: const Key('detailTrend'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StatCardHeading(
              stats.barsLabel,
              action: daily ? Text(habit.isBreak ? 'days on track' : 'days kept', style: TextStyle(fontSize: 13, color: palette.textSecondary)) : null,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < stats.bars.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (stats.bars[i].label.isNotEmpty)
                          Text(stats.bars[i].label,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: palette.textSecondary)),
                        const SizedBox(height: 4),
                        Container(
                          height: math.max(4, barArea * stats.bars[i].fraction),
                          decoration: BoxDecoration(
                            color: i == stats.bars.length - 1 ? color : palette.tint(habit.color.color),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Text(DateFormat.MMMd().format(stats.bars.first.start),
                    style: TextStyle(fontSize: 11, color: palette.textSecondary)),
              ),
              Text(monthly ? 'This month' : 'This week', style: TextStyle(fontSize: 11, color: palette.textSecondary)),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Why the habit matters, in the person's words. Tap to write or change it.
class _WhyCard extends StatelessWidget {
  final String why;
  final VoidCallback onTap;

  const _WhyCard({required this.why, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Semantics(
      button: true,
      label: why.isEmpty ? 'Why I do this: not written yet' : 'Why I do this: $why',
      hint: why.isEmpty ? 'Write it' : 'Change it',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        key: const Key('detailWhy'),
        color: palette.goldTint,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text('WHY I DO THIS',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: palette.gold)),
                  ),
                  Icon(CupertinoIcons.pencil, size: 16, color: palette.gold),
                ]),
                const SizedBox(height: 8),
                Text(
                  why.isEmpty ? 'What does this habit do for you? Tap to write it down.' : why,
                  style: why.isEmpty
                      ? TextStyle(fontSize: 15, height: 1.35, color: palette.textSecondary)
                      : TextStyle(
                          fontFamily: LargeTitleHeader.fontFamily,
                          fontSize: 18,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: palette.text,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Notes on days, newest first; a note for the chosen day is added here.
class _NotesCard extends StatelessWidget {
  final Habit habit;
  final DateTime selected;
  final DateTime today;
  final VoidCallback onAdd;
  final ValueChanged<DateTime> onOpen;

  const _NotesCard({
    required this.habit,
    required this.selected,
    required this.today,
    required this.onAdd,
    required this.onOpen,
  });

  static const shown = 10;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final days = habit.dayNotes.keys.toList()..sort((a, b) => b.compareTo(a));
    final hasSelected = habit.dayNotes.containsKey(selected);
    final whose = selected == today ? 'today' : DateFormat.MMMd().format(selected);
    return StatCard(
      key: const Key('detailNotes'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatCardHeading(
            'Notes',
            action: PillButton(
              key: const Key('detailAddNote'),
              label: hasSelected ? 'Edit note for $whose' : 'Add note for $whose',
              onPressed: onAdd,
            ),
          ),
          if (days.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('A line about how a day went helps spot what works.',
                  style: TextStyle(fontSize: 14, color: palette.textSecondary)),
            ),
          for (final day in days.take(shown))
            InkWell(
              key: Key('detailNote_${day.year}-${day.month}-${day.day}'),
              onTap: () => onOpen(day),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: palette.separator, width: 0.5))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (day == today ? 'TODAY · ' : '') + DateFormat.MMMEd().format(day).toUpperCase(),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: palette.textSecondary),
                    ),
                    const SizedBox(height: 3),
                    Text(habit.dayNotes[day]!, style: TextStyle(fontSize: 15, height: 1.35, color: palette.text)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A sheet with one text field and Done: the text, or null if dismissed.
/// [validate] keeps it open with a message until the text is right.
Future<String?> showTextSheet(
  BuildContext context, {
  required String title,
  required String initial,
  required Key fieldKey,
  required Key doneKey,
  String? hint,
  String? helper,
  int? maxLength,
  int lines = 1,
  bool numeric = false,
  String? Function(String text)? validate,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppPalette.of(context).surface,
    builder: (context) => _TextSheet(
      title: title,
      initial: initial,
      fieldKey: fieldKey,
      doneKey: doneKey,
      hint: hint,
      helper: helper,
      maxLength: maxLength,
      lines: lines,
      numeric: numeric,
      validate: validate,
    ),
  );
}

class _TextSheet extends StatefulWidget {
  final String title;
  final String initial;
  final Key fieldKey;
  final Key doneKey;
  final String? hint;
  final String? helper;
  final int? maxLength;
  final int lines;
  final bool numeric;
  final String? Function(String text)? validate;

  const _TextSheet({
    required this.title,
    required this.initial,
    required this.fieldKey,
    required this.doneKey,
    required this.hint,
    required this.helper,
    required this.maxLength,
    required this.lines,
    required this.numeric,
    required this.validate,
  });

  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  late final _controller = TextEditingController(text: widget.initial)
    ..selection = TextSelection(baseOffset: 0, extentOffset: widget.initial.length);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() {
    final error = widget.validate?.call(_controller.text);
    if (error != null) return setState(() => _error = error);
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      // Rides above the keyboard
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontFamily: LargeTitleHeader.fontFamily,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: widget.fieldKey,
                controller: _controller,
                autofocus: true,
                maxLength: widget.maxLength,
                minLines: widget.lines == 1 ? 1 : 2,
                maxLines: widget.lines,
                keyboardType: widget.numeric ? TextInputType.number : TextInputType.multiline,
                inputFormatters: widget.numeric ? [FilteringTextInputFormatter.digitsOnly] : null,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: widget.numeric ? TextInputAction.done : null,
                onSubmitted: widget.numeric ? (_) => _done() : null,
                style: widget.numeric
                    ? TextStyle(
                        fontFamily: LargeTitleHeader.fontFamily,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      )
                    : null,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  helperText: widget.helper,
                  helperMaxLines: 2,
                  errorText: _error,
                  errorMaxLines: 2,
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: 16),
              OrbButton(key: widget.doneKey, label: 'Done', onPressed: _done),
            ],
          ),
        ),
      ),
    );
  }
}
