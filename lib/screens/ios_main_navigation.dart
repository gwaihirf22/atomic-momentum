import 'dart:async';
import 'dart:math' as math;
import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/feedback/haptics.dart';
import '../core/injection/injection_container.dart';
import '../core/services/achievement_celebrations.dart';
import '../core/services/achievement_store.dart';
import '../core/services/freeze_bank.dart';
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
import 'inspire_screen.dart';
import 'settings_screen.dart';

/// The main tabs, in the bar's order. Inspire can be turned off in Settings.
enum AppTab {
  habits(
    FloatingTab(
      label: 'Habits',
      icon: CupertinoIcons.checkmark_circle,
      activeIcon: CupertinoIcons.checkmark_circle_fill,
      addLabel: 'Add habit',
    ),
    HomeScreen(),
  ),
  calendar(FloatingTab(label: 'Calendar', icon: CupertinoIcons.calendar, activeIcon: CupertinoIcons.calendar), CalendarScreen()),
  insights(
    FloatingTab(label: 'Insights', icon: CupertinoIcons.chart_bar, activeIcon: CupertinoIcons.chart_bar_fill),
    InsightsScreen(),
  ),
  inspire(
    FloatingTab(label: 'Inspire', icon: CupertinoIcons.quote_bubble, activeIcon: CupertinoIcons.quote_bubble_fill),
    InspireScreen(),
  ),
  settings(
    FloatingTab(label: 'Settings', icon: CupertinoIcons.settings, activeIcon: CupertinoIcons.settings_solid),
    SettingsScreen(),
  );

  final FloatingTab bar;
  final Widget screen;

  const AppTab(this.bar, this.screen);
}

/// The app's main screen: the tabs (four or five, see [AppTab]), each with
/// its own navigation stack, under the floating tab bar, whose Habits tab
/// turns into "+" for adding. A sideways swipe on a tab's first page slides
/// to the next or previous tab, and sliding a finger along the bar picks
/// the tab under it. On Inspire the bar fades away after [barFadeDelay]
/// untouched, and any touch brings it back.
class IOSMainNavigation extends StatefulWidget {
  /// Showing a tour's example habits: no celebrations, and taps on
  /// notifications or widgets are left for the person's own app.
  final bool demo;

  /// The tab it opens on.
  final AppTab initialTab;

  /// Lets a tour switch tabs and open pages.
  final MainNavigationController? controller;

  const IOSMainNavigation({Key? key, this.demo = false, this.initialTab = AppTab.habits, this.controller})
      : super(key: key);

  /// How long Inspire sits untouched before the bar fades.
  static const barFadeDelay = Duration(seconds: 3);

  /// A tab to show, asked for from outside the tree (a home screen widget's
  /// tap); cleared once shown.
  static final tabRequests = ValueNotifier<AppTab?>(null);

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
  final _navigators = {for (final tab in AppTab.values) tab: GlobalKey<NavigatorState>()};
  late final _observers = {for (final tab in AppTab.values) tab: _StackObserver(() => _stackChanged(tab))};

  late AppTab _current = widget.initialTab;

  /// The tabs in the bar now, in order (Inspire only while it's turned on).
  List<AppTab> _visible = AppTab.values;

  /// When the current tab was chosen: Habits' "+" ignores a tap right after
  /// arriving, so a quick double-tap from another tab doesn't open Add.
  DateTime? _selectedAt;
  static const _addGuard = Duration(milliseconds: 400);

  /// How far the current tab is slid sideways by a swipe, in points
  /// (negative: towards the next tab), with the tab it reveals.
  late final _slide = AnimationController.unbounded(vsync: this);
  AppTab? _revealed;
  double _width = 0;

  /// Tabs are built the first time they're shown, then kept.
  late final _opened = <AppTab>{widget.initialTab};

  /// Tabs with a page open on top of their first one: the bar hides there.
  final _deep = <AppTab>{};

  /// Inspire's bar has faded (see [IOSMainNavigation.barFadeDelay]).
  bool _barFaded = false;
  Timer? _fadeTimer;

  /// VoiceOver or Switch Control is on: the bar never fades.
  bool _accessible = false;

  late final HabitProvider _habits;

  /// An achievement's sheet is open.
  bool _celebrating = false;

