import 'package:flutter/material.dart';
import '../models/habit.dart';

class HabitService {
  // Singleton pattern
  static final HabitService _instance = HabitService._internal();
  
  factory HabitService() {
    return _instance;
  }
  
  HabitService._internal();

  // In-memory storage for habits
  List<Habit> _habits = [
    // Initial example data
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

  // Add a new habit
  void addHabit(Habit habit) {
    _habits.add(habit);
  }

  // Update the progress of a habit
  void updateHabitProgress(String id, int progress) {
    final index = _habits.indexWhere((habit) => habit.id == id);
    if (index != -1) {
      final habit = _habits[index];
      _habits[index] = habit.copyWith(progress: progress);
    }
  }

  // Delete a habit
  void deleteHabit(String id) {
    _habits.removeWhere((habit) => habit.id == id);
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
  void resetAllProgress() {
    _habits = _habits.map((habit) => habit.copyWith(progress: 0)).toList();
  }
}
