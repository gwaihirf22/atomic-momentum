import 'package:equatable/equatable.dart';
import 'package:clock/clock.dart';

class StreakData extends Equatable {
  final int current;
  final int longest;
  final DateTime? lastUpdateDate;
  final List<StreakPeriod> history;

  /// The last due period was missed, so one more miss ends the streak
  /// ("don't miss twice"). Cleared by completing the habit again.
  final bool atRisk;

  const StreakData({
    required this.current,
    required this.longest,
    this.lastUpdateDate,
    required this.history,
    this.atRisk = false,
  });

  factory StreakData.empty() {
    return const StreakData(
      current: 0,
      longest: 0,
      lastUpdateDate: null,
      history: [],
    );
  }

  StreakData copyWith({
    int? current,
    int? longest,
    DateTime? lastUpdateDate,
    List<StreakPeriod>? history,
    bool? atRisk,
  }) {
    return StreakData(
      current: current ?? this.current,
      longest: longest ?? this.longest,
      lastUpdateDate: lastUpdateDate ?? this.lastUpdateDate,
      history: history ?? this.history,
      atRisk: atRisk ?? this.atRisk,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current': current,
      'longest': longest,
      'lastUpdateDate': lastUpdateDate?.toIso8601String(),
      'history': history.map((period) => period.toJson()).toList(),
      'atRisk': atRisk,
    };
  }

  factory StreakData.fromJson(Map<String, dynamic> json) {
    return StreakData(
      current: json['current'] as int,
      longest: json['longest'] as int,
      lastUpdateDate: json['lastUpdateDate'] != null
          ? DateTime.parse(json['lastUpdateDate'] as String)
          : null,
      history: (json['history'] as List<dynamic>)
          .map((item) => StreakPeriod.fromJson(item as Map<String, dynamic>))
          .toList(),
      atRisk: json['atRisk'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [current, longest, lastUpdateDate, history, atRisk];

  @override
  String toString() => 'StreakData(current: $current, longest: $longest${atRisk ? ', at risk' : ''})';
}

class StreakPeriod extends Equatable {
  final DateTime startDate;
  final DateTime? endDate;
  final int length;

  const StreakPeriod({
    required this.startDate,
    this.endDate,
    required this.length,
  });

  bool get isActive => endDate == null;

  int get durationInDays {
    if (endDate != null) {
      return endDate!.difference(startDate).inDays + 1;
    }
    return clock.now().difference(startDate).inDays + 1;
  }

  StreakPeriod copyWith({
    DateTime? startDate,
    DateTime? endDate,
    int? length,
  }) {
    return StreakPeriod(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      length: length ?? this.length,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'length': length,
    };
  }

  factory StreakPeriod.fromJson(Map<String, dynamic> json) {
    return StreakPeriod(
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      length: json['length'] as int,
    );
  }

  @override
  List<Object?> get props => [startDate, endDate, length];

  @override
  String toString() => 'StreakPeriod(start: $startDate, length: $length)';
}