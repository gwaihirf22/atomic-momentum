import 'package:flutter_slidable/flutter_slidable.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../domain/entities/habit.dart';
import '../domain/entities/momentum.dart';
import '../domain/services/today.dart';
import '../domain/entities/category.dart';
import '../core/feedback/haptics.dart';
import '../core/exceptions/friendly_error.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_style.dart';
import '../core/theme/ios_typography.dart';
import '../presentation/providers/theme_provider.dart';
import '../presentation/providers/habit_provider.dart';
import '../presentation/providers/category_provider.dart';
import '../presentation/providers/settings_provider.dart';
import '../presentation/widgets/freezes_settings_section.dart';
import '../presentation/widgets/category_filter_header.dart';
import '../presentation/widgets/category_icons.dart';
import '../presentation/widgets/category_rings_bar.dart';
import '../presentation/widgets/confirm_delete_habit.dart';
import '../presentation/widgets/habit_card.dart';
import '../presentation/widgets/hold_undo_strip.dart';
import 'habit_detail_screen.dart';
import 'habit_editor_screen.dart';
import 'categories_screen.dart';
import 'package:intl/intl.dart';
import '../core/copy/greetings.dart';
import '../core/services/notification_service.dart';
import '../presentation/widgets/large_title_scaffold.dart';
import '../presentation/widgets/momentum_ring.dart';
import 'package:clock/clock.dart';
import '../presentation/tour/world_scope.dart';
import '../presentation/tour/tour_anchor.dart';
import '../presentation/tour/tour_events.dart';
import '../presentation/layout/app_layout.dart';
import '../presentation/layout/habit_pages.dart';
import '../presentation/layout/form_sheet.dart';

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

  /// Whether everything due today was done at the last look (null before
  /// the habits had loaded), and how many times it has just become so.
  bool? _allDone;
  int _burst = 0;

  /// The greeting for [now] on the person's own day (Settings → "My day
  /// starts at"); a new one when the part of the day changes.
  String _greetingFor(DateTime now, TimeOfDay dayStart, GreetingFacts facts) {
    final part = Greetings.partOf(now, dayStart: dayStart);
    if (_greeting == null || part != _greetingPart) _pickGreeting(now, dayStart, facts);
    return _greeting!;
  }

  /// A new greeting, taking its turn (one not shown lately), remembered.
  void _pickGreeting(DateTime now, TimeOfDay dayStart, GreetingFacts facts) {
    final settings = context.read<SettingsProvider>();
    final seen = settings.greetingsSeen;
    final line = Greetings.pick(now, avoid: _greeting, dayStart: dayStart, facts: facts, seen: seen);
    _greeting = line;
    _greetingPart = Greetings.partOf(now, dayStart: dayStart);
    // The example habits' greetings don't take the person's turns
    if (!_demo) unawaited(settings.setGreetingsSeen(Greetings.remember(seen, line)));
  }

  /// What the greeting can say from the person's own day.
  static GreetingFacts _factsOf(Today today, Momentum? momentum) {
    final best = today.bestStreak;
    return GreetingFacts(
      due: today.due,
      done: today.done,
      streak: best == null
          ? null
          : (
              name: best.habit.name,
              length: best.length,
              unit: best.habit.schedule.interval == 1 ? best.habit.resetFrequency.periodUnit : null,
            ),
      atRisk: today.atRisk?.name,
      level: momentum?.level,
    );
  }

  /// Everything due today has just been done (or undone): a celebratory
  /// greeting, and while the app is open, a burst of the ring's glow and a
  /// haptic. Opened on a day already done, just the greeting.
  void _watchAllDone(bool allDone, DateTime now, TimeOfDay dayStart, GreetingFacts facts) {
    final was = _allDone;
    _allDone = allDone;
    if (was == allDone || (was == null && !allDone)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _pickGreeting(now, dayStart, facts);
        if (was == false && allDone && !_demo) {
          _burst++;
          Haptics.allDone();
        }
      });
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _habitsForNotices = context.read<HabitProvider>()..addListener(_showHealthNotice);
    _scheduleMidnightReset();
    // Taps on notifications are for the person's own habits, never a tour's
    _demo = WorldScope.isDemo(context);
    if (!_demo) NotificationService.focusRequests.addListener(_onFocusRequest);

    // Load habits when screen initializes (back from a tour they already
    // are: then only a new day matters, not a whole launch's reload)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final habitProvider = context.read<HabitProvider>();
      final categoryProvider = context.read<CategoryProvider>();
      final loaded = habitProvider.state == HabitProviderState.loaded;

      (loaded ? habitProvider.resetHabitsIfNeeded() : habitProvider.loadHabits()).then((_) {
        if (!mounted) return;
        // Update available categories after habits are loaded
        categoryProvider.updateAvailableCategories(habitProvider.habits);
        // A notification tap may have launched the app
        if (!_demo) _onFocusRequest();
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _habitsForNotices.removeListener(_showHealthNotice);
    NotificationService.focusRequests.removeListener(_onFocusRequest);
    _midnightTimer?.cancel();
    _highlightTimer?.cancel();
    for (final timer in _holdTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The day may have rolled over while the app was in the background
    if (state == AppLifecycleState.resumed) {
      // Back in the app: a fresh greeting
      final now = clock.now();
      final dayStart = context.read<SettingsProvider>().dayStart;
      final habits = context.read<HabitProvider>();
      setState(() => _pickGreeting(now, dayStart, _factsOf(Today.of(habits.habits, now), habits.overallMomentum)));
      // A new day first, then whatever Health has recorded since
      habits.resetHabitsIfNeeded().then((_) => habits.syncHealth());
      _scheduleMidnightReset();
    }
  }

  late final HabitProvider _habitsForNotices;

  /// Showing a tour's example habits.
  bool _demo = false;

  /// A change that couldn't go to Health (it came from Health itself).
  /// Freezes today (or takes the freeze back), from the card's swipe actions.
  Future<void> _toggleFreeze(HabitProvider habits, Habit habit) async {
    final now = clock.now();
    final frozen = habit.isFrozenOn(now);
    final ok = frozen ? await habits.unfreeze(habit.id, now) : await habits.freeze(habit.id, now);
    if (!mounted) return;
    final left = habits.freezes?.available;
    final message = !ok
        ? habits.error ?? "Couldn't freeze ${habit.name}"
        : frozen
            ? 'Unfrozen: the freeze is back${left == null ? '' : ' ($left left)'}'
            : '${habit.name} is frozen for today${left == null ? '' : ' · $left left'}';
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Also "Your freeze came back" (a frozen day kept anyway).
  void _showHealthNotice() {
    final notice = _habitsForNotices.takeHealthNotice() ?? _habitsForNotices.takeFreezeNotice();
    if (notice == null || !mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(notice)));
  }

  // Every reset boundary (day, week, month) falls on a local midnight
  void _scheduleMidnightReset() {
    _midnightTimer?.cancel();
    final now = clock.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextMidnight.difference(now) + const Duration(seconds: 1), () {
      if (!mounted) return;
      final habits = context.read<HabitProvider>();
      habits.resetHabitsIfNeeded().then((_) => habits.syncHealth(force: true));
      _scheduleMidnightReset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final palette = AppPalette.of(context);
        final now = clock.now();
        final dayStart = context.watch<SettingsProvider>().dayStart;

        return Consumer2<HabitProvider, CategoryProvider>(
          builder: (context, habitProvider, categoryProvider, child) {
            final momentum = habitProvider.overallMomentum;
            final filteredHabits = categoryProvider.filterHabits(habitProvider.habits);
            final today = Today.of(habitProvider.habits, now);
            final facts = _factsOf(today, momentum);
            if (habitProvider.state == HabitProviderState.loaded) _watchAllDone(today.allDone, now, dayStart, facts);

            return SlidableAutoCloseBehavior(
              child: LargeTitleScaffold(
                maxContentWidth: 760,
                title: 'Habits',
                backgroundColor: palette.background,
                header: LargeTitleHeader(
                  eyebrow: DateFormat.MMMMEEEEd().format(now),
                  title: _greetingFor(now, dayStart, facts),
                  titleKey: const Key('habitsGreeting'),
                  accessory: momentum == null
                      ? null
                      : TourAnchor(
                          id: TourAnchorId.overallMomentum,
                          child: MomentumRing(
                            key: const Key('overallMomentum'),
                            momentum: momentum,
                            glowing: today.allDone,
                            burst: _burst,
                          ),
                        ),
                ),
                slivers: [
                  if (habitProvider.isLoading)
                    SliverFillRemaining(hasScrollBody: false, child: _buildLoadingState(palette))
                  else if (habitProvider.hasError)
                    SliverFillRemaining(hasScrollBody: false, child: _buildErrorState(habitProvider.error!, palette))
                  else ...[
                    if (habitProvider.onVacation)
                      SliverToBoxAdapter(
                          child: _VacationBanner(back: habitProvider.vacationBack, onEnd: habitProvider.endVacation)),
                    SliverToBoxAdapter(
                      child: CategoryFilterHeader(
                        selected: categoryProvider.selectedCategory,
                        habitCount: filteredHabits.length,
                        onShowAll: categoryProvider.clearSelectedCategory,
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
                        onLongPress: _arrange,
                      ),
                    ),
                    if (filteredHabits.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(palette, categoryProvider.selectedCategory),
                      )
                    else
                      _buildHabitList(filteredHabits, habitProvider),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingState(AppPalette palette) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CupertinoActivityIndicator(
            color: palette.text,
            radius: 20.0,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading your habits...',
            style: IOSTypography.habitSubtitle(palette),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, AppPalette palette) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.exclamationmark_triangle,
            size: 80,
            color: palette.danger,
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: IOSTypography.habitTitle(palette),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              friendlyError(error, fallback: "Your habits couldn't be loaded. Please try again."),
              style: IOSTypography.habitSubtitle(palette),
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

  Widget _buildEmptyState(AppPalette palette, Category? selectedCategory) {
    final isFiltered = selectedCategory != null;
    // The iPad's sidebar has Add habit at its top; phones have + in the bar
    final addWhere = AppLayout.of(context).hasSidebar ? 'Tap Add habit' : 'Tap + below';
    final title = isFiltered 
        ? 'No ${selectedCategory.name.toLowerCase()} habits yet'
        : 'No habits yet';
    final subtitle = isFiltered
        ? '$addWhere to add a ${selectedCategory.name.toLowerCase()} habit, or tap Show all to see all habits'
        : '$addWhere to add your first habit';
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isFiltered ? selectedCategory.icon : CupertinoIcons.checkmark_circle,
            size: 80,
            color: isFiltered 
                ? palette.habitColor(selectedCategory.color).withOpacity(0.5)
                : palette.accent.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: IOSTypography.habitTitle(palette),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              subtitle,
              style: IOSTypography.habitSubtitle(palette),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitList(List<Habit> habits, HabitProvider habitProvider) {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      // Every card is built (lists are short; a sliver list builds lazily),
      // so a tapped notification can scroll to any of them
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final habit in habits)
              HabitCard(
                key: _cardKeys.putIfAbsent(habit.id, GlobalKey.new),
                // Tapped from a notification, or showing beside the list (iPad)
                highlighted: habit.id == _highlightedId || HabitPages.isSelected(context, habit.id),
                habit: habit,
                category: context.read<CategoryProvider>().resolve(habit.categoryId),
                onEdit: () => _editHabit(habit),
                onOpen: () => _openHabit(habit),
                onDelete: () => _deleteHabit(habit),
                onSetProgress: (progress) => _updateHabitProgress(habitProvider, habit, progress),
                onSetTwoMinute: (done) => _setTwoMinute(habitProvider, habit, done),
                onHold: () => _hold(habitProvider, habit),
                holdUndo: _holdUndos[habit.id],
                onFreeze: () => _toggleFreeze(habitProvider, habit),
                onArrange: () => _arrange(habit: habit),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------- notification taps

  final Map<String, GlobalKey> _cardKeys = {};
  String? _highlightedId;
  Timer? _highlightTimer;

  /// A notification was tapped: once the tab bar has switched here and the
  /// habits are loaded, scroll to that habit's card and highlight it.
  void _onFocusRequest() {
    if (NotificationService.focusRequests.value == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showRequestedHabit());
    WidgetsBinding.instance.scheduleFrame();
  }

  void _showRequestedHabit() {
    final request = NotificationService.focusRequests.value;
    if (request == null || !mounted) return;
    final habits = context.read<HabitProvider>();
    // Not loaded yet (the app was just launched): loadHabits calls back
    if (habits.state != HabitProviderState.loaded) return;
    NotificationService.focusRequests.value = null;

    final habit = habits.getHabitById(request.habitId);
    if (habit == null) return; // deleted since: the list is enough
    final categories = context.read<CategoryProvider>();
    if (!categories.filterHabits([habit]).contains(habit)) categories.clearSelectedCategory();

    setState(() => _highlightedId = habit.id);
    // Beside the list on a wide iPad window, its page opens too
    HabitPages.selectIfPane(context, habit.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final card = _cardKeys[habit.id]?.currentContext;
      if (card != null && card.mounted) {
        Scrollable.ensureVisible(card, alignment: 0.3, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
      }
    });
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _highlightedId = null);
    });
  }

  // ---------------------------------------------- holding a ring

  final Map<String, HoldUndo> _holdUndos = {};
  final Map<String, Timer> _holdTimers = {};

  /// Holding a habit's ring finishes it, or clears its period once it's
  /// done. Either can be undone for a few seconds, so a hold by accident
  /// costs nothing.
  Future<void> _hold(HabitProvider habitProvider, Habit habit) async {
    final now = clock.now();
    final before = habit.periodDays(now);
    final finishing = !habit.isCompleted;
    Haptics.held();
    // The change shows at once (saving carries on behind), and so does Undo
    final saving = finishing
        ? habitProvider.updateHabitProgress(habit.id, habit.target)
        : habitProvider.setDays(habit.id, {for (final day in before.keys) day: 0});
    _offerUndo(
      habit.id,
      HoldUndo(
        message: finishing ? 'Marked done' : 'Cleared',
        finished: finishing,
        onUndo: () {
          TourEvents.emit(HoldUndone(habit.id));
          _endUndo(habit.id);
          Haptics.selection();
          habitProvider.setDays(habit.id, before);
        },
      ),
    );
    if (await saving || !mounted) return;
    _endUndo(habit.id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Couldn't update ${habit.name}.")));
  }

  void _offerUndo(String habitId, HoldUndo undo) {
    _holdTimers[habitId]?.cancel();
    setState(() => _holdUndos[habitId] = undo);
    _holdTimers[habitId] = Timer(HoldUndo.duration, () => _endUndo(habitId));
  }

  void _endUndo(String habitId) {
    _holdTimers.remove(habitId)?.cancel();
    if (mounted && _holdUndos.containsKey(habitId)) setState(() => _holdUndos.remove(habitId));
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

  /// The habit's page, in this tab (so the tab bar steps aside).
  /// Holding a category, or a card (that habit shown on Arrange).
  void _arrange({Habit? habit}) => CategoriesScreen.open(context, habitId: habit?.id);

  void _openHabit(Habit habit) => HabitPages.open(context, habit.id);

  void _editHabit(Habit habit) {
    // Over the tabs, so the tab bar never covers the form's Save button
    Navigator.of(context, rootNavigator: true).push(
      FormSheet.route<void>(context, (context) => HabitEditorScreen(editHabit: habit)),
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
/// While vacation mode is on: nothing is due, with a way to end it.
class _VacationBanner extends StatelessWidget {
  /// The planned return day, if there is one.
  final DateTime? back;
  final VoidCallback onEnd;

  const _VacationBanner({required this.back, required this.onEnd});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppStyle.screenPadding, 4, AppStyle.screenPadding, 8),
      child: Container(
        key: const Key('vacationBanner'),
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        decoration: BoxDecoration(color: palette.tint(palette.ice), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(CupertinoIcons.airplane, size: 18, color: palette.ice),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              back == null
                  ? 'On vacation · nothing is due. Streaks and momentum hold.'
                  : 'On vacation until ${FreezesSettingsSection.dayLabel(back!)} · nothing is due till then.',
              style: TextStyle(fontSize: 14, color: palette.text),
            ),
          ),
          TextButton(key: const Key('vacationEnd'), onPressed: onEnd, child: const Text('Turn off')),
        ]),
      ),
    );
  }
}
