import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/entities/streak_warning_settings.dart';
import '../presentation/providers/habit_provider.dart';
import '../presentation/providers/settings_provider.dart';
import '../presentation/providers/theme_provider.dart';

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
        _sectionHeader('Appearance'),
        SwitchListTile(
          title: const Text('Dark Mode'),
          subtitle: const Text('Switch between light and dark themes'),
          value: themeProvider.isDarkMode,
          onChanged: (value) {
            // Use the provider to toggle the theme
            themeProvider.toggleTheme();
          },
          secondary: Icon(
            themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const Divider(),
        _sectionHeader('Streaks'),
        SwitchListTile(
          key: const Key('streakWarningsSwitch'),
          title: const Text('Streak warnings'),
          subtitle: const Text('Get a notification before a streak expires'),
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
        const Divider(),
      ],
    );
  }

  // Keep a stored value selectable even if it is no longer one of the presets
  List<int> _leadTimeOptions(StreakWarningSettings current) {
    final options = {...StreakWarningSettings.leadTimeOptionsInHours, current.leadTime.inHours}.toList()
      ..sort();
    return options;
  }

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
}
