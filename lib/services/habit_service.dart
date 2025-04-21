import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/habit.dart';

class HabitService {
  // Singleton pattern
  static final HabitService _instance = HabitService._internal();
  
  factory HabitService() {
    return _instance;
  }
  
  HabitService._internal() {
    // Initialize by loading habits from storage
    loadHabits();
  }

  // Key for storing habits in SharedPreferences
  static const String _habitsKey = 'atomic_momentum_habits';

  // In-memory storage for habits
  List<Habit> _habits = [];

  // Default habits to use if no saved habits exist
  List<Habit> get _defaultHabits => [
    Habit(
      id: '1',
      name: 'Drink Water',
      progress: 5,
      target: 8,
      color: Colors.blue,
    ),
    Habit(
      id: '2',
      name: 'Read Bible',
      progress: 3,
      target: 7,
      color: Colors.teal,
    ),
    Habit(
      id: '3',
      name: 'Workout',
      progress: 7,
      target: 7,
      color: Colors.orange,
    ),
  ];

  // Get all habits
  List<Habit> getHabits() {
    return List.from(_habits);
  }

  // Load habits from SharedPreferences
  Future<void> loadHabits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final habitsJson = prefs.getStringList(_habitsKey);
      
      if (habitsJson != null && habitsJson.isNotEmpty) {
        // Convert JSON strings to Habit objects
        _habits = habitsJson.map((json) => Habit.fromJson(json)).toList();
      } else {
        // Use default habits if none are saved
        _habits = _defaultHabits;
        // Save default habits
        saveHabits();
      }
    } catch (e) {
      print('Error loading habits: $e');
      // Fallback to default habits if there's an error
      _habits = _defaultHabits;
    }
  }

  // Save habits to SharedPreferences
  Future<void> saveHabits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Convert Habit objects to JSON strings
      final habitsJson = _habits.map((habit) => habit.toJson()).toList();
      await prefs.setStringList(_habitsKey, habitsJson);
    } catch (e) {
      print('Error saving habits: $e');
    }
  }

  // Add a new habit
  Future<void> addHabit(Habit habit) async {
    _habits.add(habit);
    await saveHabits();
  }

  // Update the progress of a habit
  Future<void> updateHabitProgress(String id, int progress) async {
    final index = _habits.indexWhere((habit) => habit.id == id);
    if (index != -1) {
      final habit = _habits[index];
      _habits[index] = habit.copyWith(progress: progress);
      await saveHabits();
    }
  }

  // Delete a habit
  Future<void> deleteHabit(String id) async {
    _habits.removeWhere((habit) => habit.id == id);
    await saveHabits();
  }

  // Find a habit by ID
  Habit? getHabitById(String id) {
    try {
      return _habits.firstWhere((habit) => habit.id == id);
    } catch (e) {
      return null;
    }
  }

  // Reset the progress of all habits (for daily reset)
  Future<void> resetAllProgress() async {
    _habits = _habits.map((habit) => habit.copyWith(progress: 0)).toList();
    await saveHabits();
  }
}
