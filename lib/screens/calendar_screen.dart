import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../domain/entities/habit.dart';
import '../domain/entities/habit_category.dart';
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
  HabitCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _selectedHabits = ValueNotifier(_getHabitsForDay(_selectedDay!));
  }

  @override
  void dispose() {
    _selectedHabits.dispose();
    super.dispose();
  }

  List<Habit> _getHabitsForDay(DateTime day) {
    final habitProvider = context.read<HabitProvider>();
    List<Habit> dayHabits = habitProvider.habits.where((habit) {
      // Filter by category if selected
      if (_selectedCategory != null && habit.category != _selectedCategory) {
        return false;
      }
      return true;
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

  Widget _buildCategoryFilters() {
    return Consumer<CategoryProvider>(
      builder: (context, categoryProvider, child) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildCategoryChip(null, 'All', Icons.apps),
              const SizedBox(width: 8),
              ...HabitCategory.values.map((category) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildCategoryChip(
                    category,
                    category.displayName,
                    _getCategoryIcon(category),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryChip(HabitCategory? category, String label, IconData icon) {
    final isSelected = _selectedCategory == category;
    
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
          _selectedCategory = selected ? category : null;
          _selectedHabits.value = _getHabitsForDay(_selectedDay!);
        });
      },
      backgroundColor: category?.defaultColor.withOpacity(0.1),
      selectedColor: category?.defaultColor.withOpacity(0.3) ?? Theme.of(context).primaryColor.withOpacity(0.3),
    );
  }

  IconData _getCategoryIcon(HabitCategory category) {
    switch (category) {
      case HabitCategory.body:
        return Icons.fitness_center;
      case HabitCategory.spirit:
        return Icons.self_improvement;
      case HabitCategory.mind:
        return Icons.psychology;
      case HabitCategory.social:
        return Icons.people;
      case HabitCategory.career:
        return Icons.work;
      case HabitCategory.creative:
        return Icons.palette;
    }
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

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: habits.length,
      itemBuilder: (context, index) {
        final habit = habits[index];
        final progress = habit.getProgressForDate(day);
        final isCompleted = habit.wasCompletedOnDate(day);
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: habit.color.color,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCompleted ? Icons.check : Icons.circle_outlined,
                color: Colors.white,
              ),
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
                Text('Progress: $progress/${habit.target}'),
                LinearProgressIndicator(
                  value: habit.target > 0 ? progress / habit.target : 0,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(habit.color.color),
                ),
              ],
            ),
            trailing: Text(
              habit.category.displayName,
              style: TextStyle(
                color: habit.category.defaultColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
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
                          style: const TextStyle(color: Colors.black87),
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
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                      _selectedHabits.value = _getHabitsForDay(selectedDay);
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