import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;
  final bool isDarkMode;

  const SettingsScreen({
    Key? key, 
    required this.onThemeChanged,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
  }

  Future<void> _toggleTheme(bool value) async {
    setState(() {
      _isDarkMode = value;
    });

    // Update theme in the app
    widget.onThemeChanged(value ? ThemeMode.dark : ThemeMode.light);

    // Save to shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Appearance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Switch between light and dark themes'),
            value: _isDarkMode,
            onChanged: _toggleTheme,
            secondary: Icon(
              _isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const Divider(),
          // You can add more settings sections below
        ],
      ),
    );
  }
}