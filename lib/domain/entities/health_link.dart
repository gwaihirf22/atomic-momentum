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

/// What a linked habit counts in. Each is an exact number of its metric's
/// base unit (steps, workouts, minutes, or milliliters), so amounts convert
/// both ways; nothing typed ever goes into the arithmetic.
enum HealthUnit {
  steps('steps', 1, 8000),
  workouts('workouts', 1, 1),
  minutes('minutes', 1, 30),
  hours('hours', 60, 1),
  glasses('glasses', 250, 8),
  ml('ml', 1, 2000),
  flOz('fl oz', 29.5735, 64),
  cups('cups', 236.588, 8);

  /// As the habit's units read ("fl oz").
  final String label;

  /// How many of the metric's base unit one of these is (a glass: 250 ml).
  final double base;

  /// A sensible target in this unit when nothing else says (sleep and
  /// mindful minutes have their own, see [HealthMetric.defaultTargetIn]).
  final int typicalTarget;

  const HealthUnit(this.label, this.base, this.typicalTarget);

  /// [baseAmount] (steps, minutes, ml…) in this unit, rounded to whole.
  int fromBase(num baseAmount) => (baseAmount / base).round();

  /// [amount] of this unit in the base unit.
  double toBase(num amount) => amount * base;

  static const _words = {
    steps: ['step', 'steps'],
    workouts: ['workout', 'workouts', 'session', 'sessions'],
    minutes: ['min', 'mins', 'minute', 'minutes'],
    hours: ['h', 'hr', 'hrs', 'hour', 'hours'],
    glasses: ['glass', 'glasses'],
    ml: ['ml', 'milliliter', 'milliliters', 'millilitre', 'millilitres'],
    flOz: ['oz', 'fl oz', 'floz', 'fl. oz', 'ounce', 'ounces', 'fluid ounce', 'fluid ounces'],
    cups: ['cup', 'cups'],
  };

  /// The unit [text] names, if it's one of [among] (null if it isn't, or
  /// isn't a unit we know, such as "bottles").
  static HealthUnit? match(String text, List<HealthUnit> among) {
    final word = text.trim().toLowerCase();
    for (final unit in among) {
      if (_words[unit]!.contains(word)) return unit;
    }
    return null;
  }

  static HealthUnit? fromName(Object? name) => values.where((u) => u.name == name).firstOrNull;
}

/// Something a habit can be filled in from: Apple Health on iPhone, Health
/// Connect on Android. Counts in whole [HealthUnit]s a day.
enum HealthMetric {
  steps('Steps', [HealthUnit.steps], HealthGroup.activity, android: true),
  exerciseMinutes('Exercise', [HealthUnit.minutes, HealthUnit.hours], HealthGroup.activity, android: true),
  workouts('Workouts', [HealthUnit.workouts], HealthGroup.activity, android: true),
  sleepHours('Sleep', [HealthUnit.hours, HealthUnit.minutes], HealthGroup.sleep, android: true),
  mindfulMinutes('Mindful minutes', [HealthUnit.minutes, HealthUnit.hours], HealthGroup.mindfulness,
      android: false, writable: true),
  water('Water', [HealthUnit.glasses, HealthUnit.ml, HealthUnit.flOz, HealthUnit.cups], HealthGroup.nutrition,
      android: true, writable: true);

  final String label;

  /// The units it can count in, the usual one first.
  final List<HealthUnit> units;
  final HealthGroup group;

  /// Health Connect has it (Apple Health has every one).
  final bool android;

  /// Logging the habit can also log it to Health.
  final bool writable;

  const HealthMetric(this.label, this.units, this.group, {required this.android, this.writable = false});

  HealthUnit get defaultUnit => units.first;

  /// The usual unit's word ("glasses").
  String get unit => defaultUnit.label;

  int get defaultTarget => defaultTargetIn(defaultUnit);

  /// A sensible target counted in [unit]: 7 hours of sleep is 420 minutes.
  int defaultTargetIn(HealthUnit unit) => switch (this) {
        sleepHours => unit.fromBase(7 * 60),
        mindfulMinutes => unit == HealthUnit.hours ? 1 : 10,
        _ => unit.typicalTarget,
      };

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

/// A habit filled in from Health: which [metric], the [unit] it counts in,
/// whether logging it also logs to Health ([logToHealth], for writable
/// metrics), and the day it was linked (days before it are never filled in).
class HealthLink extends Equatable {
  final HealthMetric metric;
  final HealthUnit unit;
  final bool logToHealth;
  final DateTime linkedOn;

  /// [unit] defaults to the metric's usual one (and must be one of its own).
  HealthLink({required this.metric, HealthUnit? unit, this.logToHealth = false, required this.linkedOn})
      : unit = unit != null && metric.units.contains(unit) ? unit : metric.defaultUnit;

  /// Logging also logs to Health (only for metrics that can be written).
  bool get logsToHealth => logToHealth && metric.writable;

  HealthLink copyWith({HealthMetric? metric, HealthUnit? unit, bool? logToHealth}) => HealthLink(
        metric: metric ?? this.metric,
        unit: unit ?? (metric == null ? this.unit : null),
        logToHealth: logToHealth ?? this.logToHealth,
        linkedOn: linkedOn,
      );

  Map<String, dynamic> toJson() => {
        'metric': metric.name,
        if (unit != metric.defaultUnit) 'unit': unit.name,
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
      unit: HealthUnit.fromName(json['unit']),
      logToHealth: json['log'] == true,
      linkedOn: DateTime(linked.year, linked.month, linked.day),
    );
  }

  @override
  List<Object?> get props => [metric, unit, logToHealth, linkedOn];
}
