import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_style.dart';
import '../presentation/widgets/adaptive.dart';
import '../domain/entities/streak_warning_settings.dart';
import '../presentation/providers/habit_provider.dart';
import '../presentation/providers/settings_provider.dart';
import '../presentation/providers/theme_provider.dart';
import 'categories_screen.dart';
import 'notification_tester_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: _buildSettingsList(context),
    );
  }
  
  Widget _buildSettingsList(BuildContext context) {
    // Get the theme provider
    final themeProvider = Provider.of<ThemeProvider>(context);
    final settings = context.watch<SettingsProvider>();
    final streakWarnings = settings.streakWarnings;
    
    return ListView(
      children: [
        _sectionHeader('Display'),
        ListTile(
          key: const Key('appearanceSetting'),
          leading: Icon(Icons.brightness_6_outlined, color: Theme.of(context).primaryColor),
          title: const Text('Appearance'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_themeModeLabel(themeProvider.themeMode), style: TextStyle(color: secondaryLabel(context))),
              const Icon(Icons.chevron_right),
            ],
          ),
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
        const Divider(),
        _sectionHeader('Habits'),
        ListTile(
          key: const Key('openCategories'),
          leading: Icon(Icons.category_outlined, color: Theme.of(context).primaryColor),
          title: const Text('Categories'),
          subtitle: const Text('Add, edit, reorder or restore categories'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CategoriesScreen()),
          ),
        ),
        const Divider(),
        _sectionHeader('Calendar'),
        ListTile(
          leading: Icon(Icons.date_range, color: Theme.of(context).primaryColor),
          title: const Text('Start week on'),
          trailing: DropdownButton<int?>(
            key: const Key('weekStartDropdown'),
            value: settings.weekStartOverride,
            onChanged: (day) => settings.setWeekStart(day),
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Text('Automatic (${_dayNames[settings.regionalFirstDay - 1]})'),
              ),
              for (final day in const [DateTime.sunday, DateTime.monday, DateTime.saturday])
                DropdownMenuItem<int?>(value: day, child: Text(_dayNames[day - 1])),
            ],
          ),
        ),
        const Divider(),
        _sectionHeader('Streaks'),
        SwitchListTile(
          key: const Key('streakWarningsSwitch'),
          title: const Text('Streak warnings'),
          subtitle: const Text("Get a \"Don't miss twice\" notification before a streak would end"),
          value: streakWarnings.enabled,
          onChanged: (value) async {
            await settings.setStreakWarningsEnabled(value);
            if (context.mounted) {
              await context.read<HabitProvider>().resyncStreakWarnings();
            }
          },
          secondary: Icon(
            Icons.local_fire_department,
            color: Theme.of(context).primaryColor,
          ),
        ),
        ListTile(
          enabled: streakWarnings.enabled,
          leading: const Icon(Icons.schedule),
          title: const Text('Warn me'),
          trailing: DropdownButton<int>(
            key: const Key('streakWarningLeadTime'),
            value: streakWarnings.leadTime.inHours,
            onChanged: streakWarnings.enabled
                ? (hours) async {
                    if (hours == null) return;
                    await settings.setStreakWarningLeadTime(Duration(hours: hours));
                    if (context.mounted) {
                      await context.read<HabitProvider>().resyncStreakWarnings();
                    }
                  }
                : null,
            items: [
              for (final hours in _leadTimeOptions(streakWarnings))
                DropdownMenuItem(
                  value: hours,
                  child: Text(hours == 24 ? '1 day before' : '$hours ${hours == 1 ? 'hour' : 'hours'} before'),
                ),
            ],
          ),
        ),
        SwitchListTile(
          key: const Key('streakWarningFirstMissSwitch'),
          title: const Text('Also remind me before a first miss'),
          subtitle: const Text(
              "By default you're warned only before a second miss would end a streak"),
          value: streakWarnings.remindBeforeFirstMiss,
          onChanged: streakWarnings.enabled
              ? (value) async {
                  await settings.setRemindBeforeFirstMiss(value);
                  if (context.mounted) {
                    await context.read<HabitProvider>().resyncStreakWarnings();
                  }
                }
              : null,
          secondary: const Icon(Icons.notifications_active_outlined),
        ),
        const Divider(),
        // Debug builds only: never shown in release / App Store builds
        if (kDebugMode) ...[
          _sectionHeader('Developer'),
          ListTile(
            key: const Key('addSampleHabits'),
            leading: const Icon(Icons.science_outlined),
            title: const Text('Add sample habits'),
            subtitle: const Text('One per built-in category, with a few days of history'),
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
          ListTile(
            key: const Key('openNotificationTester'),
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notification tester'),
            subtitle: const Text('Check permission, send and schedule test notifications'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationTesterScreen()),
            ),
          ),
          const Divider(),
        ],
      ],
    );
  }

  // Keep a stored value selectable even if it is no longer one of the presets
  List<int> _leadTimeOptions(StreakWarningSettings current) {
    final options = {...StreakWarningSettings.leadTimeOptionsInHours, current.leadTime.inHours}.toList()
      ..sort();
    return options;
  }

  static const _dayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static String _themeModeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'System',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };
}
