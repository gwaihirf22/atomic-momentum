import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/ios_colors.dart';
import '../core/theme/ios_typography.dart';
import '../presentation/providers/theme_provider.dart';
import 'home_screen.dart';
import 'calendar_screen.dart';
import 'settings_screen.dart';

class IOSMainNavigation extends StatelessWidget {
  const IOSMainNavigation({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.themeMode == ThemeMode.dark ||
            (themeProvider.themeMode == ThemeMode.system &&
                MediaQuery.platformBrightnessOf(context) == Brightness.dark);
        
        return CupertinoTabScaffold(
          backgroundColor: isDark ? IOSColors.systemBackgroundDark : IOSColors.systemBackground,
          tabBar: CupertinoTabBar(
            backgroundColor: isDark ? IOSColors.systemBackgroundDark : IOSColors.systemBackground,
            activeColor: IOSColors.systemBlue,
            inactiveColor: isDark ? IOSColors.secondaryLabel : IOSColors.secondaryLabel,
            border: Border(
              top: BorderSide(
                color: isDark ? IOSColors.separatorDark : IOSColors.separator,
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
                activeIcon: Icon(CupertinoIcons.calendar_today),
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