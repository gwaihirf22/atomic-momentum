import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../domain/entities/habit.dart';
import '../domain/entities/habit_category.dart';
import '../core/theme/ios_colors.dart';
import '../core/theme/ios_typography.dart';
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
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.themeMode == ThemeMode.dark ||
            (themeProvider.themeMode == ThemeMode.system &&
                MediaQuery.platformBrightnessOf(context) == Brightness.dark);
        
        return CupertinoPageScaffold(
          backgroundColor: isDark ? IOSColors.systemBackgroundDark : IOSColors.systemBackground,
          navigationBar: CupertinoNavigationBar(
            backgroundColor: isDark ? IOSColors.systemBackgroundDark : IOSColors.systemBackground,
            border: Border(
              bottom: BorderSide(
                color: isDark ? IOSColors.separatorDark : IOSColors.separator,
                width: 0.5,
              ),
            ),
            middle: Text(
              'Habits',
              style: IOSTypography.getHabitTitle(isDark),
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => AddHabitScreen(),
                  ),
                ).then((_) {
                  // Refresh habits when returning from add screen
                  context.read<HabitProvider>().refreshHabits();
                });
              },
              child: Icon(
                CupertinoIcons.add,
                color: IOSColors.systemBlue,
                size: 24,
              ),
            ),
          ),
          child: SafeArea(
            child: Consumer2<HabitProvider, CategoryProvider>(
              builder: (context, habitProvider, categoryProvider, child) {
                if (habitProvider.isLoading) {
                  return _buildLoadingState(isDark);
                }
                
                if (habitProvider.hasError) {
                  return _buildErrorState(habitProvider.error!, isDark);
                }
                
                final filteredHabits = categoryProvider.filterHabits(habitProvider.habits);
                
                if (filteredHabits.isEmpty) {
                  return _buildEmptyState(isDark);
                }
                
                return Column(
                  children: [
                    _buildCategoryFilters(categoryProvider, isDark),
                    Expanded(child: _buildHabitList(filteredHabits, habitProvider, isDark)),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CupertinoActivityIndicator(
            color: isDark ? IOSColors.labelDark : IOSColors.label,
            radius: 20.0,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading your habits...',
            style: IOSTypography.getHabitSubtitle(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.exclamationmark_triangle,
            size: 80,
            color: IOSColors.systemRed,
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: IOSTypography.getHabitTitle(isDark),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              error,
              style: IOSTypography.getHabitSubtitle(isDark),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          CupertinoButton.filled(
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

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.checkmark_circle,
            size: 80,
            color: IOSColors.systemBlue.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No habits yet',
            style: IOSTypography.getHabitTitle(isDark),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'Tap the + button to add your first habit',
              style: IOSTypography.getHabitSubtitle(isDark),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilters(CategoryProvider categoryProvider, bool isDark) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildCategoryChip(null, 'All', CupertinoIcons.square_grid_2x2, categoryProvider, isDark),
          const SizedBox(width: 8),
          ...HabitCategory.values.map((category) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildCategoryChip(
                category,
                category.displayName,
                _getCategoryIcon(category),
                categoryProvider,
                isDark,
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
    bool isDark,
  ) {
    final isSelected = categoryProvider.selectedCategory == category;
    final chipColor = category?.defaultColor ?? IOSColors.systemBlue;
    
    return GestureDetector(
      onTap: () {
        if (isSelected) {
          categoryProvider.clearSelectedCategory();
        } else {
          categoryProvider.setSelectedCategory(category);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected 
            ? chipColor.withOpacity(0.2)
            : (isDark ? IOSColors.tertiarySystemFill : IOSColors.secondarySystemFill),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
              ? chipColor 
              : (isDark ? IOSColors.separatorDark : IOSColors.separator),
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon, 
              size: 16,
              color: isSelected 
                ? chipColor 
                : (isDark ? IOSColors.labelDark : IOSColors.label),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: IOSTypography.getCategoryText(isDark).copyWith(
                color: isSelected 
                  ? chipColor 
                  : (isDark ? IOSColors.labelDark : IOSColors.label),
                fontWeight: isSelected ? IOSTypography.semibold : IOSTypography.regular,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(HabitCategory category) {
    switch (category) {
      case HabitCategory.body:
        return CupertinoIcons.heart_fill;
      case HabitCategory.spirit:
        return CupertinoIcons.leaf_arrow_circlepath;
      case HabitCategory.mind:
        return CupertinoIcons.book_fill;
      case HabitCategory.social:
        return CupertinoIcons.person_2_fill;
      case HabitCategory.career:
        return CupertinoIcons.briefcase_fill;
      case HabitCategory.creative:
        return CupertinoIcons.paintbrush_fill;
    }
  }

  Widget _buildHabitList(List<Habit> habits, HabitProvider habitProvider, bool isDark) {
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