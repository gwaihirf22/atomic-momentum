import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';

/// Which days a reminder fires on.
enum ReminderMode {
  /// Worked out from the habit's schedule, counting down to when it's due
  /// (see ReminderPlanner), and skipped once it's done.
  smart,

  /// On the chosen [ReminderSettings.daysOfWeek].
  custom,
}

class ReminderSettings extends Equatable {
  final TimeOfDay time;
  final bool enabled;
  final List<int> daysOfWeek; // 1-7, Monday-Sunday; used in custom mode
  final String? customMessage;
  final ReminderMode mode;

  const ReminderSettings({
    required this.time,
    required this.enabled,
    required this.daysOfWeek,
    this.customMessage,
    this.mode = ReminderMode.custom,
  });

  /// The default for new habits: on, at [time], on smart days.
  factory ReminderSettings.smart({required TimeOfDay time, String? customMessage}) {
    return ReminderSettings(
      time: time,
      enabled: true,
      daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
      customMessage: customMessage,
      mode: ReminderMode.smart,
    );
  }

  bool get isSmart => mode == ReminderMode.smart;

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

  String get timeString {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  ReminderSettings copyWith({
    TimeOfDay? time,
    bool? enabled,
    List<int>? daysOfWeek,
    String? customMessage,
    ReminderMode? mode,
  }) {
    return ReminderSettings(
      time: time ?? this.time,
      enabled: enabled ?? this.enabled,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      customMessage: customMessage ?? this.customMessage,
      mode: mode ?? this.mode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'time': timeString,
      'enabled': enabled,
      'daysOfWeek': daysOfWeek,
      'customMessage': customMessage,
      'mode': mode.name,
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
      // Saved before smart reminders: keep the exact days that were chosen
      mode: ReminderMode.values.where((m) => m.name == json['mode']).firstOrNull ?? ReminderMode.custom,
    );
  }

  @override
  List<Object?> get props => [time, enabled, daysOfWeek, customMessage, mode];

  @override
  String toString() => 'ReminderSettings(time: $timeString, enabled: $enabled, ${mode.name})';
}