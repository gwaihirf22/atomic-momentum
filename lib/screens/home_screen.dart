import 'package:flutter_slidable/flutter_slidable.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../domain/entities/habit.dart';
import '../domain/entities/category.dart';
import '../core/feedback/haptics.dart';
import '../core/exceptions/friendly_error.dart';
import '../core/theme/ios_colors.dart';
import '../core/theme/ios_typography.dart';
import '../presentation/providers/theme_provider.dart';
import '../presentation/providers/habit_provider.dart';
import '../presentation/providers/category_provider.dart';
import '../presentation/providers/settings_provider.dart';
import '../presentation/widgets/category_filter_header.dart';
import '../presentation/widgets/category_icons.dart';
import '../presentation/widgets/category_rings_bar.dart';
import '../presentation/widgets/confirm_delete_habit.dart';
import '../presentation/widgets/habit_card.dart';
import 'add_habit_screen.dart';
import 'categories_screen.dart';
import 'package:intl/intl.dart';
import '../core/copy/greetings.dart';
import '../presentation/widgets/large_title_scaffold.dart';
import '../presentation/widgets/momentum_ring.dart';
import 'package:clock/clock.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Timer? _midnightTimer;

  // Picked when the app opens or comes back, so it stays put while in use
  String? _greeting;
  DayPart? _greetingPart;

  /// The greeting for [now] on the person's own day (Settings → "My day
  /// starts at"); a new one when the part of the day changes.
  String _greetingFor(DateTime now, TimeOfDay dayStart) {
    final part = Greetings.partOf(now, dayStart: dayStart);
    if (_greeting == null || part != _greetingPart) {
      _greeting = Greetings.pick(now, avoid: _greeting, dayStart: dayStart);
      _greetingPart = part;
    }
    return _greeting!;
  }

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
      // Back in the app: a fresh greeting
      final now = clock.now();
      final dayStart = context.read<SettingsProvider>().dayStart;
      setState(() {
        _greeting = Greetings.pick(now, avoid: _greeting, dayStart: dayStart);
        _greetingPart = Greetings.partOf(now, dayStart: dayStart);
      });
      context.read<HabitProvider>().resetHabitsIfNeeded();
      _scheduleMidnightReset();
    }
  }

  // Every reset boundary (day, week, month) falls on a local midnight
  void _scheduleMidnightReset() {
    _midnightTimer?.cancel();
    final now = clock.now();
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
        final now = clock.now();
        final dayStart = context.watch<SettingsProvider>().dayStart;

        return Consumer2<HabitProvider, CategoryProvider>(
          builder: (context, habitProvider, categoryProvider, child) {
            final momentum = habitProvider.overallMomentum;
            final filteredHabits = categoryProvider.filterHabits(habitProvider.habits);

            return SlidableAutoCloseBehavior(
              child: LargeTitleScaffold(
                title: 'Habits',
                backgroundColor: isDark ? IOSColors.systemBackgroundDark : IOSColors.systemBackground,
                trailing: _buildAddButton(context),
                header: LargeTitleHeader(
                  eyebrow: DateFormat.MMMMEEEEd().format(now),
                  title: _greetingFor(now, dayStart),
                  titleKey: const Key('habitsGreeting'),
                  accessory: momentum == null
                      ? null
                      : MomentumRing(key: const Key('overallMomentum'), momentum: momentum),
                ),
                slivers: [
                  if (habitProvider.isLoading)
                    SliverFillRemaining(hasScrollBody: false, child: _buildLoadingState(isDark))
                  else if (habitProvider.hasError)
                    SliverFillRemaining(hasScrollBody: false, child: _buildErrorState(habitProvider.error!, isDark))
                  else ...[
                    SliverToBoxAdapter(
                      child: CategoryFilterHeader(
                        selected: categoryProvider.selectedCategory,
                        habitCount: filteredHabits.length,
                        onShowAll: categoryProvider.clearSelectedCategory,
                        isDark: isDark,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: CategoryRingsBar(
                        categories: categoryProvider.filterOptions(habitProvider.habits),
                        // Rest-day habits aren't due, so they don't drag a ring down
                        stats: categoryProvider.getCategoryStats(
                            habitProvider.habits.where((h) => h.isDueOn(clock.now())).toList()),
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
                    ),
                    if (filteredHabits.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(isDark, categoryProvider.selectedCategory),
                      )
                    else
                      _buildHabitList(filteredHabits, habitProvider, isDark),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        Navigator.push(
          context,
          CupertinoPageRoute(builder: (context) => const AddHabitScreen()),
        ).then((_) {
          // Refresh habits when returning from add screen
          final habitProvider = context.read<HabitProvider>();
          final categoryProvider = context.read<CategoryProvider>();
          habitProvider.refreshHabits().then((_) {
            categoryProvider.updateAvailableCategories(habitProvider.habits);
          });
        });
      },
      child: const Icon(
        CupertinoIcons.add,
        color: IOSColors.systemBlue,
        size: 24,
        semanticLabel: 'Add habit',
      ),
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
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList.builder(
        itemCount: habits.length,
        itemBuilder: (context, index) {
          final habit = habits[index];
          return HabitCard(
            habit: habit,
            category: context.read<CategoryProvider>().resolve(habit.categoryId),
            onEdit: () => _editHabit(habit),
            onDelete: () => _deleteHabit(habit),
            onSetProgress: (progress) => _updateHabitProgress(habitProvider, habit, progress),
            onSetTwoMinute: (done) => _setTwoMinute(habitProvider, habit, done),
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

  Future<void> _setTwoMinute(HabitProvider habitProvider, Habit habit, bool done) async {
    done ? Haptics.twoMinute() : Haptics.selection();
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final success = await habitProvider.setTwoMinute(habit.id, done);
    if (!mounted) return;

    if (!success) {
      messenger.showSnackBar(SnackBar(content: Text("Couldn't save ${habit.name}.")));
    } else if (done) {
      messenger.showSnackBar(
        SnackBar(
          key: const Key('twoMinuteSnack'),
          content: Text('Two-minute version: ${habit.twoMinute?.description ?? habit.name}. Day kept!'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => habitProvider.setTwoMinute(habit.id, false),
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