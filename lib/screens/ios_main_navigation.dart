import 'dart:math' as math;
import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/feedback/haptics.dart';
import '../core/injection/injection_container.dart';
import '../core/services/achievement_store.dart';
import '../core/services/notification_service.dart';
import '../core/theme/app_palette.dart';
import '../domain/services/achievements.dart';
import '../presentation/providers/category_provider.dart';
import '../presentation/providers/habit_provider.dart';
import '../presentation/providers/settings_provider.dart';
import '../presentation/widgets/achievement_widgets.dart';
import '../presentation/widgets/floating_tab_bar.dart';
import '../presentation/widgets/tab_swipe.dart';
import 'habit_editor_screen.dart';
import 'home_screen.dart';
import 'calendar_screen.dart';
import 'insights_screen.dart';
import 'settings_screen.dart';

/// The app's main screen: four tabs, each with its own navigation stack,
/// under the floating tab bar, whose Habits tab turns into "+" for adding.
/// A sideways swipe on a tab's first page slides to the next or previous
/// tab, and sliding a finger along the bar picks the tab under it.
class IOSMainNavigation extends StatefulWidget {
  const IOSMainNavigation({Key? key}) : super(key: key);

  /// Opens New Habit over everything (the tab bar included), from anywhere.
  static Future<void> addHabit(BuildContext context) async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(fullscreenDialog: true, builder: (_) => const HabitEditorScreen()),
    );
    if (!context.mounted) return;
    final habitProvider = context.read<HabitProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    await habitProvider.refreshHabits();
    categoryProvider.updateAvailableCategories(habitProvider.habits);
  }

  @override
  State<IOSMainNavigation> createState() => _IOSMainNavigationState();
}

class _IOSMainNavigationState extends State<IOSMainNavigation> with SingleTickerProviderStateMixin {
  static const _tabs = [
    FloatingTab(
      label: 'Habits',
      icon: CupertinoIcons.checkmark_circle,
      activeIcon: CupertinoIcons.checkmark_circle_fill,
      addLabel: 'Add habit',
    ),
    FloatingTab(label: 'Calendar', icon: CupertinoIcons.calendar, activeIcon: CupertinoIcons.calendar),
    FloatingTab(label: 'Insights', icon: CupertinoIcons.chart_bar, activeIcon: CupertinoIcons.chart_bar_fill),
    FloatingTab(label: 'Settings', icon: CupertinoIcons.settings, activeIcon: CupertinoIcons.settings_solid),
  ];

  static const _screens = <Widget>[HomeScreen(), CalendarScreen(), InsightsScreen(), SettingsScreen()];

  final _navigators = [for (final _ in _tabs) GlobalKey<NavigatorState>()];
  late final _observers = [for (var i = 0; i < _tabs.length; i++) _StackObserver(() => _stackChanged(i))];

  int _index = 0;

  /// When the current tab was chosen: Habits' "+" ignores a tap right after
  /// arriving, so a quick double-tap from another tab doesn't open Add.
  DateTime? _selectedAt;
  static const _addGuard = Duration(milliseconds: 400);

  /// How far the current tab is slid sideways by a swipe, in points
  /// (negative: towards the next tab), with the tab it reveals.
  late final _slide = AnimationController.unbounded(vsync: this);
  int? _revealed;
  double _width = 0;

  /// Tabs are built the first time they're shown, then kept.
  final _opened = <int>{0};

  /// Tabs with a page open on top of their first one: the bar hides there.
  final _deep = <int>{};

  late final HabitProvider _habits;

  /// An achievement's sheet is open.
  bool _celebrating = false;

