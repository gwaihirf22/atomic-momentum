import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../core/feedback/haptics.dart';
import '../core/theme/app_style.dart';
import '../core/theme/ios_colors.dart';
import '../domain/entities/habit.dart';
import '../domain/entities/reset_frequency.dart';
import '../presentation/providers/category_provider.dart';
import '../presentation/providers/habit_provider.dart';
import '../presentation/providers/settings_provider.dart';
import '../presentation/providers/theme_provider.dart';
import '../presentation/widgets/large_title_scaffold.dart';
import '../presentation/widgets/category_filter_header.dart';
import '../presentation/widgets/category_rings_bar.dart';
import '../presentation/widgets/habit_card.dart';
import '../presentation/widgets/habit_icons.dart';
import '../presentation/widgets/habit_progress_ring.dart';
import '../presentation/widgets/habit_stepper.dart';

/// Any day's habits: a month (or week) of days, each inside a ring that fills
/// with that day's completion, and the selected day's habits below, which
/// can be edited to fix missed logs. Styled like the Habits screen.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  late DateTime _selectedDay;

  // The Calendar keeps its own filter, separate from the Habits screen's
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _selectedDay = _localDay(DateTime.now());
  }

  // table_calendar gives UTC midnights; this screen works in local dates
  static DateTime _localDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime get _today => _localDay(DateTime.now());

  /// The chosen filter, or null (All) if it's no longer one of the options,
  /// e.g. the category was deleted.
  String? _activeFilterId(List<Habit> habits) {
    final id = _selectedCategoryId;
    if (id == null) return null;
    final options = context.read<CategoryProvider>().filterOptions(habits);
    return options.any((c) => c.id == id) ? id : null;
  }

  /// Habits due on [day] (rest days of a weekday schedule are left out),
  /// within the filter.
  List<Habit> _habitsForDay(DateTime day) {
    final habits = context.read<HabitProvider>().habits;
    final categories = context.read<CategoryProvider>();
    final filterId = _activeFilterId(habits);
    return habits
        .where((habit) => filterId == null || categories.matches(habit, filterId))
        .where((habit) => habit.isDueOn(day))
        .toList();
  }

  static double _fractionOn(Habit habit, DateTime day) =>
      habit.target > 0 ? (habit.progressForPeriodContaining(day) / habit.target).clamp(0.0, 1.0) : 0.0;

  /// The first day anything was tracked: no rings before it.
  DateTime? _firstTrackedDay(List<Habit> habits) {
    DateTime? first;
    for (final habit in habits) {
      var start = _localDay(habit.metadata.createdDate);
      for (final day in habit.history.keys) {
        if (day.isBefore(start)) start = day;
      }
      if (first == null || start.isBefore(first)) first = start;
    }
    return first;
  }

  void _toggleCategory(String id) {
    setState(() => _selectedCategoryId = _selectedCategoryId == id ? null : id);
  }

  Future<void> _setLoggedForDay(Habit habit, DateTime day, int amount, {required int periodTotal}) async {
    final logged = habit.getProgressForDate(day);
    Haptics.progressChanged(from: periodTotal, to: periodTotal + amount - logged, target: habit.target);
    final habitProvider = context.read<HabitProvider>();
    final success = await habitProvider.updateProgressForDate(habit.id, day, amount);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't update ${habit.name} for that day. Please try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkIn(context);
    final isMonth = _calendarFormat == CalendarFormat.month;

    return Consumer2<HabitProvider, CategoryProvider>(
      builder: (context, habitProvider, categoryProvider, _) {
        final habits = habitProvider.habits;
        final dayHabits = _habitsForDay(_selectedDay);
        final filterId = _activeFilterId(habits);

        return LargeTitleScaffold(
          title: DateFormat.yMMMM().format(_focusedDay),
          backgroundColor: isDark ? IOSColors.systemBackgroundDark : IOSColors.systemBackground,
          trailing: CupertinoButton(
            key: const Key('calendarFormatToggle'),
            padding: EdgeInsets.zero,
            onPressed: () => setState(() {
              _calendarFormat = isMonth ? CalendarFormat.week : CalendarFormat.month;
            }),
            child: Icon(
              isMonth ? CupertinoIcons.rectangle_split_3x1 : CupertinoIcons.calendar,
              semanticLabel: isMonth ? 'Show one week' : 'Show the whole month',
            ),
          ),
          // The month is the title, with the year above and paging beside it
          header: LargeTitleHeader(
            eyebrow: DateFormat.y().format(_focusedDay),
            title: DateFormat.MMMM().format(_focusedDay),
            titleKey: const Key('calendarMonthTitle'),
            accessory: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _pageButton(CupertinoIcons.chevron_left, isMonth ? 'Previous month' : 'Previous week', -1),
                _pageButton(CupertinoIcons.chevron_right, isMonth ? 'Next month' : 'Next week', 1),
              ],
            ),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: CategoryFilterHeader(
                selected: filterId == null ? null : categoryProvider.resolve(filterId),
                habitCount: dayHabits.length,
                onShowAll: () => setState(() => _selectedCategoryId = null),
                isDark: isDark,
              ),
            ),
            SliverToBoxAdapter(
              child: CategoryRingsBar(
                categories: categoryProvider.filterOptions(habits),
                // The rings show the selected day
                stats: categoryProvider.getCategoryStats(
                  habits.where((h) => h.isDueOn(_selectedDay)).toList(),
                  on: _selectedDay,
                ),
                selectedId: filterId,
                onTap: _toggleCategory,
                isDark: isDark,
              ),
            ),
            SliverToBoxAdapter(child: _buildCalendar(context, habits, isDark)),
            SliverToBoxAdapter(child: _buildDayHeading(context, dayHabits)),
            _buildDayHabits(context, dayHabits),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
    );
  }

  /// Pages the calendar a month (or a week) back or forward.
  Widget _pageButton(IconData icon, String label, int direction) {
    final accent = Theme.of(context).colorScheme.primary;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: 44,
      onPressed: () => setState(() {
        final d = _focusedDay;
        _focusedDay = _calendarFormat == CalendarFormat.month
            ? DateTime(d.year, d.month + direction, 1)
            : DateTime(d.year, d.month, d.day + 7 * direction);
      }),
      child: Icon(icon, size: 22, color: accent, semanticLabel: label),
    );
  }

  Widget _buildCalendar(BuildContext context, List<Habit> habits, bool isDark) {
    final accent = Theme.of(context).colorScheme.primary;
    final label = isDark ? IOSColors.labelDark : IOSColors.label;
    final secondary = secondaryLabel(context);
    final firstTracked = _firstTrackedDay(habits);

    Widget cell(DateTime utcDay, {required bool isSelected, required bool isToday}) {
      final day = _localDay(utcDay);
      final due = _habitsForDay(day);
      // Rings only where there was something to do, from the first tracked day to today
      final tracked = due.isNotEmpty && !day.isAfter(_today) && (firstTracked == null || !day.isBefore(firstTracked));
      final fraction = tracked ? due.map((h) => _fractionOn(h, day)).reduce((a, b) => a + b) / due.length : null;

      return _DayCell(
        key: Key('calendarDay_${day.year}-${day.month}-${day.day}'),
        day: day,
        fraction: fraction,
        isSelected: isSelected,
        isToday: isToday,
        accent: accent,
        labelColor: label,
      );
    }

    return TableCalendar<Habit>(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      calendarFormat: _calendarFormat,
      availableCalendarFormats: const {CalendarFormat.month: 'Month', CalendarFormat.week: 'Week'},
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      // Follows Settings > Start week on (by default, the device's region)
      startingDayOfWeek: StartingDayOfWeek.values[context.watch<SettingsProvider>().firstDayOfWeek - 1],
      rowHeight: 48,
      headerVisible: false,
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: label),
        leftChevronIcon: Icon(CupertinoIcons.chevron_left, size: 20, color: accent, semanticLabel: 'Previous'),
        rightChevronIcon: Icon(CupertinoIcons.chevron_right, size: 20, color: accent, semanticLabel: 'Next'),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: TextStyle(fontSize: 13, color: secondary),
        weekendStyle: TextStyle(fontSize: 13, color: secondary),
      ),
      calendarStyle: const CalendarStyle(outsideDaysVisible: false),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, _) => cell(day, isSelected: false, isToday: false),
        todayBuilder: (context, day, _) => cell(day, isSelected: isSameDay(_selectedDay, day), isToday: true),
        selectedBuilder: (context, day, _) => cell(day, isSelected: true, isToday: isSameDay(day, _today)),
      ),
      onDaySelected: (selectedDay, focusedDay) {
        if (isSameDay(_selectedDay, selectedDay)) return;
        Haptics.selection();
        setState(() {
          _selectedDay = _localDay(selectedDay);
          _focusedDay = focusedDay;
        });
      },
      onFormatChanged: (format) {
        if (_calendarFormat != format) setState(() => _calendarFormat = format);
      },
      // Swiping the grid changes the month in the title
      onPageChanged: (focusedDay) => setState(() => _focusedDay = focusedDay),
    );
  }

  Widget _buildDayHeading(BuildContext context, List<Habit> dayHabits) {
    final isToday = _selectedDay == _today;
    final isFuture = _selectedDay.isAfter(_today);
    final done = dayHabits.where((h) => h.wasCompletedOnDate(_selectedDay)).length;
    final date = DateFormat.MMMMEEEEd().format(_selectedDay);

    final String detail;
    if (dayHabits.isEmpty) {
      detail = 'No habits due this day';
    } else if (isFuture) {
      detail = "Future days can't be logged yet";
    } else {
      detail = '$done of ${dayHabits.length} done';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppStyle.screenPadding, 20, AppStyle.screenPadding, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              isToday ? 'Today · $date' : date,
              key: const Key('calendarDayTitle'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 2),
          Text(detail,
              key: const Key('calendarDayDetail'), style: TextStyle(fontSize: 13, color: secondaryLabel(context))),
        ],
      ),
    );
  }

  Widget _buildDayHabits(BuildContext context, List<Habit> habits) {
    final day = _selectedDay;
    // Editing past days is how missed logs are fixed and streaks repaired
    final isEditable = !day.isAfter(_today);
    final categories = context.read<CategoryProvider>();

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppStyle.screenPadding),
      sliver: SliverList.builder(
        itemCount: habits.length,
        itemBuilder: (context, index) {
          final habit = habits[index];
          return _DayHabitRow(
            habit: habit,
            day: day,
            icon: habitIcon(habit, categories.resolve(habit.categoryId)),
            isEditable: isEditable,
            onSet: (amount, periodTotal) => _setLoggedForDay(habit, day, amount, periodTotal: periodTotal),
          );
        },
      ),
    );
  }
}

