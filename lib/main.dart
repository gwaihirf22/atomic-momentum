import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load theme preference
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;
  
  runApp(MomentumApp(initialDarkMode: isDarkMode));
}

class MomentumApp extends StatefulWidget {
  final bool initialDarkMode;
  
  const MomentumApp({Key? key, required this.initialDarkMode}) : super(key: key);

  @override
  _MomentumAppState createState() => _MomentumAppState();
}

class _MomentumAppState extends State<MomentumApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }
  
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Atomic Momentum',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        primaryColor: Colors.deepPurple,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        canvasColor: Colors.grey[850],
      ),
      themeMode: _themeMode,
      home: HomeScreen(
        onThemeChanged: _setThemeMode,
        isDarkMode: isDarkMode,
      ),
    );
  }
}
