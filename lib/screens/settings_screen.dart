import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_palette.dart';
import '../domain/entities/habit_color.dart';
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
    return LargeTitleScaffold(
      title: 'Settings',
      backgroundColor: AppPalette.of(context).background,
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
          footer: 'Habits greetings follow your day. Working nights? Set when you wake up.',
          children: [
            SettingsTile(
              tileKey: const Key('appearanceSetting'),
              icon: CupertinoIcons.circle_lefthalf_fill,
              iconColor: HabitColor.indigo.color,
              title: 'Appearance',
              value: _appearanceLabel(themeProvider.appearance),
              onTap: () async {
                final appearance = await chooseAdaptive<Appearance>(
                  context,
                  title: 'Appearance',
                  selected: themeProvider.appearance,
                  options: [
                    for (final appearance in Appearance.values)
                      AdaptiveOption(appearance, _appearanceLabel(appearance), key: Key('appearance_${appearance.name}')),
                  ],
                );
                if (appearance != null) await themeProvider.setAppearance(appearance);
              },
            ),
            // System is dark at night; this picks its daytime look
            if (themeProvider.appearance == Appearance.system)
              SettingsTile(
                tileKey: const Key('dayThemeSetting'),
                icon: CupertinoIcons.sun_max_fill,
                iconColor: HabitColor.amber.color,
                title: 'In light mode',
                value: _themeLabel(themeProvider.dayTheme),
                onTap: () async {
                  final theme = await chooseAdaptive<AppTheme>(
                    context,
                    title: 'In light mode',
                    selected: themeProvider.dayTheme,
                    options: [
                      for (final theme in ThemeProvider.dayThemes)
                        AdaptiveOption(theme, _themeLabel(theme), key: Key('dayTheme_${theme.name}')),
                    ],
                  );
                  if (theme != null) await themeProvider.setDayTheme(theme);
                },
              ),
            SettingsTile(
              tileKey: const Key('dayStartSetting'),
              icon: CupertinoIcons.sunrise_fill,
              iconColor: HabitColor.orange.color,
              title: 'My day starts at',
              value: settings.dayStart.format(context),
              onTap: () async {
                final time = await pickTimeAdaptive(context, initial: settings.dayStart);
                if (time != null) await settings.setDayStart(time);
              },
            ),
          ],
        ),
        SettingsSection(
          header: 'Habits',
          footer: 'Adding and editing open in this style. Switch any time at the top of the page.',
          children: [
            SettingsTile(
              tileKey: const Key('addHabitStyleSetting'),
              icon: CupertinoIcons.wand_stars,
              iconColor: HabitColor.deepOrange.color,
              title: 'Habit editor',
              value: _styleLabel(settings.addHabitStyle),
              onTap: () async {
                final style = await chooseAdaptive<AddHabitStyle>(
                  context,
                  title: 'Open the habit editor in',
                  selected: settings.addHabitStyle,
                  options: [
                    for (final style in AddHabitStyle.values)
                      AdaptiveOption(
                        style,
                        _styleLabel(style),
                        subtitle: _styleDescription(style),
                        key: Key('addHabitStyle_${style.name}'),
                      ),
                  ],
                );
                if (style != null) await settings.setAddHabitStyle(style);
              },
            ),
            SettingsTile(
              tileKey: const Key('openCategories'),
              icon: CupertinoIcons.square_grid_2x2_fill,
              iconColor: HabitColor.orange.color,
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
              iconColor: HabitColor.red.color,
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
          header: 'Reminders',
          footer: 'New habits remind you at this time. Change it for any habit when you edit it.',
          children: [
            SettingsTile(
              tileKey: const Key('defaultReminderTime'),
              icon: CupertinoIcons.alarm_fill,
              iconColor: HabitColor.green.color,
              title: 'Default time',
              value: settings.defaultReminderTime.format(context),
              onTap: () async {
                final time = await pickTimeAdaptive(context, initial: settings.defaultReminderTime);
                if (time != null) await settings.setDefaultReminderTime(time);
              },
            ),
          ],
        ),
        SettingsSection(
          header: 'Streaks',
          children: [
            SettingsSwitchTile(
              tileKey: const Key('streakWarningsSwitch'),
              icon: Icons.local_fire_department,
              iconColor: HabitColor.orange.color,
              title: 'Streak warnings',
              subtitle: 'Before a second miss would end it',
              value: streakWarnings.enabled,
              onChanged: (value) async {
                await settings.setStreakWarningsEnabled(value);
                await resync();
              },
            ),
            SettingsTile(
              tileKey: const Key('streakWarningLeadTime'),
              icon: CupertinoIcons.clock_fill,
              iconColor: HabitColor.blue.color,
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
              iconColor: HabitColor.purple.color,
              title: 'Early nudge',
              subtitle: 'Remind before a first miss, too',
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
                iconColor: HabitColor.blueGrey.color,
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
                iconColor: HabitColor.blueGrey.color,
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

  static String _appearanceLabel(Appearance appearance) => switch (appearance) {
        Appearance.system => 'System',
        Appearance.light => 'Light',
        Appearance.sepia => 'Sepia',
        Appearance.dark => 'Dark',
      };

  static String _styleLabel(AddHabitStyle style) => switch (style) {
        AddHabitStyle.builder => 'Builder',
        AddHabitStyle.story => 'Story',
      };

  static String _styleDescription(AddHabitStyle style) => switch (style) {
        AddHabitStyle.builder => 'Three quick steps',
        AddHabitStyle.story => 'Write it as one sentence',
      };

  static String _themeLabel(AppTheme theme) => switch (theme) {
        AppTheme.light => 'Light',
        AppTheme.sepia => 'Sepia',
        AppTheme.dark => 'Dark',
      };
}