/// A day number inside a thin ring that fills with that day's completion.
/// The selected day is a solid accent circle; today's number is in the
/// accent color, as in iOS Calendar.
class _DayCell extends StatelessWidget {
  final DateTime day;

  /// 0–1, or null when there was nothing to track that day (no ring).
  final double? fraction;
  final bool isSelected;
  final bool isToday;
  final Color accent;
  final Color labelColor;

  const _DayCell({
    super.key,
    required this.day,
    required this.fraction,
    required this.isSelected,
    required this.isToday,
    required this.accent,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isSelected
        ? Colors.white
        : isToday
            ? accent
            : labelColor;

    // table_calendar labels each day for VoiceOver with its date; the
    // selected day's heading reads out how much was done
    return Center(
      child: SizedBox(
        width: 40,
        height: 40,
        child: CustomPaint(
          painter:
              fraction == null ? null : RingPainter(fraction: fraction!, color: accent, stroke: 3, trackOpacity: 0.15),
          child: Center(
            child: Container(
              width: 30,
              height: 30,
              decoration: isSelected ? BoxDecoration(color: accent, shape: BoxShape.circle) : null,
              alignment: Alignment.center,
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 15,
                  color: textColor,
                  fontWeight: isSelected || isToday ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One habit on the selected day, styled like the habit cards: its icon in
/// a progress ring (a check when done), the name (crossed out when done),
/// what was logged, and a −/+ stepper for that day.
class _DayHabitRow extends StatelessWidget {
  final Habit habit;
  final DateTime day;
  final IconData icon;
  final bool isEditable;

  /// Sets the amount logged on [day]; also gets the period total before.
  final void Function(int amount, int periodTotal) onSet;

  const _DayHabitRow({
    required this.habit,
    required this.day,
    required this.icon,
    required this.isEditable,
    required this.onSet,
  });

  String _subtitle(int loggedThatDay, int periodTotal) {
    final units = habit.units.isEmpty ? '' : ' ${habit.units}';
    final schedule = habit.schedule;
    if (schedule.frequency == ResetFrequency.daily && schedule.interval == 1) {
      return '$loggedThatDay/${habit.target}$units';
    }
    final period = schedule.interval == 1 ? 'this ${schedule.frequency.periodUnit}' : 'this period';
    return '$loggedThatDay logged · $periodTotal/${habit.target} $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = habit.color.color;
    final loggedThatDay = habit.getProgressForDate(day);
    final periodTotal = habit.progressForPeriodContaining(day);
    final isDone = habit.wasCompletedOnDate(day);
    final subtitle = _subtitle(loggedThatDay, periodTotal);
    final canAdd = isEditable && periodTotal < habit.target;
    final canRemove = isEditable && loggedThatDay > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppStyle.cardGap),
      child: Material(
        key: Key('dayHabit_${habit.id}'),
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppStyle.cardRadius),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          // Same rule as the habit cards: two rows on narrow phones or large text
          child: LayoutBuilder(builder: (context, constraints) {
            final twoRows =
                constraints.maxWidth < HabitCard.twoRowWidth || MediaQuery.textScalerOf(context).scale(1) > 1.15;
            final ring = HabitProgressRing(
              key: Key('dayHabitIcon_${habit.id}'),
              icon: icon,
              color: color,
              fraction: habit.target > 0 ? (periodTotal / habit.target).clamp(0.0, 1.0) : 0,
              isDone: isDone,
              checkKey: const Key('completedBadge'),
              semanticLabel: '${habit.name}, $subtitle',
              onTap: canAdd ? () => onSet(loggedThatDay + 1, periodTotal) : null,
            );
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  habit.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    // Crossed off, like a done list
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.2,
                    color: secondaryLabel(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            );
            final stepper = !isEditable
                ? null
                : HabitStepper(
                    color: color,
                    removeKey: Key('decrementDay_${habit.id}'),
                    addKey: Key('incrementDay_${habit.id}'),
                    removeTooltip: 'Remove one from this day',
                    addTooltip: 'Add one to this day',
                    onRemove: canRemove ? () => onSet(loggedThatDay - 1, periodTotal) : null,
                    onAdd: canAdd ? () => onSet(loggedThatDay + 1, periodTotal) : null,
                  );

            final topRow = Row(children: [
              ring,
              const SizedBox(width: 12),
              Expanded(child: details),
              if (stepper != null && !twoRows) ...[const SizedBox(width: 8), stepper],
            ]);
            if (stepper == null || !twoRows) return topRow;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [topRow, const SizedBox(height: 6), stepper],
            );
          }),
        ),
      ),
    );
  }
}
