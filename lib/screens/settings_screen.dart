import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_style.dart';
import '../domain/entities/streak_warning_settings.dart';
import '../presentation/providers/habit_provider.dart';
import '../presentation/providers/settings_provider.dart';
import '../presentation/providers/theme_provider.dart';
import '../presentation/widgets/adaptive.dart';
import '../presentation/widgets/large_title_scaffold.dart';
import '../presentation/widgets/settings_list.dart';
import 'categories_screen.dart';
import 'notification_tester_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild when the appearance changes
    // iOS Settings style: grouped rows on the grouped background
    final background = isCupertino(context)
        ? CupertinoDynamicColor.resolve(CupertinoColors.systemGroupedBackground, context)
        : Theme.of(context).scaffoldBackgroundColor;
    return LargeTitleScaffold(
      title: 'Settings',
      backgroundColor: background,
      header: const LargeTitleHeader(title: 'Settings', titleKey: Key('settingsTitle')),
      slivers: [_buildSettingsList(context)],
    );
  }

  Widget _buildSettingsList(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final settings = context.watch<SettingsProvider>();
    final streakWarnings = settings.streakWarnings;

    Future<void> resync() async {
      if (context.mounted) await context.read<HabitProvider>().resyncStreakWarnings();
    }

    final automaticWeekStart = 'Automatic (${_dayNames[settings.regionalFirstDay - 1]})';

    return SliverList.list(
      children: [
        SettingsSection(
          header: 'Display',
          children: [
            SettingsTile(
              tileKey: const Key('appearanceSetting'),
              icon: CupertinoIcons.circle_lefthalf_fill,
              iconColor: CupertinoColors.systemIndigo,
              title: 'Appearance',
              value: _themeModeLabel(themeProvider.themeMode),
              onTap: () async {
                final mode = await chooseAdaptive<ThemeMode>(
                  context,
                  title: 'Appearance',
                  selected: themeProvider.themeMode,
                  options: [
                    for (final mode in [ThemeMode.system, ThemeMode.light, ThemeMode.dark])
                      AdaptiveOption(mode, _themeModeLabel(mode), key: Key('appearance_${mode.name}')),
                  ],
                );
                if (mode != null) await themeProvider.setThemeMode(mode);
              },
            ),
          ],
        ),
        SettingsSection(
          header: 'Habits',
          children: [
            SettingsTile(
              tileKey: const Key('openCategories'),
              icon: CupertinoIcons.square_grid_2x2_fill,
              iconColor: CupertinoColors.systemOrange,
              title: 'Categories',
              subtitle: 'Add, edit, reorder or restore categories',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CategoriesScreen()),
              ),
            ),
          ],
        ),
        SettingsSection(
          header: 'Calendar',
          children: [
            SettingsTile(
              tileKey: const Key('weekStartSetting'),
              icon: CupertinoIcons.calendar,
              iconColor: CupertinoColors.systemRed,
              title: 'Start week on',
              value:
                  settings.weekStartOverride == null ? automaticWeekStart : _dayNames[settings.weekStartOverride! - 1],
              onTap: () async {
                // 0 stands for Automatic (null can't mean both "cancelled" and "automatic")
                final day = await chooseAdaptive<int>(
                  context,
                  title: 'Start week on',
                  selected: settings.weekStartOverride ?? 0,
                  options: [
                    AdaptiveOption(0, automaticWeekStart, key: const Key('weekStart_auto')),
                    for (final day in const [DateTime.sunday, DateTime.monday, DateTime.saturday])
                      AdaptiveOption(day, _dayNames[day - 1], key: Key('weekStart_$day')),
                  ],
                );
                if (day != null) await settings.setWeekStart(day == 0 ? null : day);
              },
            ),
          ],
        ),
        SettingsSection(
          header: 'Streaks',
          footer: "By default you're warned only before a second miss would end a streak.",
          children: [
            SettingsSwitchTile(
              tileKey: const Key('streakWarningsSwitch'),
              icon: Icons.local_fire_department,
              iconColor: CupertinoColors.systemOrange,
              title: 'Streak warnings',
              subtitle: "A \"Don't miss twice\" notification before a streak would end",
              value: streakWarnings.enabled,
              onChanged: (value) async {
                await settings.setStreakWarningsEnabled(value);
                await resync();
              },
            ),
            SettingsTile(
              tileKey: const Key('streakWarningLeadTime'),
              icon: CupertinoIcons.clock_fill,
              iconColor: CupertinoColors.systemBlue,
              title: 'Warn me',
              value: _leadTimeLabel(streakWarnings.leadTime.inHours),
              enabled: streakWarnings.enabled,
              onTap: () async {
                final hours = await chooseAdaptive<int>(
                  context,
                  title: 'Warn me',
                  selected: streakWarnings.leadTime.inHours,
                  options: [
                    for (final hours in _leadTimeOptions(streakWarnings))
                      AdaptiveOption(hours, _leadTimeLabel(hours), key: Key('leadTime_$hours')),
                  ],
                );
                if (hours == null) return;
                await settings.setStreakWarningLeadTime(Duration(hours: hours));
                await resync();
              },
            ),
            SettingsSwitchTile(
              tileKey: const Key('streakWarningFirstMissSwitch'),
              icon: CupertinoIcons.bell_fill,
              iconColor: CupertinoColors.systemPurple,
              title: 'Also remind me before a first miss',
              value: streakWarnings.remindBeforeFirstMiss,
              onChanged: streakWarnings.enabled
                  ? (value) async {
                      await settings.setRemindBeforeFirstMiss(value);
                      await resync();
                    }
                  : null,
            ),
          ],
        ),
        // Debug builds only: never shown in release / App Store builds
        if (kDebugMode)
          SettingsSection(
            header: 'Developer',
            children: [
              SettingsTile(
                tileKey: const Key('addSampleHabits'),
                icon: CupertinoIcons.lab_flask_solid,
                iconColor: CupertinoColors.systemGrey,
                title: 'Add sample habits',
                subtitle: 'One per built-in category, with a few days of history',
                showChevron: false,
                onTap: () async {
                  final added = await context.read<HabitProvider>().addSampleHabits();
                  if (!context.mounted) return;
                  // Replace rather than queue behind a message from an earlier tap
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                      content: Text(added == 0
                          ? 'Sample habits are already added'
                          : 'Added $added sample ${added == 1 ? 'habit' : 'habits'}'),
                    ));
                },
              ),
              SettingsTile(
                tileKey: const Key('openNotificationTester'),
                icon: CupertinoIcons.bell_fill,
                iconColor: CupertinoColors.systemGrey,
                title: 'Notification tester',
                subtitle: 'Check permission, send and schedule test notifications',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationTesterScreen()),
                ),
              ),
            ],
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  // Keep a stored value selectable even if it is no longer one of the presets
  List<int> _leadTimeOptions(StreakWarningSettings current) {
    final options = {...StreakWarningSettings.leadTimeOptionsInHours, current.leadTime.inHours}.toList()..sort();
    return options;
  }

  static String _leadTimeLabel(int hours) =>
      hours == 24 ? '1 day before' : '$hours ${hours == 1 ? 'hour' : 'hours'} before';

  static const _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static String _themeModeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'System',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };
}