  @override
  void initState() {
    super.initState();
    _habits = context.read<HabitProvider>()..addListener(_checkAchievements);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAchievements());
    NotificationService.focusRequests.addListener(_showHabits);
    // A notification tap that launched the app arrives before this screen
    if (NotificationService.focusRequests.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showHabits());
    }
  }

  @override
  void dispose() {
    _habits.removeListener(_checkAchievements);
    NotificationService.focusRequests.removeListener(_showHabits);
    _slide.dispose();
    super.dispose();
  }

  /// Celebrates an achievement just earned (today or yesterday), once. Ones
  /// found in older history, or there before the first check, are filed on
  /// the shelf quietly. Waits while Add, Edit or a sheet is open.
  void _checkAchievements() {
    if (_celebrating || !mounted || _habits.state != HabitProviderState.loaded) return;
    final store = get<AchievementStore>();
    final now = clock.now();
    final weekStart = context.read<SettingsProvider>().firstDayOfWeek;
    final earned = Achievements.earned(_habits.habits, now, weekStart: weekStart);
    if (!store.started) {
      store.markSeen(earned.map((a) => a.id));
      return;
    }
    final seen = store.seen;
    final fresh = earned.where((a) => !seen.contains(a.id)).toList();
    if (fresh.isEmpty) return;

    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final recent = fresh.where((a) => !a.earnedOn.isBefore(yesterday)).toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));
    if (recent.isNotEmpty && Navigator.of(context, rootNavigator: true).canPop()) return;
    store.markSeen(fresh.map((a) => a.id));
    if (recent.isEmpty) return;

    final achievement = recent.first;
    final next = Achievements.next(_habits.habits, now)
        .where((p) => p.habitName != null && p.habitName == achievement.habitName)
        .firstOrNull;
    _celebrating = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) await showAchievementSheet(context, achievement, isNew: true, next: next);
      _celebrating = false;
    });
  }

  void _stackChanged(int tab) {
    // Navigators report changes while they build; update after the frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final deep = _navigators[tab].currentState?.canPop() ?? false;
      if (deep != _deep.contains(tab)) setState(() => deep ? _deep.add(tab) : _deep.remove(tab));
    });
  }

  void _select(int index) {
    if (index == _index) {
      // Tapping the current tab goes back to its first page, as in iOS
      _navigators[index].currentState?.popUntil((route) => route.isFirst);
      return;
    }
    _switchTo(index);
  }

  /// Shows [index] (from a tap, a swipe or sliding along the bar).
  void _switchTo(int index) {
    _endSlide();
    if (index == _index) return;
    setState(() {
      _index = index;
      _opened.add(index);
      _selectedAt = clock.now();
    });
  }

  void _slideAlongBar(int index) {
    if (index == _index) return;
    Haptics.selection();
    _switchTo(index);
  }

  void _endSlide() {
    _slide.stop();
    _slide.value = 0;
    _revealed = null;
  }

  void _swipeStart(DragStartDetails _) => _slide.stop();

  void _swipeUpdate(DragUpdateDetails details) {
    final offset = _slide.value + details.delta.dx;
    final next = offset < 0 ? _index + 1 : _index - 1;
    if (next < 0 || next >= _tabs.length) {
      // Past the first or last tab: it gives a little, then stops
      _revealed = null;
      _slide.value = (offset.sign * math.min(offset.abs(), 60.0));
      return;
    }
    if (next != _revealed) setState(() => _opened.add(_revealed = next));
    _slide.value = offset.clamp(-_width, _width);
  }

  void _swipeEnd(DragEndDetails details) {
    final offset = _slide.value;
    final velocity = details.primaryVelocity ?? 0;
    final next = _revealed;
    final goes = next != null &&
        offset != 0 &&
        (offset.abs() > _width / 3 || (velocity.abs() > 400 && velocity.sign == offset.sign));
    if (!goes) {
      _slide.animateTo(0, duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic);
      return;
    }
    _slide
        .animateTo(offset.sign * _width, duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic)
        .whenCompleteOrCancel(() {
      if (!mounted || _revealed != next || _slide.value.abs() < _width) return;
      Haptics.selection();
      _switchTo(next);
    });
  }

  void _add() {
    final at = _selectedAt;
    if (at != null && clock.now().difference(at) < _addGuard) return;
    IOSMainNavigation.addHabit(context);
  }

  /// A notification was tapped: show the Habits list (the Habits screen
  /// then scrolls to the habit), closing anything open on top of it.
  void _showHabits() {
    if (NotificationService.focusRequests.value == null) return;
    _endSlide();
    if (_index != 0) setState(() => _index = 0);
    // Add and Edit open above the tabs; pages and sheets open inside them
    if (mounted) Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
    _navigators[0].currentState?.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final showBar = !_deep.contains(_index);

    final tabs = [
      for (var i = 0; i < _tabs.length; i++)
        _opened.contains(i)
            ? CupertinoTabView(
                navigatorKey: _navigators[i],
                navigatorObservers: [_observers[i]],
                builder: (context) => _screens[i],
              )
            : const SizedBox.shrink(),
    ];

    return ColoredBox(
      color: palette.background,
      child: Stack(
        children: [
          Positioned.fill(
            child: TabBarInset(
              height: FloatingTabBar.coveredHeight(safeBottom),
              child: LayoutBuilder(builder: (context, constraints) {
                _width = constraints.maxWidth;
                return RawGestureDetector(
                  // Only on a tab's first page; pages pushed on it swipe back
                  gestures: showBar
                      ? {
                          TabSwipeRecognizer: GestureRecognizerFactoryWithHandlers<TabSwipeRecognizer>(
                            () => TabSwipeRecognizer(debugOwner: this),
                            (recognizer) => recognizer
                              ..onStart = _swipeStart
                              ..onUpdate = _swipeUpdate
                              ..onEnd = _swipeEnd,
                          ),
                        }
                      : const {},
                  child: AnimatedBuilder(
                    animation: _slide,
                    builder: (context, _) {
                      final offset = _slide.value;
                      final revealed = offset == 0 ? null : _revealed;
                      return Stack(
                        children: [
                          for (var i = 0; i < _tabs.length; i++)
                            Offstage(
                              offstage: i != _index && i != revealed,
                              child: Transform.translate(
                                offset: Offset(
                                  i == _index ? offset : (i == revealed ? offset + (i > _index ? _width : -_width) : 0),
                                  0,
                                ),
                                child: IgnorePointer(
                                  ignoring: i != _index,
                                  child: TickerMode(
                                    enabled: i == _index,
                                    child: FocusScope(canRequestFocus: i == _index, child: tabs[i]),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                );
              }),
            ),
          ),
          Positioned(
            left: FloatingTabBar.sideMargin,
            right: FloatingTabBar.sideMargin,
            bottom: FloatingTabBar.bottomGap(safeBottom),
            child: IgnorePointer(
              ignoring: !showBar,
              child: AnimatedSlide(
                offset: showBar ? Offset.zero : const Offset(0, 2),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedBuilder(
                  animation: _slide,
                  builder: (context, _) => FloatingTabBar(
                    tabs: _tabs,
                    // The highlight moves over once the swipe is halfway
                    currentIndex: _revealed != null && _slide.value.abs() > _width / 2 ? _revealed! : _index,
                    onTap: _select,
                    onSlide: _slideAlongBar,
                    onAdd: _add,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reports every change to a tab's navigation stack.
class _StackObserver extends NavigatorObserver {
  final VoidCallback onChange;

  _StackObserver(this.onChange);

  @override
  void didPush(Route route, Route? previousRoute) => onChange();

  @override
  void didPop(Route route, Route? previousRoute) => onChange();

  @override
  void didRemove(Route route, Route? previousRoute) => onChange();

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) => onChange();
}
