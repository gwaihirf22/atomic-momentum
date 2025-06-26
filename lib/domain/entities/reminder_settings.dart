import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';

class ReminderSettings extends Equatable {
  final TimeOfDay time;
  final bool enabled;
  final List<int> daysOfWeek; // 1-7, Monday-Sunday
  final String? customMessage;

  const ReminderSettings({
    required this.time,
    required this.enabled,
    required this.daysOfWeek,
    this.customMessage,
  });

  factory ReminderSettings.disabled() {
    return const ReminderSettings(
      time: TimeOfDay(hour: 9, minute: 0),
      enabled: false,
      daysOfWeek: [1, 2, 3, 4, 5, 6, 7], // All days
      customMessage: null,
    );
  }

  factory ReminderSettings.daily({
    required TimeOfDay time,
    String? customMessage,
  }) {
    return ReminderSettings(
      time: time,
      enabled: true,
      daysOfWeek: const [1, 2, 3, 4, 5, 6, 7], // All days
      customMessage: customMessage,
    );
  }

  factory ReminderSettings.weekdays({
    required TimeOfDay time,
    String? customMessage,
  }) {
    return ReminderSettings(
      time: time,
      enabled: true,
      daysOfWeek: const [1, 2, 3, 4, 5], // Monday-Friday
      customMessage: customMessage,
    );
  }

  bool shouldRemindToday(DateTime date) {
    if (!enabled) return false;
    
    final weekday = date.weekday; // 1-7, Monday-Sunday
    return daysOfWeek.contains(weekday);
  }

  String get timeString {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String get daysString {
    if (daysOfWeek.length == 7) return 'Daily';
    if (daysOfWeek.length == 5 && 
        daysOfWeek.every((day) => day >= 1 && day <= 5)) {
      return 'Weekdays';
    }
    
    const dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return daysOfWeek.map((day) => dayNames[day]).join(', ');
  }

  ReminderSettings copyWith({
    TimeOfDay? time,
    bool? enabled,
    List<int>? daysOfWeek,
    String? customMessage,
  }) {
    return ReminderSettings(
      time: time ?? this.time,
      enabled: enabled ?? this.enabled,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      customMessage: customMessage ?? this.customMessage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'time': timeString,
      'enabled': enabled,
      'daysOfWeek': daysOfWeek,
      'customMessage': customMessage,
    };
  }

  factory ReminderSettings.fromJson(Map<String, dynamic> json) {
    final timeString = json['time'] as String;
    final timeParts = timeString.split(':');
    final time = TimeOfDay(
      hour: int.parse(timeParts[0]),
      minute: int.parse(timeParts[1]),
    );

    return ReminderSettings(
      time: time,
      enabled: json['enabled'] as bool,
      daysOfWeek: (json['daysOfWeek'] as List<dynamic>).cast<int>(),
      customMessage: json['customMessage'] as String?,
    );
  }

  @override
  List<Object?> get props => [time, enabled, daysOfWeek, customMessage];

  @override
  String toString() => 'ReminderSettings(time: $timeString, enabled: $enabled)';
}