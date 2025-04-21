import 'dart:convert';
import 'package:flutter/material.dart';

class Habit {
  final String id;
  final String name;
  final int target;
  final int progress;
  final Color color;

  Habit({
    required this.id,
    required this.name,
    required this.target,
    required this.progress,
    this.color = Colors.purple, // Default color
  });

  // Create a copy of this habit with modified properties
  Habit copyWith({
    String? id,
    String? name,
    int? target,
    int? progress,
    Color? color,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      target: target ?? this.target,
      progress: progress ?? this.progress,
      color: color ?? this.color,
    );
  }

  // Convert Habit to a Map for JSON serialization
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'target': target,
      'progress': progress,
      'color': color.value, // Store color as int value
    };
  }

  // Create a Habit from a Map from JSON
  factory Habit.fromMap(Map<String, dynamic> map) {
    return Habit(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      target: map['target'] ?? 0,
      progress: map['progress'] ?? 0,
      color: map['color'] != null ? Color(map['color']) : Colors.purple,
    );
  }

  // Convert Habit to JSON string
  String toJson() => json.encode(toMap());

  // Create a Habit from JSON string
  factory Habit.fromJson(String source) => Habit.fromMap(json.decode(source));

  // For debugging
  @override
  String toString() {
    return 'Habit(id: $id, name: $name, target: $target, progress: $progress, color: ${color.value})';
  }
}
