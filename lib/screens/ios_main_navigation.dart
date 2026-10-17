import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/services/notification_service.dart';
import '../core/theme/app_palette.dart';
import '../presentation/providers/category_provider.dart';
import '../presentation/providers/habit_provider.dart';
import '../presentation/widgets/floating_tab_bar.dart';
import 'add_habit_screen.dart';
import 'home_screen.dart';
import 'calendar_screen.dart';
import 'insights_screen.dart';
import 'settings_screen.dart';

/// The app's main screen: four tabs, each with its own navigation stack,
/// under the floating tab bar with the "+" orb in the middle.
class IOSMainNavigation extends StatefulWidget {
  const IOSMainNavigation({Key? key}) : super(key: key);

  /// Opens New Habit over everything (the tab bar included), from anywhere.
  static Future<void> addHabit(BuildContext context) async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(fullscreenDialog: true, builder: (_) => const AddHabitScreen()),
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

class _IOSMainNavigationState extends State<IOSMainNavigation> {
  static const _tabs = [
    FloatingTab(label: 'Habits', icon: CupertinoIcons.checkmark_circle, activeIcon: CupertinoIcons.checkmark_circle_fill),
    FloatingTab(label: 'Calendar', icon: CupertinoIcons.calendar, activeIcon: CupertinoIcons.calendar),
    FloatingTab(label: 'Insights', icon: CupertinoIcons.chart_bar, activeIcon: CupertinoIcons.chart_bar_fill),
    FloatingTab(label: 'Settings', icon: CupertinoIcons.settings, activeIcon: CupertinoIcons.settings_solid),
  ];

  static const _screens = <Widget>[HomeScreen(), CalendarScreen(), InsightsScreen(), SettingsScreen()];

  final _navigators = [for (final _ in _tabs) GlobalKey<NavigatorState>()];
  late final _observers = [for (var i = 0; i < _tabs.length; i++) _StackObserver(() => _stackChanged(i))];

  int _index = 0;

  /// Tabs are built the first time they're shown, then kept.
  final _opened = <int>{0};

  /// Tabs with a page open on top of their first one: the bar hides there.
  final _deep = <int>{};

  @override
  void initState() {
    super.initState();
    NotificationService.focusRequests.addListener(_showHabits);
    // A notification tap that launched the app arrives before this screen
    if (NotificationService.focusRequests.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showHabits());
    }
  }

  @override
  void dispose() {
    NotificationService.focusRequests.removeListener(_showHabits);
    super.dispose();
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
    setState(() {
      _index = index;
      _opened.add(index);
    });
  }

  /// A notification was tapped: show the Habits list (the Habits screen
  /// then scrolls to the habit), closing anything open on top of it.
  void _showHabits() {
    if (NotificationService.focusRequests.value == null) return;
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

    return ColoredBox(
      color: palette.background,
      child: Stack(
        children: [
          Positioned.fill(
            child: TabBarInset(
              height: FloatingTabBar.coveredHeight(safeBottom),
              child: Stack(
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    Offstage(
                      offstage: i != _index,
                      child: TickerMode(
                        enabled: i == _index,
                        child: FocusScope(
                          canRequestFocus: i == _index,
                          child: _opened.contains(i)
                              ? CupertinoTabView(
                                  navigatorKey: _navigators[i],
                                  navigatorObservers: [_observers[i]],
                                  builder: (context) => _screens[i],
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                ],
              ),
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
                child: FloatingTabBar(
                  tabs: _tabs,
                  currentIndex: _index,
                  orbAfter: 2,
                  onTap: _select,
                  onAdd: () => IOSMainNavigation.addHabit(context),
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
