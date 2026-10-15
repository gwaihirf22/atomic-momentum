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

  /// Local midnight at which the period containing [date] began.
  ///
  /// [anchor] picks the reset day: weekly periods start on the anchor's
  /// weekday, monthly periods on the anchor's day of the month (clamped to the
  /// last day in shorter months). Daily periods ignore it. A `never` habit has
  /// a single period that starts at the anchor.
  DateTime periodStart(DateTime date, {required DateTime anchor}) {
    final day = _dateOnly(date);
    switch (this) {
      case ResetFrequency.daily:
        return day;
      case ResetFrequency.weekly:
        final daysSinceResetDay = (day.weekday - anchor.weekday) % 7;
        return DateTime(day.year, day.month, day.day - daysSinceResetDay);
      case ResetFrequency.monthly:
        final thisMonthReset = _monthlyResetDate(day.year, day.month, anchor.day);
        if (!day.isBefore(thisMonthReset)) return thisMonthReset;
        return _monthlyResetDate(day.year, day.month - 1, anchor.day);
      case ResetFrequency.never:
        return _dateOnly(anchor);
    }
  }

  /// Local midnight at which the period after the one containing [date] begins.
  DateTime nextPeriodStart(DateTime date, {required DateTime anchor}) {
    final start = periodStart(date, anchor: anchor);
    switch (this) {
      case ResetFrequency.daily:
        return DateTime(start.year, start.month, start.day + 1);
      case ResetFrequency.weekly:
        return DateTime(start.year, start.month, start.day + 7);
      case ResetFrequency.monthly:
        return _monthlyResetDate(start.year, start.month + 1, anchor.day);
      case ResetFrequency.never:
        throw StateError('Cannot calculate next reset date for never frequency');
    }
  }

  /// True when [currentDate] falls in a later period than [lastResetDate].
  bool shouldReset(DateTime lastResetDate, DateTime currentDate, {required DateTime anchor}) {
    if (!isPeriodic) return false;

    return periodStart(currentDate, anchor: anchor)
        .isAfter(periodStart(lastResetDate, anchor: anchor));
  }

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

  static DateTime _dateOnly(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  // DateTime normalises month overflow (month 0 or 13), so callers can pass month +/- 1
  static DateTime _monthlyResetDate(int year, int month, int anchorDay) {
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, anchorDay > lastDayOfMonth ? lastDayOfMonth : anchorDay);
  }

  @override
  String toString() => name;
}
