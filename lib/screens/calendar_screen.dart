import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../domain/entities/habit.dart';
import '../domain/entities/category.dart';
import '../domain/entities/reset_frequency.dart';
import '../presentation/widgets/category_icons.dart';
import '../presentation/widgets/habit_icons.dart';
import '../presentation/providers/habit_provider.dart';
import '../presentation/providers/category_provider.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final ValueNotifier<List<Habit>> _selectedHabits;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  // The Calendar keeps its own filter, separate from the Habits screen's
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _selectedDay = _localDay(DateTime.now());
    _selectedHabits = ValueNotifier(_getHabitsForDay(_selectedDay!));
  }

  static DateTime _localDay(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void dispose() {
    _selectedHabits.dispose();
    super.dispose();
  }

  List<Habit> _getHabitsForDay(DateTime day) {
    final habitProvider = context.read<HabitProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final selectedId = _activeFilterId(habitProvider.habits);
    List<Habit> dayHabits = habitProvider.habits.where((habit) {
      // Filter by category if selected
      if (selectedId != null && !categoryProvider.matches(habit, selectedId)) {
        return false;
      }
      // Rest days of a weekday schedule aren't shown or counted
      return habit.isDueOn(day);
    }).toList();

    return dayHabits;
  }

  List<Habit> _getCompletedHabitsForDay(DateTime day) {
    final habits = _getHabitsForDay(day);
    return habits.where((habit) => habit.wasCompletedOnDate(day)).toList();
  }

  Color _getDayColor(DateTime day) {
    final completedHabits = _getCompletedHabitsForDay(day);
    final totalHabits = _getHabitsForDay(day);

    if (totalHabits.isEmpty) return Colors.transparent;

    final completionRate = completedHabits.length / totalHabits.length;
    
    if (completionRate == 1.0) {
      return Colors.green.withOpacity(0.8);
    } else if (completionRate >= 0.5) {
      return Colors.orange.withOpacity(0.6);
    } else if (completionRate > 0) {
      return Colors.red.withOpacity(0.4);
    }
    
    return Colors.grey.withOpacity(0.2);
  }

  /// The chosen filter, or null (All) if it's no longer one of the options,
  /// e.g. the category was deleted.
  String? _activeFilterId(List<Habit> habits) {
    final id = _selectedCategoryId;
    if (id == null) return null;
    final options = context.read<CategoryProvider>().filterOptions(habits);
    return options.any((c) => c.id == id) ? id : null;
  }

  Widget _buildCategoryFilters() {
    return Consumer<CategoryProvider>(
      builder: (context, categoryProvider, child) {
        final habits = context.read<HabitProvider>().habits;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildCategoryChip(null, 'All', Icons.apps),
              const SizedBox(width: 8),
              for (final category in categoryProvider.filterOptions(habits))
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildCategoryChip(category, category.name, category.icon),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryChip(Category? category, String label, IconData icon) {
    final isSelected = _activeFilterId(context.read<HabitProvider>().habits) == category?.id;
    
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedCategoryId = selected ? category?.id : null;
          _selectedHabits.value = _getHabitsForDay(_selectedDay!);
        });
      },
      key: Key('calendarCategoryChip_${category?.id ?? 'all'}'),
      backgroundColor: category?.color.withOpacity(0.1),
      selectedColor: category?.color.withOpacity(0.3) ?? Theme.of(context).primaryColor.withOpacity(0.3),
    );
  }

  Widget _buildDayHabits(DateTime day) {
    final habits = _getHabitsForDay(day);
    
    if (habits.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No habits for this day',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    final isEditable = !DateUtils.dateOnly(day).isAfter(DateUtils.dateOnly(DateTime.now()));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: habits.length,
      itemBuilder: (context, index) {
        final habit = habits[index];
        final loggedThatDay = habit.getProgressForDate(day);
        final periodTotal = habit.progressForPeriodContaining(day);
        final isCompleted = habit.wasCompletedOnDate(day);
        final units = habit.units.isEmpty ? '' : ' ${habit.units}';
        final isDaily = habit.resetFrequency == ResetFrequency.daily;
        
        return Card(
          key: Key('dayHabit_${habit.id}'),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: _HabitDayIcon(
              key: Key('dayHabitIcon_${habit.id}'),
              icon: habitIcon(habit, context.read<CategoryProvider>().resolve(habit.categoryId)),
              color: habit.color.color,
              isCompleted: isCompleted,
            ),
            title: Text(
              habit.name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isDaily
                    ? 'Logged: $loggedThatDay/${habit.target}$units'
                    : 'Logged this day: $loggedThatDay$units · '
                      '${habit.resetFrequency.displayName} total: $periodTotal/${habit.target}'),
                LinearProgressIndicator(
                  value: habit.target > 0 ? (periodTotal / habit.target).clamp(0.0, 1.0) : 0,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(habit.color.color),
                ),
                Text(
                  context.read<CategoryProvider>().resolve(habit.categoryId).name,
                  style: TextStyle(
                    color: context.read<CategoryProvider>().resolve(habit.categoryId).color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            // Editing past days is how missed logs are fixed and streaks repaired
            trailing: isEditable
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: Key('decrementDay_${habit.id}'),
                        icon: const Icon(Icons.remove_circle_outline),
                        tooltip: 'Remove one from this day',
                        onPressed: loggedThatDay > 0
                            ? () => _setLoggedForDay(habit, day, loggedThatDay - 1)
                            : null,
                      ),
                      IconButton(
                        key: Key('incrementDay_${habit.id}'),
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: 'Add one to this day',
                        onPressed: periodTotal < habit.target
                            ? () => _setLoggedForDay(habit, day, loggedThatDay + 1)
                            : null,
                      ),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }

  Future<void> _setLoggedForDay(Habit habit, DateTime day, int amount) async {
    final habitProvider = context.read<HabitProvider>();
    final success = await habitProvider.updateProgressForDate(habit.id, day, amount);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(habitProvider.error ?? 'Could not update that day')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Habit Calendar'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_calendarFormat == CalendarFormat.month 
                ? Icons.view_week 
                : Icons.calendar_month),
            onPressed: () {
              setState(() {
                _calendarFormat = _calendarFormat == CalendarFormat.month
                    ? CalendarFormat.week
                    : CalendarFormat.month;
              });
            },
          ),
        ],
      ),
      body: Consumer<HabitProvider>(
        builder: (context, habitProvider, child) {
          return Column(
            children: [
              _buildCategoryFilters(),
              
              // Calendar Widget
              TableCalendar<Habit>(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDay, day);
                },
                eventLoader: _getHabitsForDay,
                startingDayOfWeek: StartingDayOfWeek.monday,
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  weekendTextStyle: const TextStyle(color: Colors.red),
                  holidayTextStyle: const TextStyle(color: Colors.red),
                  defaultDecoration: BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                ),
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    return Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _getDayColor(day),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        ),
                      ),
                    );
                  },
                  markerBuilder: (context, day, habits) {
                    final completedHabits = _getCompletedHabitsForDay(day);
                    final totalHabits = habits.length;
                    
                    if (totalHabits == 0) return const SizedBox.shrink();
                    
                    return Positioned(
                      bottom: 1,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        width: 16,
                        height: 16,
                        child: Center(
                          child: Text(
                            '${completedHabits.length}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  if (!isSameDay(_selectedDay, selectedDay)) {
                    setState(() {
                      // table_calendar gives UTC midnights; keep local dates in this screen
                      _selectedDay = _localDay(selectedDay);
                      _focusedDay = focusedDay;
                      _selectedHabits.value = _getHabitsForDay(_selectedDay!);
                    });
                  }
                },
                onFormatChanged: (format) {
                  if (_calendarFormat != format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  }
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
              ),
              
              const Divider(),
              
              // Selected Day Details
              Expanded(
                child: ValueListenableBuilder<List<Habit>>(
                  valueListenable: _selectedHabits,
                  builder: (context, habits, _) {
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Habits for ${_selectedDay?.day}/${_selectedDay?.month}/${_selectedDay?.year}',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _buildDayHabits(_selectedDay!),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A habit's icon in a circle: tinted while not done, filled with a check
/// badge once the day (or period) is complete.
class _HabitDayIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isCompleted;

  const _HabitDayIcon({Key? key, required this.icon, required this.color, required this.isCompleted})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isCompleted ? 'completed' : 'not completed',
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: isCompleted ? color : color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(icon, size: 22, color: isCompleted ? Colors.white : color),
              ),
            ),
            if (isCompleted)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  key: const Key('completedBadge'),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                  ),
                  child: const Icon(Icons.check, size: 11, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
