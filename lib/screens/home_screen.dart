import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/entities/habit.dart';
import '../domain/entities/habit_category.dart';
import '../presentation/providers/theme_provider.dart';
import '../presentation/providers/habit_provider.dart';
import '../presentation/providers/category_provider.dart';
import 'add_habit_screen.dart';
import 'settings_screen.dart';
import 'calendar_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Load habits when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HabitProvider>().loadHabits();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Momentum'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Calendar',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CalendarScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer2<HabitProvider, CategoryProvider>(
        builder: (context, habitProvider, categoryProvider, child) {
          if (habitProvider.isLoading) {
            return _buildLoadingState();
          }
          
          if (habitProvider.hasError) {
            return _buildErrorState(habitProvider.error!);
          }
          
          final filteredHabits = categoryProvider.filterHabits(habitProvider.habits);
          
          if (filteredHabits.isEmpty) {
            return _buildEmptyState();
          }
          
          return Column(
            children: [
              _buildCategoryFilters(categoryProvider),
              Expanded(child: _buildHabitList(filteredHabits, habitProvider)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddHabitScreen(),
            ),
          ).then((_) {
            // Refresh habits when returning from add screen
            context.read<HabitProvider>().refreshHabits();
          });
        },
        child: const Icon(Icons.add),
        tooltip: 'Add a new habit',
      ),
    );
  }
  
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading your habits...',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          const Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              context.read<HabitProvider>().clearError();
              context.read<HabitProvider>().loadHabits();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.track_changes,
            size: 80,
            color: Theme.of(context).primaryColor.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No habits yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add your first habit',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilters(CategoryProvider categoryProvider) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildCategoryChip(null, 'All', Icons.apps, categoryProvider),
          const SizedBox(width: 8),
          ...HabitCategory.values.map((category) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildCategoryChip(
                category,
                category.displayName,
                _getCategoryIcon(category),
                categoryProvider,
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(
    HabitCategory? category,
    String label,
    IconData icon,
    CategoryProvider categoryProvider,
  ) {
    final isSelected = categoryProvider.selectedCategory == category;
    
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
        if (selected) {
          categoryProvider.setSelectedCategory(category);
        } else {
          categoryProvider.clearSelectedCategory();
        }
      },
      backgroundColor: category?.defaultColor.withOpacity(0.1),
      selectedColor: category?.defaultColor.withOpacity(0.3) ?? 
                    Theme.of(context).primaryColor.withOpacity(0.3),
      checkmarkColor: category?.defaultColor ?? Theme.of(context).primaryColor,
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

  Widget _buildHabitList(List<Habit> habits, HabitProvider habitProvider) {
    return ListView.builder(
      itemCount: habits.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final habit = habits[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            habit.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            habit.category.displayName,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${habit.progress}/${habit.target}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: habit.color.color,
                          ),
                        ),
                        if (habit.streak.current > 0)
                          Text(
                            '🔥 ${habit.streak.current} day streak',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: habit.progressPercentage,
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(habit.color.color),
                  borderRadius: BorderRadius.circular(5),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: habit.progress > 0 && !habitProvider.isPerformingOperation
                          ? () => _updateHabitProgress(habitProvider, habit, habit.progress - 1)
                          : null,
                      color: habit.color.color,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: habit.progress < habit.target && !habitProvider.isPerformingOperation
                          ? () => _updateHabitProgress(habitProvider, habit, habit.progress + 1)
                          : null,
                      color: habit.color.color,
                    ),
                    if (habit.isCompleted)
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Future<void> _updateHabitProgress(HabitProvider habitProvider, Habit habit, int newProgress) async {
    final success = await habitProvider.updateHabitProgress(habit.id, newProgress);
    
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update ${habit.name}'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _updateHabitProgress(habitProvider, habit, newProgress),
          ),
        ),
      );
    }
  }
}