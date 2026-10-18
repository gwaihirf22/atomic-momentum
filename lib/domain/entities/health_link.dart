import 'package:equatable/equatable.dart';

/// Which part of a phone's health data a metric comes from.
enum HealthGroup {
  activity('Activity'),
  sleep('Sleep'),
  mindfulness('Mindfulness'),
  nutrition('Nutrition');

  final String label;
  const HealthGroup(this.label);
}

/// Something a habit can be filled in from: Apple Health on iPhone, Health
/// Connect on Android. Each counts in whole units a day.
enum HealthMetric {
  steps('Steps', 'steps', 8000, HealthGroup.activity, android: true),
  exerciseMinutes('Exercise', 'minutes', 30, HealthGroup.activity, android: true),
  workouts('Workouts', 'workouts', 1, HealthGroup.activity, android: true),
  sleepHours('Sleep', 'hours', 7, HealthGroup.sleep, android: true),
  mindfulMinutes('Mindful minutes', 'minutes', 10, HealthGroup.mindfulness, android: false, writable: true),
  water('Water', 'glasses', 8, HealthGroup.nutrition, android: true, writable: true);

  final String label;

  /// What the habit counts in (water: 250 ml glasses).
  final String unit;
  final int defaultTarget;
  final HealthGroup group;

  /// Health Connect has it (Apple Health has every one).
  final bool android;

  /// Logging the habit can also log it to Health.
  final bool writable;

  const HealthMetric(this.label, this.unit, this.defaultTarget, this.group,
      {required this.android, this.writable = false});

  /// Milliliters in one glass of water.
  static const glassMl = 250;

  bool availableOn({required bool isAndroid}) => !isAndroid || android;

  static HealthMetric? fromName(Object? name) => values.where((m) => m.name == name).firstOrNull;

  static const _hints = {
    steps: ['walk', 'step', 'stroll', 'hike'],
    exerciseMinutes: ['run', 'jog', 'gym', 'exercise', 'yoga', 'swim', 'cycl', 'bike', 'cardio', 'train', 'lift', 'pilates'],
    workouts: ['workout'],
    sleepHours: ['sleep', 'bed early', 'bedtime'],
    mindfulMinutes: ['meditat', 'mindful', 'breath'],
    water: ['water', 'hydrat'],
  };

  /// What a habit called [name] (counting in [units]) is most likely
  /// about, for suggesting a link; null if nothing fits. [available]
  /// limits it to what this phone has.
  static HealthMetric? suggestFor(String name, String units, {bool Function(HealthMetric)? available}) {
    final text = '${name.toLowerCase()} ${units.toLowerCase()}';
    // "workout" wins over the "out"-less hints; units decide between minutes and counts
    for (final metric in [workouts, steps, exerciseMinutes, sleepHours, mindfulMinutes, water]) {
      if (available != null && !available(metric)) continue;
      if (_hints[metric]!.any(text.contains)) {
        if (metric == workouts && text.contains('minute')) return exerciseMinutes;
        return metric;
      }
    }
    return null;
  }
}

/// A habit filled in from Health: which [metric], whether logging it also
/// logs to Health ([logToHealth], for writable metrics), and the day it was
/// linked (days before it are never filled in).
class HealthLink extends Equatable {
  final HealthMetric metric;
  final bool logToHealth;
  final DateTime linkedOn;

  const HealthLink({required this.metric, this.logToHealth = false, required this.linkedOn});

  /// Logging also logs to Health (only for metrics that can be written).
  bool get logsToHealth => logToHealth && metric.writable;

  HealthLink copyWith({HealthMetric? metric, bool? logToHealth}) =>
      HealthLink(metric: metric ?? this.metric, logToHealth: logToHealth ?? this.logToHealth, linkedOn: linkedOn);

  Map<String, dynamic> toJson() => {
        'metric': metric.name,
        if (logToHealth) 'log': true,
        'linkedOn': '${linkedOn.year.toString().padLeft(4, '0')}-${linkedOn.month.toString().padLeft(2, '0')}-'
            '${linkedOn.day.toString().padLeft(2, '0')}',
      };

  /// Null for anything unreadable (an unknown metric drops the link).
  static HealthLink? fromJson(dynamic json) {
    if (json is! Map) return null;
    final metric = HealthMetric.fromName(json['metric']);
    final linked = json['linkedOn'] is String ? DateTime.tryParse(json['linkedOn'] as String) : null;
    if (metric == null || linked == null) return null;
    return HealthLink(
      metric: metric,
      logToHealth: json['log'] == true,
      linkedOn: DateTime(linked.year, linked.month, linked.day),
    );
  }

  @override
  List<Object?> get props => [metric, logToHealth, linkedOn];
}
