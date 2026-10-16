import 'package:flutter_slidable/flutter_slidable.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../domain/entities/habit.dart';
import '../domain/entities/category.dart';
import '../core/feedback/haptics.dart';
import '../presentation/widgets/app_nav_bar.dart';
import '../core/exceptions/friendly_error.dart';
import '../core/theme/ios_colors.dart';
import '../core/theme/ios_typography.dart';
import '../presentation/providers/theme_provider.dart';
import '../presentation/providers/habit_provider.dart';
import '../presentation/providers/category_provider.dart';
import '../presentation/widgets/category_filter_header.dart';
import '../presentation/widgets/category_icons.dart';
import '../presentation/widgets/category_rings_bar.dart';
import '../presentation/widgets/confirm_delete_habit.dart';
import '../presentation/widgets/habit_card.dart';
import 'add_habit_screen.dart';
import 'categories_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnightReset();

    // Load habits when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final habitProvider = context.read<HabitProvider>();
      final categoryProvider = context.read<CategoryProvider>();

      habitProvider.loadHabits().then((_) {
        // Update available categories after habits are loaded
        categoryProvider.updateAvailableCategories(habitProvider.habits);
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The day may have rolled over while the app was in the background
    if (state == AppLifecycleState.resumed) {
      context.read<HabitProvider>().resetHabitsIfNeeded();
      _scheduleMidnightReset();
    }
  }

  // Every reset boundary (day, week, month) falls on a local midnight
  void _scheduleMidnightReset() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextMidnight.difference(now) + const Duration(seconds: 1), () {
      if (!mounted) return;
      context.read<HabitProvider>().resetHabitsIfNeeded();
      _scheduleMidnightReset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkIn(context);
        
        // Material Scaffold hosts SnackBars (delete confirmations, save
        // failures with Retry); Cupertino scaffolds can't show them
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: CupertinoPageScaffold(
          backgroundColor: isDark ? IOSColors.systemBackgroundDark : IOSColors.systemBackground,
          navigationBar: appNavigationBar(
            title: 'Habits',
            isDark: isDark,
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
                  final habitProvider = context.read<HabitProvider>();
                  final categoryProvider = context.read<CategoryProvider>();
                  
                  habitProvider.refreshHabits().then((_) {
                    // Update available categories after refresh
                    categoryProvider.updateAvailableCategories(habitProvider.habits);
                  });
                });
              },
              child: Icon(
                CupertinoIcons.add,
                color: IOSColors.systemBlue,
                size: 24,
                semanticLabel: 'Add habit',
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
                
                return Column(
                  children: [
                    CategoryFilterHeader(
                      selected: categoryProvider.selectedCategory,
                      habitCount: filteredHabits.length,
                      onShowAll: categoryProvider.clearSelectedCategory,
                      isDark: isDark,
                    ),
                    CategoryRingsBar(
                      categories: categoryProvider.filterOptions(habitProvider.habits),
                      // Rest-day habits aren't due, so they don't drag a ring down
                      stats: categoryProvider.getCategoryStats(
                          habitProvider.habits.where((h) => h.isDueOn(DateTime.now())).toList()),
                      selectedId: categoryProvider.selectedCategory?.id,
                      onTap: categoryProvider.toggleCategory,
                      onLongPress: () {
                        HapticFeedback.mediumImpact();
                        Navigator.of(context).push(
                          CupertinoPageRoute(builder: (_) => const CategoriesScreen()),
                        );
                      },
                      isDark: isDark,
                    ),
                    Expanded(
                      child: filteredHabits.isEmpty 
                        ? _buildEmptyState(isDark, categoryProvider.selectedCategory)
                        : _buildHabitList(filteredHabits, habitProvider, isDark),
                    ),
                  ],
                );
              },
            ),
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
              friendlyError(error, fallback: "Your habits couldn't be loaded. Please try again."),
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

  Widget _buildEmptyState(bool isDark, Category? selectedCategory) {
    final isFiltered = selectedCategory != null;
    final title = isFiltered 
        ? 'No ${selectedCategory.name.toLowerCase()} habits yet'
        : 'No habits yet';
    final subtitle = isFiltered
        ? 'Tap the + button to add a ${selectedCategory.name.toLowerCase()} habit, or tap Show all to see all habits'
        : 'Tap the + button to add your first habit';
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isFiltered ? selectedCategory.icon : CupertinoIcons.checkmark_circle,
            size: 80,
            color: isFiltered 
                ? selectedCategory.color.withOpacity(0.5)
                : IOSColors.systemBlue.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: IOSTypography.getHabitTitle(isDark),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              subtitle,
              style: IOSTypography.getHabitSubtitle(isDark),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitList(List<Habit> habits, HabitProvider habitProvider, bool isDark) {
    // One open swipe-action pane at a time across the list
    return SlidableAutoCloseBehavior(
      child: ListView.builder(
        itemCount: habits.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final habit = habits[index];
          return HabitCard(
            habit: habit,
            category: context.read<CategoryProvider>().resolve(habit.categoryId),
            busy: habitProvider.isPerformingOperation,
            onEdit: () => _editHabit(habit),
            onDelete: () => _deleteHabit(habit),
            onSetProgress: (progress) => _updateHabitProgress(habitProvider, habit, progress),
          );
        },
      ),
    );
  }

  Future<void> _updateHabitProgress(HabitProvider habitProvider, Habit habit, int newProgress) async {
    Haptics.progressChanged(from: habit.progress, to: newProgress, target: habit.target);
    final success = await habitProvider.updateHabitProgress(habit.id, newProgress);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Couldn't update ${habit.name}."),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _updateHabitProgress(habitProvider, habit, newProgress),
          ),
        ),
      );
    }
  }

  void _editHabit(Habit habit) {
    // Navigate to AddHabitScreen in edit mode
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => AddHabitScreen(editHabit: habit),
      ),
    ).then((_) {
      // Refresh habits when returning from edit screen
      context.read<HabitProvider>().refreshHabits();
    });
  }

  Future<void> _deleteHabit(Habit habit) async {
    if (!await confirmDeleteHabit(context, habit.name) || !mounted) return;

    final success = await context.read<HabitProvider>().deleteHabit(habit.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '${habit.name} deleted' : "Couldn't delete ${habit.name}. Please try again."),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}