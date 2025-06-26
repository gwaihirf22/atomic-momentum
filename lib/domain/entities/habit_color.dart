import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';

class HabitColor extends Equatable {
  final int value;
  final String hex;
  final String name;

  const HabitColor({
    required this.value,
    required this.hex,
    required this.name,
  });

  Color get color => Color(value);

  // Predefined colors for consistency
  static const blue = HabitColor(value: 0xFF2196F3, hex: "#2196F3", name: "Blue");
  static const green = HabitColor(value: 0xFF4CAF50, hex: "#4CAF50", name: "Green");
  static const orange = HabitColor(value: 0xFFFF9800, hex: "#FF9800", name: "Orange");
  static const purple = HabitColor(value: 0xFF9C27B0, hex: "#9C27B0", name: "Purple");
  static const teal = HabitColor(value: 0xFF009688, hex: "#009688", name: "Teal");
  static const red = HabitColor(value: 0xFFF44336, hex: "#F44336", name: "Red");
  static const indigo = HabitColor(value: 0xFF3F51B5, hex: "#3F51B5", name: "Indigo");
  static const pink = HabitColor(value: 0xFFE91E63, hex: "#E91E63", name: "Pink");

  static const List<HabitColor> predefinedColors = [
    blue,
    green,
    orange,
    purple,
    teal,
    red,
    indigo,
    pink,
  ];

  factory HabitColor.fromColor(Color color) {
    final hex = '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
    return HabitColor(
      value: color.value,
      hex: hex,
      name: _getColorName(color.value),
    );
  }

  factory HabitColor.fromHex(String hex) {
    String cleanHex = hex.replaceAll('#', '');
    if (cleanHex.length == 6) {
      cleanHex = 'FF$cleanHex'; // Add alpha channel
    }
    final value = int.parse(cleanHex, radix: 16);
    
    return HabitColor(
      value: value,
      hex: hex.startsWith('#') ? hex : '#$hex',
      name: _getColorName(value),
    );
  }

  static String _getColorName(int colorValue) {
    for (final predefined in predefinedColors) {
      if (predefined.value == colorValue) {
        return predefined.name;
      }
    }
    return 'Custom';
  }

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'hex': hex,
      'name': name,
    };
  }

  factory HabitColor.fromJson(Map<String, dynamic> json) {
    return HabitColor(
      value: json['value'] as int,
      hex: json['hex'] as String,
      name: json['name'] as String,
    );
  }

  @override
  List<Object?> get props => [value, hex, name];

  @override
  String toString() => 'HabitColor(name: $name, hex: $hex)';
}