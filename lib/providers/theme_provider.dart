import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode;
  
  // Constructor sets the initial theme mode
  ThemeProvider(bool isDarkMode) 
    : _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
  
  // Getter for the current theme mode
  ThemeMode get themeMode => _themeMode;
  
  // Getter for checking if dark mode is active
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  // Method to toggle between light and dark mode
  Future<void> toggleTheme() async {
    // Toggle the theme mode
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    
    // Save the preference to shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
    
    // Notify listeners about the change
    notifyListeners();
  }
  
  // Method to set a specific theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    
    _themeMode = mode;
    
    // Save the preference to shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
    
    // Notify listeners about the change
    notifyListeners();
  }
}