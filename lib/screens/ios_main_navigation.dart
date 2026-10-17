import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/services/notification_service.dart';
import '../core/theme/app_palette.dart';
import '../presentation/providers/theme_provider.dart';
import 'home_screen.dart';
import 'calendar_screen.dart';
import 'settings_screen.dart';

class IOSMainNavigation extends StatefulWidget {
  const IOSMainNavigation({Key? key}) : super(key: key);

  @override
  State<IOSMainNavigation> createState() => _IOSMainNavigationState();
}

class _IOSMainNavigationState extends State<IOSMainNavigation> {
  final _tabs = CupertinoTabController();
  final _habitsNavigator = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    NotificationService.focusRequests.addListener(_showHabits);
    // A notification tap that launched the app arrives before this screen
    if (NotificationService.focusRequests.value != null) _showHabits();
  }

  @override
  void dispose() {
    NotificationService.focusRequests.removeListener(_showHabits);
    _tabs.dispose();
    super.dispose();
  }

  /// A notification was tapped: show the Habits list (the Habits screen
  /// then scrolls to the habit), closing anything open on top of it.
  void _showHabits() {
    if (NotificationService.focusRequests.value == null) return;
    _tabs.index = 0;
    _habitsNavigator.currentState?.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final palette = AppPalette.of(context);

        return CupertinoTabScaffold(
          controller: _tabs,
          backgroundColor: palette.background,
          tabBar: CupertinoTabBar(
            backgroundColor: palette.background,
            activeColor: palette.accent,
            inactiveColor: palette.textSecondary,
            border: Border(
              top: BorderSide(
                color: palette.separator,
                width: 0.5,
              ),
            ),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.checkmark_circle),
                activeIcon: Icon(CupertinoIcons.checkmark_circle_fill),
                label: 'Habits',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.calendar),
                activeIcon: Icon(CupertinoIcons.calendar),
                label: 'Calendar',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.settings),
                activeIcon: Icon(CupertinoIcons.settings_solid),
                label: 'Settings',
              ),
            ],
          ),
          tabBuilder: (context, index) {
            switch (index) {
              case 0:
                return CupertinoTabView(
                  navigatorKey: _habitsNavigator,
                  builder: (context) => const IOSHomeScreen(),
                );
              case 1:
                return CupertinoTabView(
                  builder: (context) => const IOSCalendarScreen(),
                );
              case 2:
                return CupertinoTabView(
                  builder: (context) => const IOSSettingsScreen(),
                );
              default:
                return CupertinoTabView(
                  builder: (context) => const IOSHomeScreen(),
                );
            }
          },
        );
      },
    );
  }
}

class IOSHomeScreen extends StatelessWidget {
  const IOSHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}

class IOSCalendarScreen extends StatelessWidget {
  const IOSCalendarScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const CalendarScreen();
  }
}

class IOSSettingsScreen extends StatelessWidget {
  const IOSSettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const SettingsScreen();
  }
}