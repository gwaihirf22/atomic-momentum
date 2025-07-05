import 'package:equatable/equatable.dart';

class StreakData extends Equatable {
  final int current;
  final int longest;
  final DateTime? lastUpdateDate;
  final List<StreakPeriod> history;

  const StreakData({
    required this.current,
    required this.longest,
    this.lastUpdateDate,
    required this.history,
  });

  factory StreakData.empty() {
    return const StreakData(
      current: 0,
      longest: 0,
      lastUpdateDate: null,
      history: [],
    );
  }

  StreakData updateStreak({
    required DateTime date,
    required bool completed,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);

    // If updating for a future date, don't change streak
    if (targetDate.isAfter(today)) {
      return this;
    }

    int newCurrent = current;
    int newLongest = longest;
    List<StreakPeriod> newHistory = List.from(history);

    if (completed) {
      // Check if this continues the current streak
      if (lastUpdateDate != null) {
        final lastUpdate = DateTime(
          lastUpdateDate!.year,
          lastUpdateDate!.month,
          lastUpdateDate!.day,
        );
        final daysDifference = targetDate.difference(lastUpdate).inDays;

        if (daysDifference == 1) {
          // Consecutive day - continue streak
          newCurrent = current + 1;
        } else if (daysDifference == 0) {
          // Same day - no change to streak
          newCurrent = current;
        } else {
          // Gap in days - start new streak
          if (current > 0) {
            // End the current streak period
            newHistory = _endCurrentStreakPeriod(newHistory, lastUpdateDate!);
          }
          newCurrent = 1;
        }
      } else {
        // First completion
        newCurrent = 1;
      }

      // Update longest streak
      if (newCurrent > longest) {
        newLongest = newCurrent;
      }

      // Start new streak period if needed
      if (newHistory.isEmpty || 
          (newHistory.last.endDate != null && newCurrent == 1)) {
        newHistory.add(StreakPeriod(
          startDate: targetDate,
          endDate: null,
          length: newCurrent,
        ));
      } else if (newHistory.isNotEmpty && newHistory.last.endDate == null) {
        // Update current streak period
        newHistory[newHistory.length - 1] = newHistory.last.copyWith(
          length: newCurrent,
        );
      }
    } else {
      // Not completed - break streak if it was ongoing
      if (current > 0 && lastUpdateDate != null) {
        newHistory = _endCurrentStreakPeriod(newHistory, lastUpdateDate!);
      }
      newCurrent = 0;
    }

    return StreakData(
      current: newCurrent,
      longest: newLongest,
      lastUpdateDate: targetDate.isAfter(today) ? lastUpdateDate : targetDate,
      history: newHistory,
    );
  }

  List<StreakPeriod> _endCurrentStreakPeriod(
    List<StreakPeriod> history,
    DateTime endDate,
  ) {
    if (history.isEmpty) return history;

    final newHistory = List<StreakPeriod>.from(history);
    if (newHistory.last.endDate == null) {
      newHistory[newHistory.length - 1] = newHistory.last.copyWith(
        endDate: endDate,
      );
    }
    return newHistory;
  }

  StreakData copyWith({
    int? current,
    int? longest,
    DateTime? lastUpdateDate,
    List<StreakPeriod>? history,
  }) {
    return StreakData(
      current: current ?? this.current,
      longest: longest ?? this.longest,
      lastUpdateDate: lastUpdateDate ?? this.lastUpdateDate,
      history: history ?? this.history,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current': current,
      'longest': longest,
      'lastUpdateDate': lastUpdateDate?.toIso8601String(),
      'history': history.map((period) => period.toJson()).toList(),
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
    );
  }

  @override
  List<Object?> get props => [current, longest, lastUpdateDate, history];

  @override
  String toString() => 'StreakData(current: $current, longest: $longest)';
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
    return DateTime.now().difference(startDate).inDays + 1;
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