  @override
  void initState() {
    super.initState();
    _habits = context.read<HabitProvider>();
    widget.controller?._attach(this);
    // Example habits are quiet: nothing to celebrate, and requests from
    // notifications and widgets wait for the person's own app
    if (widget.demo) return;
    _habits.addListener(_checkAchievementsSoon);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAchievements());
    NotificationService.focusRequests.addListener(_showHabits);
    IOSMainNavigation.tabRequests.addListener(_showRequestedTab);
    // A notification or widget tap that launched the app arrives before this screen
    if (NotificationService.focusRequests.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showHabits());
    }
    if (IOSMainNavigation.tabRequests.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showRequestedTab());
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _habits.removeListener(_checkAchievementsSoon);
    NotificationService.focusRequests.removeListener(_showHabits);
    IOSMainNavigation.tabRequests.removeListener(_showRequestedTab);
    _fadeTimer?.cancel();
    _slide.dispose();
    super.dispose();
  }

  bool _checkPending = false;

  /// Checks after the frame that shows the change (a tap draws first), once
  /// however many times habits notified before it.
  void _checkAchievementsSoon() {
    if (_checkPending) return;
    _checkPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPending = false;
      _checkAchievements();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// Celebrates an achievement just earned (today or yesterday), once. Ones
  /// found in older history, or there before the first check, are filed on
  /// the shelf quietly. Waits while Add, Edit or a sheet is open.
  void _checkAchievements() {
    if (_celebrating || !mounted || _habits.state != HabitProviderState.loaded) return;
    final store = get<AchievementStore>();
    final now = clock.now();
    final weekStart = context.read<SettingsProvider>().firstDayOfWeek;
    final started = store.started;
    // Streak milestones and habits formed fill the freeze bank (once each)
    final bank = sl.isRegistered<FreezeBank>() ? get<FreezeBank>() : null;
    bank?.check(now);
    final earned = Achievements.earned(_habits.habits, now, weekStart: weekStart);
    final credit = bank?.credit([for (final a in earned) if (Achievements.earnsFreeze(a)) a.id], now);
    final decision = AchievementCelebrations.decide(
      earned: earned,
      started: started,
      seen: store.seen,
      now: now,
      busy: Navigator.of(context, rootNavigator: true).canPop(),
    );
    if (decision.wait) return;
    // The first check starts the store even with nothing earned yet
    if (decision.markSeen.isNotEmpty || !started) store.markSeen(decision.markSeen);
    final achievement = decision.celebrate;
    if (achievement == null) return;

    final next = Achievements.next(_habits.habits, now)
        .where((p) => p.habitName != null && p.habitName == achievement.habitName)
        .firstOrNull;
    _celebrating = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final credited = await credit;
      final FreezeEarned? freeze = credited == null
          ? null
          : credited.added.contains(achievement.id)
              ? (added: true, available: bank!.available)
              : credited.full.contains(achievement.id)
                  ? (added: false, available: bank!.available)
                  : null;
      if (mounted) await showAchievementSheet(context, achievement, isNew: true, next: next, freeze: freeze);
      _celebrating = false;
    });
  }

  void _stackChanged(AppTab tab) {
    // Navigators report changes while they build; update after the frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final deep = _navigators[tab]!.currentState?.canPop() ?? false;
      if (deep == _deep.contains(tab)) return;
      setState(() => deep ? _deep.add(tab) : _deep.remove(tab));
      if (tab == _current) _wakeBar();
    });
  }

  /// A tap on the bar's tab at [position].
  void _select(int position) {
    final tab = _visible[position];
    if (tab == _current) {
      // Tapping the current tab goes back to its first page, as in iOS
      _navigators[tab]!.currentState?.popUntil((route) => route.isFirst);
      return;
    }
    _switchTo(tab);
  }

  /// Shows [tab] (from a tap, a swipe or sliding along the bar).
  void _switchTo(AppTab tab) {
    _endSlide();
    if (tab == _current) return;
    setState(() {
      _current = tab;
      _opened.add(tab);
      _selectedAt = clock.now();
    });
    widget.controller?.current.value = tab;
    _wakeBar();
  }

  void _slideAlongBar(int position) {
    final tab = _visible[position];
    if (tab == _current) return;
    Haptics.selection();
    _switchTo(tab);
  }

  /// Whether the bar fades on the tab showing now: Inspire's first page.
  bool get _fades => _current == AppTab.inspire && !_deep.contains(AppTab.inspire) && !_accessible;

  /// Shows the bar again (if it had faded) and starts the wait before it
  /// fades, where it does.
  void _wakeBar() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    if (_barFaded) setState(() => _barFaded = false);
    if (!_fades) return;
    _fadeTimer = Timer(IOSMainNavigation.barFadeDelay, () {
      if (mounted && _fades) setState(() => _barFaded = true);
    });
  }

  void _endSlide() {
    _slide.stop();
    _slide.value = 0;
    _revealed = null;
  }

  void _swipeStart(DragStartDetails _) => _slide.stop();

  void _swipeUpdate(DragUpdateDetails details) {
    final offset = _slide.value + details.delta.dx;
    final position = _visible.indexOf(_current);
    final nextPosition = offset < 0 ? position + 1 : position - 1;
    if (nextPosition < 0 || nextPosition >= _visible.length) {
      // Past the first or last tab: it gives a little, then stops
      _revealed = null;
      _slide.value = (offset.sign * math.min(offset.abs(), 60.0));
      return;
    }
    final next = _visible[nextPosition];
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
    if (_current != AppTab.habits) setState(() => _current = AppTab.habits);
    widget.controller?.current.value = AppTab.habits;
    _wakeBar();
    // Add and Edit open above the tabs; pages and sheets open inside them
    if (mounted) Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
    _navigators[AppTab.habits]!.currentState?.popUntil((route) => route.isFirst);
  }

  /// A home screen widget asked for a tab (Inspire for the quote widget):
  /// shows its first page, if the tab is on.
  void _showRequestedTab() {
    final tab = IOSMainNavigation.tabRequests.value;
    if (tab == null || !mounted) return;
    IOSMainNavigation.tabRequests.value = null;
    if (!_visible.contains(tab)) return;
    _endSlide();
    Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
    _navigators[tab]!.currentState?.popUntil((route) => route.isFirst);
    _switchTo(tab);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final showInspire = context.watch<SettingsProvider>().showInspireTab;
    _visible = [
      for (final tab in AppTab.values)
        if (tab != AppTab.inspire || showInspire) tab,
    ];
    // Inspire was turned off while showing (Settings is where it's turned
    // off, so this is only a safeguard)
    if (!_visible.contains(_current)) _current = AppTab.settings;
    if (_revealed != null && !_visible.contains(_revealed)) _endSlide();
    _accessible = MediaQuery.accessibleNavigationOf(context);
    final showBar = !_deep.contains(_current);
    final faded = _barFaded && _fades;
    final position = _visible.indexOf(_current);

    Widget tabView(AppTab tab) => _opened.contains(tab)
        ? CupertinoTabView(
            navigatorKey: _navigators[tab],
            navigatorObservers: [_observers[tab]!],
            builder: (context) => tab.screen,
          )
        : const SizedBox.shrink();

    return ColoredBox(
      color: palette.background,
      child: Stack(
        children: [
          Positioned.fill(
            // Any touch brings a faded bar back
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _wakeBar(),
              child: TabBarInset(
              height: FloatingTabBar.coveredHeight(safeBottom),
              child: TabBarFade(
              faded: faded,
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
                          for (final tab in AppTab.values)
                            Offstage(
                              offstage: tab != _current && tab != revealed,
                              child: Transform.translate(
                                offset: Offset(
                                  tab == _current
                                      ? offset
                                      : (tab == revealed
                                          ? offset + (_visible.indexOf(tab) > position ? _width : -_width)
                                          : 0),
                                  0,
                                ),
                                child: IgnorePointer(
                                  ignoring: tab != _current,
                                  child: TickerMode(
                                    enabled: tab == _current,
                                    child: FocusScope(canRequestFocus: tab == _current, child: tabView(tab)),
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
            ),
          ),
          Positioned(
            left: FloatingTabBar.sideMargin,
            right: FloatingTabBar.sideMargin,
            bottom: FloatingTabBar.bottomGap(safeBottom),
            child: IgnorePointer(
              ignoring: !showBar || faded,
              child: AnimatedOpacity(
                key: const Key('tabBarFade'),
                opacity: faded ? 0 : 1,
                duration: Duration(milliseconds: faded ? 600 : 200),
                curve: Curves.easeOut,
                child: AnimatedSlide(
                  offset: showBar ? Offset.zero : const Offset(0, 2),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: AnimatedBuilder(
                    animation: _slide,
                    builder: (context, _) => FloatingTabBar(
                      tabs: [for (final tab in _visible) tab.bar],
                      // The highlight moves over once the swipe is halfway
                      currentIndex: _visible.indexOf(
                        _revealed != null && _slide.value.abs() > _width / 2 ? _revealed! : _current,
                      ),
                      onTap: _select,
                      onSlide: _slideAlongBar,
                      onAdd: _add,
                    ),
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

/// Lets a tour drive the tabs from outside: show a tab, reach a tab's own
/// navigator to open a page, close everything open. [current] follows the
/// tab showing.
class MainNavigationController {
  _IOSMainNavigationState? _state;

  final current = ValueNotifier<AppTab>(AppTab.habits);

  bool get isAttached => _state != null;

  void _attach(_IOSMainNavigationState state) {
    _state = state;
    current.value = state._current;
  }

  void _detach(_IOSMainNavigationState state) {
    if (_state == state) _state = null;
  }

  /// Shows [tab] (if it's in the bar), as a tap on it would.
  void show(AppTab tab) {
    final state = _state;
    if (state == null || !state.mounted || !state._visible.contains(tab)) return;
    state._switchTo(tab);
  }

  /// [tab]'s own navigator, for opening a page in it.
  NavigatorState? navigatorOf(AppTab tab) => _state?._navigators[tab]!.currentState;

  /// Closes everything open: sheets and Add/Edit on top, and every tab's
  /// pages back to its first.
  void popAllToRoot() {
    final state = _state;
    if (state == null || !state.mounted) return;
    Navigator.of(state.context, rootNavigator: true).popUntil((route) => route.isFirst);
    for (final key in state._navigators.values) {
      key.currentState?.popUntil((route) => route.isFirst);
    }
  }
}
