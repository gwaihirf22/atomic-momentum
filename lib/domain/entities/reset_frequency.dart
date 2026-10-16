import 'habit_schedule.dart';

enum ResetFrequency {
  daily("Daily", Duration(days: 1)),
  weekly("Weekly", Duration(days: 7)),
  monthly("Monthly", Duration(days: 30)),
  never("Never", null);

  const ResetFrequency(this.displayName, this.duration);

  final String displayName;
  final Duration? duration;

  static ResetFrequency fromString(String value) {
    return ResetFrequency.values.firstWhere(
      (frequency) => frequency.name == value,
      orElse: () => ResetFrequency.daily,
    );
  }

  /// Whether this frequency has periods at all (and therefore resets and streaks).
  bool get isPeriodic => this != ResetFrequency.never;

  /// Unit a streak is counted in, as in "3 week streak".
  String get periodUnit {
    switch (this) {
      case ResetFrequency.weekly:
        return 'week';
      case ResetFrequency.monthly:
        return 'month';
      case ResetFrequency.daily:
      case ResetFrequency.never:
        return 'day';
    }
  }

  // Period maths lives in HabitSchedule; these are the interval-1 shorthands.

  /// Local midnight at which the period containing [date] began. Weekly
  /// periods start on [anchor]'s weekday, monthly ones on its day of month.
  DateTime periodStart(DateTime date, {required DateTime anchor}) =>
      HabitSchedule(frequency: this, anchor: anchor).periodStart(date);

  /// Local midnight at which the period after the one containing [date] begins.
  DateTime nextPeriodStart(DateTime date, {required DateTime anchor}) =>
      HabitSchedule(frequency: this, anchor: anchor).nextPeriodStart(date);

  /// True when [currentDate] falls in a later period than [lastResetDate].
  bool shouldReset(DateTime lastResetDate, DateTime currentDate, {required DateTime anchor}) =>
      HabitSchedule(frequency: this, anchor: anchor).shouldReset(lastResetDate, currentDate);

  /// Human-readable reset day, e.g. "Resets every Thursday" or "Resets on the
  /// 15th of each month". Null for frequencies without a choosable reset day.
  String? describeResetDay(DateTime anchor) {
    switch (this) {
      case ResetFrequency.weekly:
        return 'Resets every ${_weekdayNames[anchor.weekday - 1]}';
      case ResetFrequency.monthly:
        final day = anchor.day;
        final shortMonthNote = day > 28 ? ' (or the last day of shorter months)' : '';
        return 'Resets on the ${_ordinal(day)} of each month$shortMonthNote';
      case ResetFrequency.daily:
      case ResetFrequency.never:
        return null;
    }
  }

  static const _weekdayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  static String _ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  @override
  String toString() => name;
}
